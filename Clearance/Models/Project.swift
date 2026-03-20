import Foundation

struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var directoryPaths: [String]
    var excludedPaths: [String]
    var enabledFileTypes: [String]?

    init(id: UUID = UUID(), name: String, directoryPaths: [String] = [], excludedPaths: [String] = [], enabledFileTypes: [String]? = nil) {
        self.id = id
        self.name = name
        self.directoryPaths = directoryPaths
        self.excludedPaths = excludedPaths
        self.enabledFileTypes = enabledFileTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        directoryPaths = try container.decode([String].self, forKey: .directoryPaths)
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        enabledFileTypes = try container.decodeIfPresent([String].self, forKey: .enabledFileTypes)
    }
}
