import SwiftUI

private let textColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)

struct MoltyView: View {
    @ObservedObject var data: SessionDataProvider

    var body: some View {
        if data.hasActiveSession {
            activeView
        } else {
            emptyState
        }
    }

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Molty Meter")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .padding(.bottom, 8)

            // Arc gauge with lobster
            ArcGaugeView(
                progress: data.healthState.arcProgress,
                healthState: data.healthState
            )
            .frame(height: 110)
            .padding(.horizontal, 4)

            // Advice row
            HStack {
                Text("Advice")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor)
                Spacer()
                Text(data.healthState.advice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            divider

            // Metrics
            metricRow(label: "Session Cost", value: String(format: "$%.2f", data.sessionCost))
            divider
            metricRow(label: "Tokens used", value: data.formattedTokens)
            divider
            metricRow(label: "Budget used", value: "\(Int(data.budgetPercentUsed * 100))%")
            divider
            metricRow(label: "Model", value: data.displayModelName)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("Molty Meter")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text("🦞")
                .font(.system(size: 40))
                .opacity(0.3)

            Text("No active session")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(textColor)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
        }
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}
