import Foundation

struct SessionUsageEntry {
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let timestamp: Date
}

struct ParsedSession {
    let sessionId: String
    let entries: [SessionUsageEntry]
    let startTime: Date?
    let projectPath: String

    var totalInputTokens: Int { entries.reduce(0) { $0 + $1.inputTokens } }
    var totalOutputTokens: Int { entries.reduce(0) { $0 + $1.outputTokens } }
    var totalCacheReadTokens: Int { entries.reduce(0) { $0 + $1.cacheReadTokens } }
    var totalCacheWriteTokens: Int { entries.reduce(0) { $0 + $1.cacheWriteTokens } }
    var totalTokens: Int { totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheWriteTokens }
    var primaryModel: String { entries.last?.model ?? "unknown" }

    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    var totalCost: Double {
        var costByModel: [String: (input: Int, output: Int, cacheRead: Int, cacheWrite: Int)] = [:]
        for entry in entries {
            var current = costByModel[entry.model] ?? (0, 0, 0, 0)
            current.input += entry.inputTokens
            current.output += entry.outputTokens
            current.cacheRead += entry.cacheReadTokens
            current.cacheWrite += entry.cacheWriteTokens
            costByModel[entry.model] = current
        }
        return costByModel.reduce(0.0) { total, pair in
            total + CostCalculator.cost(
                model: pair.key,
                inputTokens: pair.value.input,
                outputTokens: pair.value.output,
                cacheReadTokens: pair.value.cacheRead,
                cacheWriteTokens: pair.value.cacheWrite
            )
        }
    }
}

class ClaudeDataParser {
    private static let claudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func activeSessionId() -> String? {
        let latestLink = claudeDir.appendingPathComponent("debug/latest")
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: latestLink.path) else {
            return nil
        }
        // Target is like /Users/liz/.claude/debug/{session-id}.txt
        let filename = URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent
        return filename
    }

    static func findSessionJSONL(sessionId: String) -> URL? {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: nil
        ) else { return nil }

        for dir in projectDirs {
            let jsonlFile = dir.appendingPathComponent("\(sessionId).jsonl")
            if FileManager.default.fileExists(atPath: jsonlFile.path) {
                return jsonlFile
            }
        }
        return nil
    }

    static func parseSession(jsonlURL: URL, sessionId: String) -> ParsedSession? {
        guard let data = try? Data(contentsOf: jsonlURL),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var entries: [SessionUsageEntry] = []
        var startTime: Date?
        // Track last entry per message ID for dedup (streaming sends multiple entries per msg)
        var lastEntryByMsgId: [String: SessionUsageEntry] = [:]

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let type = obj["type"] as? String ?? ""

            // Capture session start from first user message
            if type == "user" && startTime == nil {
                if let ts = obj["timestamp"] as? String {
                    startTime = isoFormatter.date(from: ts)
                }
            }

            guard type == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let msgId = message["id"] as? String else { continue }

            let model = message["model"] as? String ?? "unknown"
            let tsString = obj["timestamp"] as? String ?? ""
            let timestamp = isoFormatter.date(from: tsString) ?? Date()

            let entry = SessionUsageEntry(
                model: model,
                inputTokens: usage["input_tokens"] as? Int ?? 0,
                outputTokens: usage["output_tokens"] as? Int ?? 0,
                cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                timestamp: timestamp
            )

            // Dedup: keep last entry per message ID (streaming updates)
            lastEntryByMsgId[msgId] = entry
        }

        entries = Array(lastEntryByMsgId.values).sorted { $0.timestamp < $1.timestamp }

        let projectPath = jsonlURL.deletingLastPathComponent().lastPathComponent

        return ParsedSession(
            sessionId: sessionId,
            entries: entries,
            startTime: startTime,
            projectPath: projectPath
        )
    }

    static func loadActiveSession() -> ParsedSession? {
        guard let sessionId = activeSessionId(),
              let jsonlURL = findSessionJSONL(sessionId: sessionId) else { return nil }
        return parseSession(jsonlURL: jsonlURL, sessionId: sessionId)
    }

    /// Returns the path to the active session's JSONL file (for file monitoring)
    static func activeSessionJSONLPath() -> String? {
        guard let sessionId = activeSessionId(),
              let url = findSessionJSONL(sessionId: sessionId) else { return nil }
        return url.path
    }
}
