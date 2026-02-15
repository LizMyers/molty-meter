import Foundation

struct ModelPricing {
    let inputPerMillion: Double
    let outputPerMillion: Double
    let cacheReadPerMillion: Double
    let cacheWritePerMillion: Double
}

struct CostCalculator {
    static let pricing: [String: ModelPricing] = [
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
    ]

    static func cost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        guard let p = pricing[model] else { return 0 }
        let input = Double(inputTokens) / 1_000_000.0 * p.inputPerMillion
        let output = Double(outputTokens) / 1_000_000.0 * p.outputPerMillion
        let cacheRead = Double(cacheReadTokens) / 1_000_000.0 * p.cacheReadPerMillion
        let cacheWrite = Double(cacheWriteTokens) / 1_000_000.0 * p.cacheWritePerMillion
        return input + output + cacheRead + cacheWrite
    }
}
