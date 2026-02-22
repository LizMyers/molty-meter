import Foundation

enum ModelProvider {
    case anthropic
    case openAI
    case unknown(String) // stores the raw model name for display

    static func from(modelName: String) -> ModelProvider {
        let lower = modelName.lowercased()
        if lower.hasPrefix("claude") { return .anthropic }
        if lower.hasPrefix("gpt") || lower.hasPrefix("o1") || lower.hasPrefix("o3") { return .openAI }
        return .unknown(modelName)
    }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openAI: return "OpenAI"
        case .unknown(let model):
            // Try to derive a readable provider name from the model
            let lower = model.lowercased()
            if lower.hasPrefix("gemini") { return "Google" }
            if lower.hasPrefix("deepseek") { return "DeepSeek" }
            if lower.hasPrefix("mistral") || lower.hasPrefix("codestral") { return "Mistral" }
            return model
        }
    }

    var costURL: String? {
        switch self {
        case .openAI: return "https://platform.openai.com/settings/organization/limits"
        case .anthropic: return "https://console.anthropic.com/settings/cost"
        case .unknown: return nil
        }
    }

    var isOpenAI: Bool {
        if case .openAI = self { return true }
        return false
    }

    var isAnthropic: Bool {
        if case .anthropic = self { return true }
        return false
    }
}
