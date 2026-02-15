import SwiftUI

private let titleColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)
private let textColor = Color(red: 0xDD/255.0, green: 0xDD/255.0, blue: 0xDD/255.0)

enum BackPanelTab {
    case settings
    case budget
}

struct SettingsView: View {
    @Binding var isShowingSettings: Bool
    @State private var selectedTab: BackPanelTab = .settings
    @State private var budgetText: String = ""
    @State private var config = MoltyConfig.load()
    @State private var dailySpend: [DailySpend] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with back button and tabs
            HStack {
                Button(action: { isShowingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                        .frame(width: 30, height: 30)  // Larger tap target
                }
                .buttonStyle(.plain)
                .padding(.leading, 5)

                // Tab buttons
                HStack(spacing: 0) {
                    tabButton("Settings", tab: .settings)
                    tabButton("Spend", tab: .budget)
                }
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
                .offset(x: -15)
            }
            .padding(.bottom, 16)

            // Tab content
            if selectedTab == .settings {
                settingsContent
            } else {
                budgetContent
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            budgetText = String(format: "%.0f", config.monthlyBudget)
            dailySpend = BudgetReportGenerator.getDailySpend()
        }
    }

    private func tabButton(_ title: String, tab: BackPanelTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Text(title)
                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? .white : textColor.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Tab

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 8)

            Text("Monthly Budget")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .padding(.horizontal, 15)

            Spacer().frame(height: 12)

            HStack {
                Text("$")
                    .foregroundColor(textColor)
                    .font(.system(size: 16, weight: .medium))
                TextField("", text: $budgetText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 70)
                    .onSubmit { saveBudget() }
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal, 15)

            Spacer().frame(height: 10)

            // Compact save button
            Button(action: saveBudget) {
                Text("Save")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
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
    }

    // MARK: - Budget Tab

    private var budgetContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Summary row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sessions")
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.7))
                    Text("\(dailySpend.reduce(0) { $0 + $1.sessions })")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Cost")
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.7))
                    Text(String(format: "$%.2f", dailySpend.reduce(0) { $0 + $1.cost }))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            // Table header
            HStack {
                Text("Date")
                    .frame(width: 70, alignment: .leading)
                Text("Sessions")
                    .frame(width: 60, alignment: .center)
                Spacer()
                Text("Cost")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textColor.opacity(0.5))
            .padding(.horizontal, 14)  // 10 + 2 + 2 to match table data

            // Scrolling table - no background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(dailySpend.reversed(), id: \.date) { day in
                        HStack {
                            Text(formatDate(day.date))
                                .frame(width: 70, alignment: .leading)
                            Text("\(day.sessions)")
                                .frame(width: 60, alignment: .center)
                            Spacer()
                            Text(String(format: "$%.2f", day.cost))
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(textColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 2)
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func saveBudget() {
        if let value = Double(budgetText), value > 0 {
            config.monthlyBudget = value
            config.save()
        }
        isShowingSettings = false
    }
}
