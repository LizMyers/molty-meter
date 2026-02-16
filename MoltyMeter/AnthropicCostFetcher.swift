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

    // Haiku 4.5 pricing (USD per million tokens) — verified against cost endpoint
    private static let inputRate: Double        = 1.00  // uncached input
    private static let cacheReadRate: Double     = 0.10  // cache read
    private static let cacheWriteRate: Double    = 1.25  // ephemeral cache write
    private static let outputRate: Double        = 5.00  // output

    // Cache: re-fetch every 30 minutes
    private static var cachedCost: Double?
    private static var lastFetchTime: Date?

    /// Fetch monthly Haiku cost from the usage endpoint.
    /// Two-pass: daily buckets for historical days + hourly buckets for today.
    /// Filters by API key ID if provided for key-specific costs.
    static func fetchMonthlyHaikuCost(adminKey: String, apiKeyId: String?) async -> Double? {
        if let cached = cachedCost, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < 1800 {
            return cached
        }

        log("[MoltyAPI] fetchMonthlyHaikuCost called")
        let calendar = Calendar.current
        let now = Date()

        guard let monthStart = calendar.date(from: DateComponents(
                  year: calendar.component(.year, from: now),
                  month: calendar.component(.month, from: now),
                  day: 1, hour: 0, minute: 0, second: 0)),
              let todayStart = calendar.date(from: DateComponents(
                  year: calendar.component(.year, from: now),
                  month: calendar.component(.month, from: now),
                  day: calendar.component(.day, from: now),
                  hour: 0, minute: 0, second: 0)) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")

        // Pass 1: daily buckets from month start to start of today (UTC)
        var historicalCost: Double = 0
        let monthStartUTC = formatter.string(from: monthStart)
        let todayStartUTC = formatter.string(from: todayStart)
        let nowUTC = formatter.string(from: now)

        if todayStart > monthStart {
            historicalCost = await fetchUsageCost(
                adminKey: adminKey, apiKeyId: apiKeyId,
                startingAt: monthStartUTC, endingAt: todayStartUTC,
                bucketWidth: "1d", limit: 31, label: "historical"
            ) ?? 0
        }

        // Pass 2: hourly buckets for today
        let todayCost = await fetchUsageCost(
            adminKey: adminKey, apiKeyId: apiKeyId,
            startingAt: todayStartUTC, endingAt: nowUTC,
            bucketWidth: "1h", limit: 24, label: "today"
        ) ?? 0

        let totalCost = historicalCost + todayCost
        log("[MoltyAPI] Historical: $\(String(format: "%.2f", historicalCost)), Today: $\(String(format: "%.2f", todayCost)), Total: $\(String(format: "%.2f", totalCost))")

        cachedCost = totalCost
        lastFetchTime = Date()

        return totalCost
    }

    private static func fetchUsageCost(
        adminKey: String, apiKeyId: String?,
        startingAt: String, endingAt: String,
        bucketWidth: String, limit: Int, label: String
    ) async -> Double? {
        var totalCost: Double = 0
        var nextPage: String? = nil
        var pageCount = 0

        while true {
            pageCount += 1
            var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/usage_report/messages")!
            var queryItems = [
                URLQueryItem(name: "starting_at", value: startingAt),
                URLQueryItem(name: "ending_at", value: endingAt),
                URLQueryItem(name: "models[]", value: "claude-haiku-4-5-20251001"),
                URLQueryItem(name: "bucket_width", value: bucketWidth),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            if let keyId = apiKeyId, !keyId.isEmpty {
                queryItems.append(URLQueryItem(name: "api_key_ids[]", value: keyId))
            }
            if let page = nextPage {
                queryItems.append(URLQueryItem(name: "page", value: page))
            }
            components.queryItems = queryItems

            guard let url = components.url else { return nil }
            log("[MoltyAPI] \(label) page \(pageCount): \(url)")

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
                    log("[MoltyAPI] \(label) request failed")
                    return nil
                }
                httpStatus = httpResponse.statusCode
                data = respData
                if httpStatus != 429 { break }
            }

            log("[MoltyAPI] \(label) HTTP \(httpStatus)")
            guard httpStatus == 200, let data else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            if let buckets = json["data"] as? [[String: Any]] {
                for bucket in buckets {
                    guard let results = bucket["results"] as? [[String: Any]] else { continue }
                    for entry in results {
                        totalCost += costFromTokens(entry)
                    }
                }
            }

            let hasMore = json["has_more"] as? Bool ?? false
            guard hasMore, let page = json["next_page"] as? String else { break }
            nextPage = page
        }

        return totalCost
    }

    private static func costFromTokens(_ entry: [String: Any]) -> Double {
        let uncached = entry["uncached_input_tokens"] as? Int ?? 0
        let cacheRead = entry["cache_read_input_tokens"] as? Int ?? 0
        let output = entry["output_tokens"] as? Int ?? 0

        var cacheWrite = 0
        if let cacheCreation = entry["cache_creation"] as? [String: Any] {
            cacheWrite += cacheCreation["ephemeral_5m_input_tokens"] as? Int ?? 0
            cacheWrite += cacheCreation["ephemeral_1h_input_tokens"] as? Int ?? 0
        }

        return (Double(uncached) * inputRate
              + Double(cacheRead) * cacheReadRate
              + Double(cacheWrite) * cacheWriteRate
              + Double(output) * outputRate) / 1_000_000.0
    }
}
