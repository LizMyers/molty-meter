import Foundation

struct MoltyConfig: Codable {
    var monthlyBudget: Double

    static let defaultBudget: Double = 100.0

    static func load() -> MoltyConfig {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".molty-meter.json")

        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(MoltyConfig.self, from: data) else {
            return MoltyConfig(monthlyBudget: defaultBudget)
        }
        return config
    }

    func save() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".molty-meter.json")

        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: configPath)
        }
    }
}
