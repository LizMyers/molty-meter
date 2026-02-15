import SwiftUI

enum SessionHealthState: Equatable {
    case healthy
    case watching
    case warning
    case heavy

    var color: Color {
        switch self {
        case .healthy: return .green
        case .watching: return .yellow
        case .warning: return .orange
        case .heavy: return .red
        }
    }

    var advice: String {
        switch self {
        case .healthy: return "Let's Go!"
        case .watching: return "Cruising"
        case .warning: return "Wrap it up"
        case .heavy: return "Time to molt!"
        }
    }

    var adviceColor: Color {
        switch self {
        case .healthy: return .green
        case .watching: return .yellow
        case .warning: return .orange
        case .heavy: return .white
        }
    }

    /// Arc progress: 0.0 (green) to 1.0 (red)
    var arcProgress: Double {
        switch self {
        case .healthy: return 0.15
        case .watching: return 0.45
        case .warning: return 0.7
        case .heavy: return 0.95
        }
    }

    static func from(cost: Double, totalTokens: Int) -> SessionHealthState {
        if cost > 5.0 || totalTokens > 1_000_000 {
            return .heavy
        } else if cost > 3.50 || totalTokens > 750_000 {
            return .warning
        } else if cost > 2.0 || totalTokens > 500_000 {
            return .watching
        }
        return .healthy
    }
}
