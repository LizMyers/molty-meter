import SwiftUI
import AppKit

private let titleColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)  // #BBBBBB
private let textColor = Color(red: 0xDD/255.0, green: 0xDD/255.0, blue: 0xDD/255.0)   // #DDDDDD

struct MoltyView: View {
    @ObservedObject var data: SessionDataProvider
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            // Main view (front)
            mainContent
                .opacity(isShowingSettings ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingSettings ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Settings view (back)
            SettingsView(isShowingSettings: $isShowingSettings)
                .opacity(isShowingSettings ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingSettings ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.easeInOut(duration: 0.4), value: isShowingSettings)
        .onChange(of: isShowingSettings) { newValue in
            // Refresh data when returning from settings
            if !newValue {
                data.refresh()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if data.hasActiveSession {
            activeView
        } else {
            emptyState
        }
    }

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with settings button
            HStack {
                Text("Molty Meter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(titleColor)

                Spacer()

                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            // Two gauges side by side: Session (large) + Budget (small battery)
            HStack(alignment: .bottom, spacing: 12) {
                // Session arc (larger)
                ArcGaugeView(
                    sessionProgress: data.healthState.arcProgress,
                    budgetProgress: data.budgetPercentUsed,
                    healthState: data.healthState
                )
                .frame(width: 170, height: 97)

                // Budget gauge - shows amount SPENT (fills as you spend)
                BatteryGaugeView(progress: data.budgetPercentUsed, size: 40)  // 10% bigger
                    .offset(x: -10, y: -33)  // Left 10px, up 33px
            }
            .frame(maxWidth: .infinity)

            // Advice row
            HStack {
                Text("Status")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor)
                Spacer()
                Text(data.currentAdvice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
            }
            .padding(.top, 30)
            .padding(.bottom, 8)

            divider

            // Metrics
            metricRow(label: "Context", value: data.formattedTokens)
            divider
            HStack {
                Text("Monthly")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(textColor)
                Spacer()
                (Text(String(format: "$%.2f", data.monthlySpend))
                    .foregroundColor(.white)
                + Text(String(format: "/$%.0f", data.monthlyBudget))
                    .foregroundColor(textColor))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture {
                if let url = URL(string: "https://console.anthropic.com/settings/cost") {
                    NSWorkspace.shared.open(url)
                }
            }
            divider
            metricRow(label: "Forecast", value: data.forecastText)
            divider
            metricRow(label: "Model", value: data.displayModelName)
            divider

            Spacer()

            // Byline
            Button(action: {
                if let url = URL(string: "https://github.com/lizmyers/") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Text("by Liz Myers")
                        .font(.system(size: 13))
                        .foregroundColor(textColor.opacity(0.6))
                    Spacer()
                    Text("v1.0")
                        .font(.system(size: 13))
                        .foregroundColor(textColor.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Molty Meter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(titleColor)

                Spacer()

                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

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
