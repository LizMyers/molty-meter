import Foundation

struct ModelPricing {
    let inputPerMillion: Double
    let outputPerMillion: Double
    let cacheReadPerMillion: Double
    let cacheWritePerMillion: Double
}

struct CostCalculator {
    static let pricing: [String: ModelPricing] = [
        // Anthropic Claude
        "claude-opus-4-6": ModelPricing(
            inputPerMillion: 15.00, outputPerMillion: 75.00,
            cacheReadPerMillion: 1.50, cacheWritePerMillion: 18.75
        ),
        "claude-opus-4-5": ModelPricing(
            inputPerMillion: 15.00, outputPerMillion: 75.00,
            cacheReadPerMillion: 1.50, cacheWritePerMillion: 18.75
        ),
        "claude-sonnet-4-5": ModelPricing(
            inputPerMillion: 3.00, outputPerMillion: 15.00,
            cacheReadPerMillion: 0.30, cacheWritePerMillion: 3.75
        ),
        "claude-haiku-4-5": ModelPricing(
            inputPerMillion: 0.80, outputPerMillion: 4.00,
            cacheReadPerMillion: 0.08, cacheWritePerMillion: 1.00
        ),
        // OpenAI GPT — update prices at https://platform.openai.com/docs/pricing
        "gpt-4o-mini": ModelPricing(
            inputPerMillion: 0.15, outputPerMillion: 0.60,
            cacheReadPerMillion: 0.075, cacheWritePerMillion: 0.00
        ),
        "gpt-4o": ModelPricing(
            inputPerMillion: 2.50, outputPerMillion: 10.00,
            cacheReadPerMillion: 1.25, cacheWritePerMillion: 0.00
        ),
        "gpt-4-turbo": ModelPricing(
            inputPerMillion: 10.00, outputPerMillion: 30.00,
            cacheReadPerMillion: 0.00, cacheWritePerMillion: 0.00
        ),
        "gpt-4": ModelPricing(
            inputPerMillion: 30.00, outputPerMillion: 60.00,
            cacheReadPerMillion: 0.00, cacheWritePerMillion: 0.00
        ),
        "gpt-3.5-turbo": ModelPricing(
            inputPerMillion: 0.50, outputPerMillion: 1.50,
            cacheReadPerMillion: 0.00, cacheWritePerMillion: 0.00
        ),
    ]

    static func cost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        // Match model by prefix (e.g., "claude-opus-4-5-20251101" matches "claude-opus-4-5")
        guard let p = pricing.first(where: { model.hasPrefix($0.key) })?.value else { return 0 }
        let input = Double(inputTokens) / 1_000_000.0 * p.inputPerMillion
        let output = Double(outputTokens) / 1_000_000.0 * p.outputPerMillion
        let cacheRead = Double(cacheReadTokens) / 1_000_000.0 * p.cacheReadPerMillion
        let cacheWrite = Double(cacheWriteTokens) / 1_000_000.0 * p.cacheWritePerMillion
        return input + output + cacheRead + cacheWrite
    }
}
