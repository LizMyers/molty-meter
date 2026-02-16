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

    // Cache: re-fetch every 30 minutes
    private static var cachedCost: Double?
    private static var lastFetchTime: Date?

    /// Fetch Haiku cost from the cost_report endpoint.
    /// Uses costStartDate if set, otherwise defaults to start of current month.
    /// Returns exact billing amounts (matches Anthropic console).
    static func fetchMonthlyHaikuCost(adminKey: String, costStartDate: String? = nil) async -> Double? {
        if let cached = cachedCost, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < 1800 {
            return cached
        }

        log("[MoltyAPI] fetchMonthlyHaikuCost called (cost_report)")
        let calendar = Calendar.current
        let now = Date()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let endingAt = formatter.string(from: now)

        // Use costStartDate if provided, otherwise start of current month
        let startDate: Date
        if let dateStr = costStartDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone(identifier: "UTC")
            startDate = df.date(from: dateStr) ?? calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        } else {
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                return nil
            }
            startDate = monthStart
        }

        var totalCents: Double = 0
        var currentStart = formatter.string(from: startDate)
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

            var data: Data?
            var httpStatus: Int = 0
            for attempt in 0..<3 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 2_000_000_000)
                }
                guard let (respData, response) = try? await URLSession.shared.data(for: request),
                      let httpResponse = response as? HTTPURLResponse else {
                    log("[MoltyAPI] Request failed (attempt \(attempt + 1)/3)")
                    if attempt < 2 { continue }
                    return nil
                }
                httpStatus = httpResponse.statusCode
                data = respData
                if httpStatus != 429 { break }
            }

            log("[MoltyAPI] HTTP \(httpStatus)")
            guard httpStatus == 200, let data else { return nil }

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

            let hasMore = json["has_more"] as? Bool ?? false
            guard hasMore, let nextPage = json["next_page"] as? String,
                  let decoded = Data(base64Encoded: nextPage.replacingOccurrences(of: "page_", with: "")),
                  let nextStart = String(data: decoded, encoding: .utf8) else {
                break
            }
            currentStart = nextStart
        }

        let result = totalCents / 100.0
        log("[MoltyAPI] Total: $\(String(format: "%.2f", result))")

        cachedCost = result
        lastFetchTime = Date()

        return result
    }
}
