import SwiftUI

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
                Button(action: { isShowingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                }
                .buttonStyle(.plain)

                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(titleColor)

                Spacer()
            }
            .padding(.bottom, 24)

            // Budget input
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly API Budget")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)

                HStack {
                    Text("$")
                        .foregroundColor(textColor)
                    TextField("", text: $budgetText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 100)
                        .onSubmit { saveBudget() }
                }
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                Text("Track spend against your Anthropic API budget")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.7))
            }

            Spacer()

            // Save button
            Button(action: saveBudget) {
                Text("Save")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
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
        isShowingSettings = false
    }
}
