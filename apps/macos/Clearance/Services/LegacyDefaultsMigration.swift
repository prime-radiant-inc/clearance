import Foundation

struct LegacyDefaultsMigration {
    static let legacyBundleIdentifier = "com.jesse.Clearance"
    static let defaultMigrationFlagKey = "didMigrateLegacyDefaults"

    private let userDefaults: UserDefaults
    private let sourceDomainName: String
    private let destinationDomainName: String
    private let migrationFlagKey: String

    init(
        userDefaults: UserDefaults = .standard,
        sourceDomainName: String = legacyBundleIdentifier,
        destinationDomainName: String = Bundle.main.bundleIdentifier ?? "com.primeradiant.Clearance",
        migrationFlagKey: String = defaultMigrationFlagKey
    ) {
        self.userDefaults = userDefaults
        self.sourceDomainName = sourceDomainName
        self.destinationDomainName = destinationDomainName
        self.migrationFlagKey = migrationFlagKey
    }

    func migrateIfNeeded() {
        let destinationDomain = userDefaults.persistentDomain(forName: destinationDomainName) ?? [:]
        if destinationDomain[migrationFlagKey] as? Bool == true {
            return
        }

        var mergedDomain = userDefaults.persistentDomain(forName: sourceDomainName) ?? [:]
        for (key, value) in destinationDomain {
            mergedDomain[key] = value
        }
        mergedDomain[migrationFlagKey] = true

        userDefaults.setPersistentDomain(mergedDomain, forName: destinationDomainName)
    }
}
