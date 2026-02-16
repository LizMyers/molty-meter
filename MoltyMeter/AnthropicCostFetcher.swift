import Foundation

private let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".molty-debug.log")
private func log(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fh = try? FileHandle(forWritingTo: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}

enum AnthropicCostFetcher {

    // TODO: Remove after Feb 2026 — Haiku spend on old "Kensington-bot" key before switch to KennyBot2
    private static let preKeyOffset: Double = 58.11

    // Cache: only re-fetch at most every 5 minutes
    private static var cachedCost: Double?
    private static var lastFetchTime: Date?

    private static var cachedDailyCosts: [DailySpend]?
    private static var lastDailyFetchTime: Date?

    static func fetchMonthlyHaikuCost(adminKey: String) async -> Double? {
        // Return cached value if fetched within last 60 seconds
        if let cached = cachedCost, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < 300 {
            return cached
        }

        log("[MoltyAPI] fetchMonthlyHaikuCost called")
        let calendar = Calendar.current
        let now = Date()

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let endingAt = formatter.string(from: now)

        var totalCents: Double = 0
        var currentStart = formatter.string(from: monthStart)
        var pageCount = 0

        while true {
            pageCount += 1
            var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
            components.queryItems = [
                URLQueryItem(name: "starting_at", value: currentStart),
                URLQueryItem(name: "ending_at", value: endingAt),
                URLQueryItem(name: "group_by[]", value: "description"),
            ]

            guard let url = components.url else { return nil }
            log("[MoltyAPI] Page \(pageCount): \(url)")

            var request = URLRequest(url: url)
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(adminKey, forHTTPHeaderField: "x-api-key")

            // Retry up to 3 times on 429
            var data: Data?
            var httpStatus: Int = 0
            for attempt in 0..<3 {
                if attempt > 0 {
                    log("[MoltyAPI] Retry \(attempt) after 429")
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 2) * 1_000_000_000)
                }
                guard let (respData, response) = try? await URLSession.shared.data(for: request),
                      let httpResponse = response as? HTTPURLResponse else {
                    log("[MoltyAPI] Network request failed")
                    return nil
                }
                httpStatus = httpResponse.statusCode
                data = respData
                if httpStatus != 429 { break }
            }

            log("[MoltyAPI] HTTP \(httpStatus)")
            guard httpStatus == 200, let data else {
                log("[MoltyAPI] Error: \(String(data: data ?? Data(), encoding: .utf8) ?? "nil")")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            if let days = json["data"] as? [[String: Any]] {
                for day in days {
                    guard let results = day["results"] as? [[String: Any]] else { continue }
                    for entry in results {
                        guard let description = entry["description"] as? String,
                              description.localizedCaseInsensitiveContains("Haiku"),
                              let amountStr = entry["amount"] as? String,
                              let amount = Double(amountStr) else { continue }
                        totalCents += amount
                    }
                }
            }

            // Paginate by decoding the next_page cursor as a new starting_at
            let hasMore = json["has_more"] as? Bool ?? false
            guard hasMore, let nextPage = json["next_page"] as? String,
                  let decoded = Data(base64Encoded: nextPage.replacingOccurrences(of: "page_", with: "")),
                  let nextStart = String(data: decoded, encoding: .utf8) else {
                break
            }
            currentStart = nextStart
        }

        let result = max(0, totalCents / 100.0 - preKeyOffset)
        log("[MoltyAPI] Total cents: \(totalCents), result: $\(String(format: "%.2f", result))")

        cachedCost = result
        lastFetchTime = Date()

        return result
    }

    static func fetchDailyHaikuCosts(adminKey: String) async -> [DailySpend]? {
        if let cached = cachedDailyCosts, let lastFetch = lastDailyFetchTime,
           Date().timeIntervalSince(lastFetch) < 300 {
            return cached
        }

        log("[MoltyAPI] fetchDailyHaikuCosts called")
        let calendar = Calendar.current
        let now = Date()

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let endingAt = formatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var dailyTotals: [String: Double] = [:]
        var currentStart = formatter.string(from: monthStart)
        var pageCount = 0

        while true {
            pageCount += 1
            var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
            components.queryItems = [
                URLQueryItem(name: "starting_at", value: currentStart),
                URLQueryItem(name: "ending_at", value: endingAt),
                URLQueryItem(name: "group_by[]", value: "description"),
            ]

            guard let url = components.url else { return nil }
            log("[MoltyAPI] Daily page \(pageCount): \(url)")

            var request = URLRequest(url: url)
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(adminKey, forHTTPHeaderField: "x-api-key")

            var data: Data?
            var httpStatus: Int = 0
            for attempt in 0..<3 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 2) * 1_000_000_000)
                }
                guard let (respData, response) = try? await URLSession.shared.data(for: request),
                      let httpResponse = response as? HTTPURLResponse else {
                    return nil
                }
                httpStatus = httpResponse.statusCode
                data = respData
                if httpStatus != 429 { break }
            }

            guard httpStatus == 200, let data else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            if let days = json["data"] as? [[String: Any]] {
                for day in days {
                    guard let startingAt = day["starting_at"] as? String,
                          let results = day["results"] as? [[String: Any]] else { continue }

                    // Parse the day date from the starting_at ISO timestamp
                    let dayDate: String
                    if let date = formatter.date(from: startingAt) {
                        dayDate = dateFormatter.string(from: date)
                    } else {
                        dayDate = String(startingAt.prefix(10))
                    }

                    for entry in results {
                        guard let description = entry["description"] as? String,
                              description.localizedCaseInsensitiveContains("Haiku"),
                              let amountStr = entry["amount"] as? String,
                              let amount = Double(amountStr) else { continue }
                        dailyTotals[dayDate, default: 0] += amount
                    }
                }
            }

            let hasMore = json["has_more"] as? Bool ?? false
            guard hasMore, let nextPage = json["next_page"] as? String,
                  let decoded = Data(base64Encoded: nextPage.replacingOccurrences(of: "page_", with: "")),
                  let nextStart = String(data: decoded, encoding: .utf8) else {
                break
            }
            currentStart = nextStart
        }

        let result = dailyTotals.map { DailySpend(date: $0.key, sessions: 0, cost: $0.value / 100.0) }
            .sorted { $0.date < $1.date }

        log("[MoltyAPI] Daily costs: \(result.count) days")

        cachedDailyCosts = result
        lastDailyFetchTime = Date()

        return result
    }
}
