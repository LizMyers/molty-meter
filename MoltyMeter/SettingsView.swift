import SwiftUI
import AppKit

private let titleColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)
private let textColor = Color(red: 0xDD/255.0, green: 0xDD/255.0, blue: 0xDD/255.0)

struct SettingsView: View {
    @Binding var isShowingSettings: Bool
    @State private var budgetText: String = ""
    @State private var config = MoltyConfig.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { saveBudget(); isShowingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .padding(.leading, 5)

                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.bottom, 16)

            // Settings content
            Spacer().frame(height: 8)

            Text("Monthly Budget")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .padding(.horizontal, 15)

            Spacer().frame(height: 12)

            HStack(spacing: 4) {
                Text("$")
                    .foregroundColor(textColor)
                    .font(.system(size: 18, weight: .medium))
                TextField("", text: $budgetText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 60)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal, 15)

            Spacer().frame(height: 32)

            Button(action: {
                if let url = URL(string: "https://console.anthropic.com/settings/cost") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Text("View Cost Data")
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .padding(.horizontal, 15)

            Spacer().frame(height: 8)

            Text("Opens cost data on Anthropic")
                .font(.system(size: 12))
                .foregroundColor(textColor.opacity(0.6))
                .padding(.horizontal, 15)

            Spacer().frame(height: 32)

            // TLDR title
            Text("Molty TLDR:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.horizontal, 15)

            Spacer().frame(height: 8)

            // Explanation
            Text("The circle tracks monthly spend against your API budget. The arc shows session health — molting early keeps each message lean and your spending efficient.")
                .font(.system(size: 12))
                .foregroundColor(textColor.opacity(0.6))
                .padding(.horizontal, 15)

            Spacer()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            budgetText = String(format: "%.0f", config.monthlyBudget)
        }
    }

    private func saveBudget() {
        if let value = Double(budgetText), value > 0 {
            config.monthlyBudget = value
            config.save()
        }
    }
}
