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

    private var advicePhrases: [String] {
        switch self {
        case .healthy:
            return [
                "Let's go!",
                "Fresh shell!",
                "Claws out!",
                "Feeling snappy",
                "Ocean's clear",
                "Seize the bait!",
                "Shell yeah!",
                "Tides are right",
                "Ready to snap"
            ]
        case .watching:
            return [
                "Cruising",
                "Steady claws",
                "Swimming along",
                "In flow",
                "Making waves",
                "Riding the tide"
            ]
        case .warning:
            return [
                "Wrap it up",
                "Riptides ahead",
                "Heavy current",
                "Shell's tight",
                "Watch the trap",
                "Nets nearby",
                "Shallow waters",
                "Getting crabby"
            ]
        case .heavy:
            return [
                "Time to molt!",
                "Shed that shell!",
                "Fresh start time",
                "Shell's cracking",
                "Molt o'clock",
                "Feeling the pinch!",
                "Boiling point!",
                "Escape the pot!",
                "Butter's melting"
            ]
        }
    }

    var advice: String {
        advicePhrases.randomElement() ?? advicePhrases[0]
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

    /// Health state based on context window usage (0.0 to 1.0)
    static func fromContextPercent(_ percent: Double) -> SessionHealthState {
        if percent > 0.85 {
            return .heavy      // >85% context used — time to molt
        } else if percent > 0.65 {
            return .warning    // >65% — wrap it up
        } else if percent > 0.40 {
            return .watching   // >40% — cruising
        }
        return .healthy        // <40% — let's go
    }
}
