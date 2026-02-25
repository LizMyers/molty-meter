import Foundation
import Combine

@MainActor
class SessionDataProvider: ObservableObject {
    @Published var totalTokens: Int = 0
    @Published var inputTokens: Int = 0
    @Published var outputTokens: Int = 0
    @Published var cacheReadTokens: Int = 0
    @Published var cacheWriteTokens: Int = 0
    @Published var modelName: String = "—"
    @Published var sessionDuration: TimeInterval = 0
    @Published var burnRate: Double = 0  // dollars per minute
    @Published var healthState: SessionHealthState = .healthy
    @Published var currentAdvice: String = "Let's go!"
    @Published var hasActiveSession: Bool = false
    @Published var monthlyBudget: Double = 100.0
    @Published var monthlySpend: Double = 0
    @Published var contextLimit: Int = 0
    @Published var forecastText: String = "—"

    var budgetPercentUsed: Double { monthlyBudget > 0 ? min(1.0, monthlySpend / monthlyBudget) : 0 }

    /// Burn rate progress for the arc gauge (0.0 = no burn, 1.0 = max)
    /// Mapped so $0.20/min = max (red zone)
    var burnRateProgress: Double {
        min(1.0, burnRate / 0.20)
    }

    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMin = minutes % 60
        return "\(hours)h \(remainingMin)m"
    }

    var formattedBurnRate: String {
        String(format: "$%.2f/min", burnRate)
    }

    var formattedTokens: String {
        let used = formatTokenCount(totalTokens)
        let limit = formatTokenCount(contextLimit)
        return "\(used) / \(limit)"
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
        return "\(count / 1000)k"
    }

    var displayModelName: String {
        // "claude-opus-4-6" -> "Opus 4.6", "gpt-5.1" -> "GPT 5.1"
        let name = modelName
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-", with: " ")
        guard let firstSpace = name.firstIndex(of: " ") else { return name.capitalized }
        let familyLower = String(name[name.startIndex..<firstSpace]).lowercased()
        let version = String(name[name.index(after: firstSpace)...])
            .replacingOccurrences(of: " ", with: ".")
        // All-caps model families
        let allCapsFamilies = ["gpt", "o1", "o3"]
        if allCapsFamilies.contains(familyLower) {
            return "\(familyLower.uppercased()) \(version)"
        }
        return "\(familyLower.capitalized) \(version)"
    }

    private var previousTotalTokens: Int = 0
    private var fallbackTimer: Timer?
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var monitoredFileDescriptor: Int32 = -1
    private var currentMonitoredPath: String?

    func startMonitoring() {
        refresh()
        setupFileMonitor()
        // Fallback poll every 10s in case file monitor misses events
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.checkFileMonitor()
            }
        }
    }

    func stopMonitoring() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        tearDownFileMonitor()
    }

    func refresh() {
        // Load config
        let config = MoltyConfig.load()
        monthlyBudget = config.monthlyBudget

        // Load active OpenClaw session first (need model name for cost routing)
        let openclawSessions = ClaudeDataParser.loadOpenClawSessions()
        guard let session = openclawSessions.first else {
            hasActiveSession = false
            totalTokens = 0
            inputTokens = 0
            outputTokens = 0
            cacheReadTokens = 0
            cacheWriteTokens = 0
            modelName = "—"
            sessionDuration = 0
            burnRate = 0
            healthState = .healthy
            contextLimit = 0
            monthlySpend = ClaudeDataParser.openClawMonthlyCost()
            forecastText = calculateForecast()
            return
        }

        hasActiveSession = true
        previousTotalTokens = totalTokens

        inputTokens = session.inputTokens
        outputTokens = session.outputTokens
        cacheReadTokens = 0
        cacheWriteTokens = 0
        totalTokens = session.totalTokens
        contextLimit = session.contextLimit
        modelName = session.model
        sessionDuration = 0

        // Monthly spend: use provider-specific API if key available, else OpenClaw
        let provider = ModelProvider.from(modelName: modelName)

        switch provider {
        case .openAI:
            let modelPrefix = "gpt"
            if let openaiKey = config.openaiAdminKey, !openaiKey.isEmpty {
                Task { [weak self] in
                    if let cost = await OpenAICostFetcher.fetchMonthlyCost(apiKey: openaiKey, costStartDate: config.costStartDate) {
                        self?.monthlySpend = cost
                    } else {
                        self?.monthlySpend = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
                    }
                    self?.forecastText = self?.calculateForecast() ?? "—"
                }
                // Show OpenClaw estimate immediately while API loads
                let localCost = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
                if monthlySpend == 0 && localCost > 0 {
                    monthlySpend = localCost
                }
            } else {
                monthlySpend = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
            }

        case .anthropic:
            let modelPrefix = "claude"
            if let adminKey = config.anthropicAdminKey, !adminKey.isEmpty {
                Task { [weak self] in
                    if let cost = await AnthropicCostFetcher.fetchMonthlyHaikuCost(adminKey: adminKey, costStartDate: config.costStartDate) {
                        self?.monthlySpend = cost
                    } else {
                        self?.monthlySpend = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
                    }
                    self?.forecastText = self?.calculateForecast() ?? "—"
                }
                // Show OpenClaw estimate immediately while API loads
                let localCost = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
                if monthlySpend == 0 && localCost > 0 {
                    monthlySpend = localCost
                }
            } else {
                monthlySpend = ClaudeDataParser.openClawMonthlyCost(modelPrefix: modelPrefix)
            }

        case .unknown:
            monthlySpend = 0
            forecastText = "No bills!"
        }

        // Calculate forecast (skip for local/unknown models, already set above)
        if !provider.isUnknown {
            forecastText = calculateForecast()
        }

        // Health based on context usage for OpenClaw
        let newHealthState = SessionHealthState.fromContextPercent(session.contextPercent)
        if newHealthState != healthState {
            healthState = newHealthState
            currentAdvice = healthState.advice
        }
    }

    private func calculateForecast() -> String {
        guard monthlySpend > 0, monthlyBudget > 0 else { return "—" }

        let now = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)
        let daysElapsed = max(Double(day), 1.0)
        let dailyRate = monthlySpend / daysElapsed

        guard let range = calendar.range(of: .day, in: .month, for: now) else { return "—" }
        let daysInMonth = Double(range.count)
        let projectedMonthlySpend = dailyRate * daysInMonth

        if projectedMonthlySpend <= monthlyBudget {
            return "On track"
        }

        // Calculate the day the budget will be exhausted: budget / dailyRate
        let exhaustionDay = monthlyBudget / dailyRate
        guard exhaustionDay <= daysInMonth else { return "On track" }

        // Build the date for that day in the current month
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = Int(exhaustionDay.rounded(.up))
        guard let exhaustionDate = calendar.date(from: components) else { return "—" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: exhaustionDate)
    }

    // MARK: - File Monitoring

    private func setupFileMonitor() {
        // Monitor OpenClaw sessions.json
        let sessionsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/agents/main/sessions/sessions.json").path
        guard FileManager.default.fileExists(atPath: sessionsPath) else { return }
        currentMonitoredPath = sessionsPath
        startFileMonitor(path: sessionsPath)
    }

    private func startFileMonitor(path: String) {
        tearDownFileMonitor()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        monitoredFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileMonitorSource = source
    }

    private func tearDownFileMonitor() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
        monitoredFileDescriptor = -1
        currentMonitoredPath = nil
    }

    /// Re-establish file monitor if the file appeared after launch
    private func checkFileMonitor() {
        let sessionsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/agents/main/sessions/sessions.json").path
        // If not monitoring but file now exists, set up the monitor
        if fileMonitorSource == nil && FileManager.default.fileExists(atPath: sessionsPath) {
            currentMonitoredPath = sessionsPath
            startFileMonitor(path: sessionsPath)
        }
    }
}
