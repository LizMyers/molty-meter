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
    @Published var isRising: Bool = false
    @Published var hasActiveSession: Bool = false
    @Published var sessionBudget: Double = 10.0  // per-session budget ceiling

    var budgetRemaining: Double { max(0, sessionBudget - sessionCost) }
    var budgetPercentUsed: Double { sessionBudget > 0 ? min(1.0, sessionCost / sessionBudget) : 0 }

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
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000.0)
        }
        return "\(totalTokens / 1000)k"
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
        guard let session = ClaudeDataParser.loadActiveSession() else {
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
            return
        }

        hasActiveSession = true
        previousCost = sessionCost
        previousTotalTokens = totalTokens

        inputTokens = session.totalInputTokens
        outputTokens = session.totalOutputTokens
        cacheReadTokens = session.totalCacheReadTokens
        cacheWriteTokens = session.totalCacheWriteTokens
        totalTokens = session.totalTokens
        sessionCost = session.totalCost
        modelName = session.primaryModel
        sessionDuration = session.duration ?? 0

        // Burn rate: cost per minute
        if sessionDuration > 60 {
            burnRate = sessionCost / (sessionDuration / 60.0)
        } else {
            burnRate = 0
        }

        // Trend
        if previousCost > 0 {
            isRising = sessionCost > previousCost
        }

        healthState = SessionHealthState.from(cost: sessionCost, totalTokens: totalTokens)
    }

    // MARK: - File Monitoring

    private func setupFileMonitor() {
        guard let path = ClaudeDataParser.activeSessionJSONLPath() else { return }
        currentMonitoredPath = path
        startFileMonitor(path: path)
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

    /// Re-establish file monitor if session changed
    private func checkFileMonitor() {
        let newPath = ClaudeDataParser.activeSessionJSONLPath()
        if newPath != currentMonitoredPath {
            if let path = newPath {
                currentMonitoredPath = path
                startFileMonitor(path: path)
            } else {
                tearDownFileMonitor()
            }
        }
    }
}
