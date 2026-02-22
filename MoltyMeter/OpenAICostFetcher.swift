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

enum OpenAICostFetcher {

    // Cache: re-fetch every 30 minutes
    private static var cachedCost: Double?
    private static var lastFetchTime: Date?

    /// Fetch monthly cost from OpenAI's /v1/organization/costs endpoint.
    /// Uses costStartDate if set, otherwise defaults to start of current month.
    /// Returns exact billing amounts (matches OpenAI dashboard).
    static func fetchMonthlyCost(apiKey: String, costStartDate: String? = nil) async -> Double? {
        if let cached = cachedCost, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < 1800 {
            return cached
        }

        log("[OpenAI] fetchMonthlyCost called")
        let calendar = Calendar.current
        let now = Date()

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

        let startTime = Int(startDate.timeIntervalSince1970)

        var components = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
        components.queryItems = [
            URLQueryItem(name: "start_time", value: String(startTime)),
            URLQueryItem(name: "bucket_width", value: "1d"),
            URLQueryItem(name: "limit", value: "31"),
        ]

        guard let url = components.url else { return nil }
        log("[OpenAI] URL: \(url)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var data: Data?
        var httpStatus: Int = 0
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 2_000_000_000)
            }
            guard let (respData, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse else {
                log("[OpenAI] Request failed (attempt \(attempt + 1)/3)")
                if attempt < 2 { continue }
                return nil
            }
            httpStatus = httpResponse.statusCode
            data = respData
            if httpStatus != 429 { break }
        }

        log("[OpenAI] HTTP \(httpStatus)")
        guard httpStatus == 200, let data else {
            if let data, let body = String(data: data, encoding: .utf8) {
                log("[OpenAI] Error body: \(body.prefix(200))")
            }
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Response: { "data": [ { "results": [ { "amount": { "value": 1.23, ... } } ] } ] }
        var totalDollars: Double = 0

        if let buckets = json["data"] as? [[String: Any]] {
            for bucket in buckets {
                if let results = bucket["results"] as? [[String: Any]] {
                    for entry in results {
                        if let amount = entry["amount"] as? [String: Any],
                           let value = amount["value"] as? Double {
                            totalDollars += value
                        }
                    }
                }
            }
        }

        log("[OpenAI] Total: $\(String(format: "%.2f", totalDollars))")

        cachedCost = totalDollars
        lastFetchTime = Date()

        return totalDollars
    }
}
