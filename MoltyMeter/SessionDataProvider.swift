import Foundation
import Combine

@MainActor
class SessionDataProvider: ObservableObject {
    @Published var sessionCost: Double = 0
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
    @Published var isRising: Bool = false
    @Published var hasActiveSession: Bool = false
    @Published var monthlyBudget: Double = 100.0
    @Published var monthlySpend: Double = 0
    @Published var contextLimit: Int = 0

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
        // "claude-opus-4-6" -> "Opus 4.6"
        let name = modelName
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-", with: " ")
        guard let firstSpace = name.firstIndex(of: " ") else { return name.capitalized }
        let family = String(name[name.startIndex..<firstSpace]).capitalized
        let version = String(name[name.index(after: firstSpace)...])
            .replacingOccurrences(of: " ", with: ".")
        return "\(family) \(version)"
    }

    private var previousCost: Double = 0
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

        // Calculate monthly spend (OpenClaw only - Claude Code is subscription, not API billed)
        monthlySpend = ClaudeDataParser.openClawMonthlyCost()

        // Load active OpenClaw session
        let openclawSessions = ClaudeDataParser.loadOpenClawSessions()
        guard let session = openclawSessions.first else {
            hasActiveSession = false
            sessionCost = 0
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
            return
        }

        hasActiveSession = true
        previousCost = sessionCost
        previousTotalTokens = totalTokens

        inputTokens = session.inputTokens
        outputTokens = session.outputTokens
        cacheReadTokens = 0
        cacheWriteTokens = 0
        totalTokens = session.totalTokens
        contextLimit = session.contextLimit
        modelName = session.model
        sessionDuration = 0

        // Get actual cost from JSONL file (pre-calculated by OpenClaw)
        sessionCost = ClaudeDataParser.parseOpenClawSessionTotalCost(jsonlPath: session.sessionFile)

        // Trend
        if previousCost > 0 {
            isRising = sessionCost > previousCost
        }

        // Health based on context usage for OpenClaw
        let newHealthState = SessionHealthState.fromContextPercent(session.contextPercent)
        if newHealthState != healthState {
            healthState = newHealthState
            currentAdvice = healthState.advice
        }
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

    /// Re-establish file monitor if needed
    private func checkFileMonitor() {
        // OpenClaw sessions.json path is stable, no need to re-establish
    }
}
