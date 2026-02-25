import Foundation
import AppKit

struct DailySpend {
    let date: String
    let sessions: Int
    let cost: Double
}

class BudgetReportGenerator {
    /// Get daily spend data for in-app display
    static func getDailySpend() -> [DailySpend] {
        return generateReport()
    }

    static func generateAndOpen() {
        let report = generateReport()
        let html = generateHTML(from: report)

        // Write to temp file and open
        let tempDir = FileManager.default.temporaryDirectory
        let reportURL = tempDir.appendingPathComponent("molty-budget-report.html")

        do {
            try html.write(to: reportURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(reportURL)
        } catch {
            // Failed to write report
        }
    }

    private static func generateReport() -> [DailySpend] {
        let openclawDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/agents")

        guard let agentDirs = try? FileManager.default.contentsOfDirectory(
            at: openclawDir, includingPropertiesForKeys: nil
        ) else { return [] }

        var dailyData: [String: (sessions: Int, cost: Double)] = [:]

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        for agentDir in agentDirs {
            let sessionsDir = agentDir.appendingPathComponent("sessions")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: sessionsDir, includingPropertiesForKeys: nil
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                guard let data = try? Data(contentsOf: file),
                      let content = String(data: data, encoding: .utf8) else { continue }

                let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
                var sessionDate: String?
                var sessionCost: Double = 0

                for line in lines {
                    guard let lineData = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                        continue
                    }

                    let type = obj["type"] as? String ?? ""

                    // Get session start date
                    if (type == "session" || type == "user") && sessionDate == nil {
                        if let ts = obj["timestamp"] as? String,
                           let date = isoFormatter.date(from: ts) {
                            // Only count this month
                            if date >= startOfMonth {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd"
                                sessionDate = dateFormatter.string(from: date)
                            }
                        }
                    }

                    // Sum costs
                    if type == "message",
                       let message = obj["message"] as? [String: Any],
                       let usage = message["usage"] as? [String: Any],
                       let cost = usage["cost"] as? [String: Any],
                       let costTotal = cost["total"] as? Double {
                        sessionCost += costTotal
                    }
                }

                // Add to daily totals
                if let date = sessionDate, sessionCost > 0 {
                    var current = dailyData[date] ?? (sessions: 0, cost: 0)
                    current.sessions += 1
                    current.cost += sessionCost
                    dailyData[date] = current
                }
            }
        }

        // Convert to sorted array
        return dailyData.map { DailySpend(date: $0.key, sessions: $0.value.sessions, cost: $0.value.cost) }
            .sorted { $0.date < $1.date }
    }

    private static func generateHTML(from report: [DailySpend]) -> String {
        let totalCost = report.reduce(0) { $0 + $1.cost }
        let totalSessions = report.reduce(0) { $0 + $1.sessions }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"

        let rows = report.map { daily -> String in
            let displayDate: String
            if let date = dateFormatter.date(from: daily.date) {
                displayDate = displayFormatter.string(from: date)
            } else {
                displayDate = daily.date
            }
            return """
                <tr>
                    <td>\(displayDate)</td>
                    <td class="center">\(daily.sessions)</td>
                    <td class="right">$\(String(format: "%.2f", daily.cost))</td>
                </tr>
            """
        }.joined(separator: "\n")

        let monthName = DateFormatter().monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        let year = Calendar.current.component(.year, from: Date())

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Molty Meter - Budget Report</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                    color: #eee;
                    margin: 0;
                    padding: 40px;
                    min-height: 100vh;
                }
                .container {
                    max-width: 600px;
                    margin: 0 auto;
                }
                h1 {
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    margin-bottom: 8px;
                }
                h1 span { font-size: 1.5em; }
                .subtitle {
                    color: #888;
                    margin-bottom: 32px;
                }
                .summary {
                    display: flex;
                    gap: 24px;
                    margin-bottom: 32px;
                }
                .stat {
                    background: rgba(255,255,255,0.05);
                    border-radius: 12px;
                    padding: 20px 28px;
                    flex: 1;
                }
                .stat-label {
                    color: #888;
                    font-size: 14px;
                    margin-bottom: 4px;
                }
                .stat-value {
                    font-size: 28px;
                    font-weight: 600;
                }
                .stat-value.cost { color: #4ade80; }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    background: rgba(255,255,255,0.03);
                    border-radius: 12px;
                    overflow: hidden;
                }
                th, td {
                    padding: 14px 20px;
                    text-align: left;
                    border-bottom: 1px solid rgba(255,255,255,0.06);
                }
                th {
                    background: rgba(255,255,255,0.05);
                    font-weight: 600;
                    color: #bbb;
                    font-size: 13px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }
                tr:last-child td { border-bottom: none; }
                tr:hover { background: rgba(255,255,255,0.02); }
                .center { text-align: center; }
                .right { text-align: right; font-variant-numeric: tabular-nums; }
                .footer {
                    margin-top: 32px;
                    color: #666;
                    font-size: 13px;
                    text-align: center;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1><span>🦞</span> Molty Meter</h1>
                <div class="subtitle">Budget Report for \(monthName) \(year)</div>

                <div class="summary">
                    <div class="stat">
                        <div class="stat-label">Total Spend</div>
                        <div class="stat-value cost">$\(String(format: "%.2f", totalCost))</div>
                    </div>
                    <div class="stat">
                        <div class="stat-label">Sessions</div>
                        <div class="stat-value">\(totalSessions)</div>
                    </div>
                </div>

                <table>
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th class="center">Sessions</th>
                            <th class="right">Cost</th>
                        </tr>
                    </thead>
                    <tbody>
                        \(rows)
                    </tbody>
                </table>

                <div class="footer">
                    Generated by Molty Meter • OpenClaw API Usage
                </div>
            </div>
        </body>
        </html>
        """
    }
}
