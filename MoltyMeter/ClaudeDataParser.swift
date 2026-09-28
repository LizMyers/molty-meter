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
    private static let openclawDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".openclaw")
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

    // MARK: - OpenClaw Support

    struct OpenClawSession {
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let contextLimit: Int
        let sessionFile: String

        var contextPercent: Double {
            contextLimit > 0 ? Double(totalTokens) / Double(contextLimit) : 0
        }

        var cost: Double {
            // OpenClaw doesn't track cache tokens separately in sessions.json
            CostCalculator.cost(
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: 0,
                cacheWriteTokens: 0
            )
        }
    }

    /// Read the model name from the last assistant message in a session JSONL file.
    /// This reflects the actual model in use, even if it changed mid-session.
    private static func lastModelFromJSONL(path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else { return nil }

        var lastModel: String?
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            // Both Claude Code and OpenClaw formats store model in message.model
            if let message = obj["message"] as? [String: Any],
               let model = message["model"] as? String {
                lastModel = model
            }
        }
        return lastModel
    }

    /// Load active OpenClaw sessions via the `openclaw sessions --json` CLI.
    ///
    /// This used to read ~/.openclaw/agents/*/sessions/sessions.json directly, but OpenClaw
    /// migrated session state into a SQLite store (openclaw-agent.sqlite) and that flat file
    /// no longer exists — reading it always silently returned zero sessions, so the widget
    /// permanently showed "no active session" even while Kenny was actively running. The CLI
    /// is the stable interface to whatever storage format is live underneath (found Sep 28).
    static func loadOpenClawSessions() -> [OpenClawSession] {
        guard let json = runOpenClawSessionsJSON(),
              let sessionsArray = json["sessions"] as? [[String: Any]] else {
            return []
        }

        var sessions: [OpenClawSession] = []
        for entry in sessionsArray {
            guard let model = entry["model"] as? String,
                  let totalTokens = entry["totalTokens"] as? Int,
                  let contextTokens = entry["contextTokens"] as? Int else {
                continue
            }
            let inputTokens = entry["inputTokens"] as? Int ?? 0
            let outputTokens = entry["outputTokens"] as? Int ?? 0
            let identity = entry["key"] as? String ?? entry["sessionId"] as? String ?? "unknown"

            sessions.append(OpenClawSession(
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                totalTokens: totalTokens,
                contextLimit: contextTokens,
                sessionFile: identity
            ))
        }

        // The CLI already returns sessions sorted most-recently-updated first.
        return sessions
    }

    /// Runs `openclaw sessions --json` and parses stdout. Uses the absolute Homebrew path
    /// since GUI/LaunchAgent-launched apps don't inherit an interactive shell's PATH.
    private static func runOpenClawSessionsJSON() -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/openclaw")
        process.arguments = ["sessions", "--json"]

        let stdout = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdout
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return nil
        }
        // Read to EOF before waiting on exit — waiting first risks a deadlock if output
        // ever exceeds the pipe buffer (child blocks writing, parent blocks waiting).
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Calculate cost for OpenClaw session JSONL file
    static func openClawSessionCost(jsonlPath: String) -> Double {
        let url = URL(fileURLWithPath: jsonlPath)
        guard let session = parseSession(jsonlURL: url, sessionId: url.deletingPathExtension().lastPathComponent) else {
            return 0
        }
        return session.totalCost
    }

    /// Calculate total cost for all sessions in the current month (Claude Code + OpenClaw)
    static func monthlyTotalCost() -> Double {
        var totalCost: Double = 0

        // Claude Code sessions
        totalCost += claudeCodeMonthlyCost()

        // OpenClaw sessions
        totalCost += openClawMonthlyCost()

        return totalCost
    }

    private static func claudeCodeMonthlyCost() -> Double {
        let projectsDir = claudeDir.appendingPathComponent("projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir, includingPropertiesForKeys: nil
        ) else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var totalCost: Double = 0

        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                // Skip files older than start of month (optimization)
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate < startOfMonth {
                    continue
                }

                let sessionId = file.deletingPathExtension().lastPathComponent
                if let session = parseSession(jsonlURL: file, sessionId: sessionId) {
                    // Only count if session started this month
                    if let startTime = session.startTime, startTime >= startOfMonth {
                        totalCost += session.totalCost
                    }
                }
            }
        }

        return totalCost
    }

    /// Calculate monthly cost, optionally filtered by model prefix (e.g. "gpt", "claude")
    static func openClawMonthlyCost(modelPrefix: String? = nil) -> Double {
        let agentsDir = openclawDir.appendingPathComponent("agents")
        guard let agentDirs = try? FileManager.default.contentsOfDirectory(
            at: agentsDir, includingPropertiesForKeys: nil
        ) else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var totalCost: Double = 0

        for agentDir in agentDirs {
            let sessionsDir = agentDir.appendingPathComponent("sessions")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: sessionsDir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                // Skip files older than start of month
                if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate < startOfMonth {
                    continue
                }

                // Parse OpenClaw JSONL for cost
                totalCost += parseOpenClawSessionCost(jsonlURL: file, startOfMonth: startOfMonth, modelPrefix: modelPrefix)
            }
        }

        return totalCost
    }

    /// Parse OpenClaw session JSONL and calculate cost
    private static func parseOpenClawSessionCost(jsonlURL: URL, startOfMonth: Date, modelPrefix: String? = nil) -> Double {
        guard let data = try? Data(contentsOf: jsonlURL),
              let content = String(data: data, encoding: .utf8) else { return 0 }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var totalCost: Double = 0
        var sessionStart: Date?
        var sessionModel: String?

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let type = obj["type"] as? String ?? ""

            // Get session start time
            if type == "session" && sessionStart == nil {
                if let ts = obj["timestamp"] as? String {
                    sessionStart = isoFormatter.date(from: ts)
                }
            }

            // OpenClaw format: type=message, message.usage.cost.total
            if type == "message",
               let message = obj["message"] as? [String: Any] {
                // Capture model from first message
                if sessionModel == nil, let model = message["model"] as? String {
                    sessionModel = model
                }
                if let usage = message["usage"] as? [String: Any],
                   let cost = usage["cost"] as? [String: Any],
                   let costTotal = cost["total"] as? Double {
                    totalCost += costTotal
                }
            }
        }

        // Only count if session started this month
        if let start = sessionStart, start < startOfMonth {
            return 0
        }

        // Filter by model prefix if specified
        if let prefix = modelPrefix,
           let model = sessionModel,
           !model.lowercased().hasPrefix(prefix.lowercased()) {
            return 0
        }

        return totalCost
    }

    /// Parse OpenClaw session JSONL and return total cost for active session display
    static func parseOpenClawSessionTotalCost(jsonlPath: String) -> Double {
        let url = URL(fileURLWithPath: jsonlPath)
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return 0 }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var totalCost: Double = 0

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let type = obj["type"] as? String, type == "message",
               let message = obj["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any],
               let cost = usage["cost"] as? [String: Any],
               let costTotal = cost["total"] as? Double {
                totalCost += costTotal
            }
        }

        return totalCost
    }
}
