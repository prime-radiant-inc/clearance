import XCTest
@testable import Clearance

final class LegacyDefaultsMigrationTests: XCTestCase {
    func testMigrateIfNeededCopiesLegacyDomainIntoDestinationDomain() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sourceDomainName = "LegacyDefaultsMigrationTests.source.\(UUID().uuidString)"
        let destinationDomainName = "LegacyDefaultsMigrationTests.destination.\(UUID().uuidString)"
        let migrationFlagKey = "didMigrateLegacyDefaults"

        defaults.removePersistentDomain(forName: sourceDomainName)
        defaults.removePersistentDomain(forName: destinationDomainName)
        defer {
            defaults.removePersistentDomain(forName: sourceDomainName)
            defaults.removePersistentDomain(forName: destinationDomainName)
        }

        defaults.setPersistentDomain(
            [
                "defaultOpenMode": "edit",
                "theme": "classicBlue",
                "recentFiles": Data("[]".utf8)
            ],
            forName: sourceDomainName
        )

        let migration = LegacyDefaultsMigration(
            userDefaults: defaults,
            sourceDomainName: sourceDomainName,
            destinationDomainName: destinationDomainName,
            migrationFlagKey: migrationFlagKey
        )

        migration.migrateIfNeeded()

        let migrated = try XCTUnwrap(defaults.persistentDomain(forName: destinationDomainName))
        XCTAssertEqual(migrated["defaultOpenMode"] as? String, "edit")
        XCTAssertEqual(migrated["theme"] as? String, "classicBlue")
        XCTAssertEqual(migrated["recentFiles"] as? Data, Data("[]".utf8))
        XCTAssertEqual(migrated[migrationFlagKey] as? Bool, true)
    }

    func testMigrateIfNeededPreservesExistingDestinationValues() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sourceDomainName = "LegacyDefaultsMigrationTests.source.\(UUID().uuidString)"
        let destinationDomainName = "LegacyDefaultsMigrationTests.destination.\(UUID().uuidString)"
        let migrationFlagKey = "didMigrateLegacyDefaults"

        defaults.removePersistentDomain(forName: sourceDomainName)
        defaults.removePersistentDomain(forName: destinationDomainName)
        defer {
            defaults.removePersistentDomain(forName: sourceDomainName)
            defaults.removePersistentDomain(forName: destinationDomainName)
        }

        defaults.setPersistentDomain(
            [
                "theme": "classicBlue",
                "appearance": "dark"
            ],
            forName: sourceDomainName
        )
        defaults.setPersistentDomain(
            [
                "theme": "apple",
                "renderedTextScale": 1.25
            ],
            forName: destinationDomainName
        )

        let migration = LegacyDefaultsMigration(
            userDefaults: defaults,
            sourceDomainName: sourceDomainName,
            destinationDomainName: destinationDomainName,
            migrationFlagKey: migrationFlagKey
        )

        migration.migrateIfNeeded()

        let migrated = try XCTUnwrap(defaults.persistentDomain(forName: destinationDomainName))
        XCTAssertEqual(migrated["theme"] as? String, "apple")
        XCTAssertEqual(migrated["appearance"] as? String, "dark")
        XCTAssertEqual(migrated["renderedTextScale"] as? Double, 1.25)
        XCTAssertEqual(migrated[migrationFlagKey] as? Bool, true)
    }

    func testMigrateIfNeededIsIdempotent() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sourceDomainName = "LegacyDefaultsMigrationTests.source.\(UUID().uuidString)"
        let destinationDomainName = "LegacyDefaultsMigrationTests.destination.\(UUID().uuidString)"
        let migrationFlagKey = "didMigrateLegacyDefaults"

        defaults.removePersistentDomain(forName: sourceDomainName)
        defaults.removePersistentDomain(forName: destinationDomainName)
        defer {
            defaults.removePersistentDomain(forName: sourceDomainName)
            defaults.removePersistentDomain(forName: destinationDomainName)
        }

        defaults.setPersistentDomain(["theme": "classicBlue"], forName: sourceDomainName)

        let migration = LegacyDefaultsMigration(
            userDefaults: defaults,
            sourceDomainName: sourceDomainName,
            destinationDomainName: destinationDomainName,
            migrationFlagKey: migrationFlagKey
        )

        migration.migrateIfNeeded()
        defaults.setPersistentDomain(["theme": "apple", migrationFlagKey: true], forName: destinationDomainName)
        defaults.setPersistentDomain(["theme": "dark"], forName: sourceDomainName)

        migration.migrateIfNeeded()

        let migrated = try XCTUnwrap(defaults.persistentDomain(forName: destinationDomainName))
        XCTAssertEqual(migrated["theme"] as? String, "apple")
        XCTAssertEqual(migrated[migrationFlagKey] as? Bool, true)
    }

    func testMigrateIfNeededMarksMigrationWithoutLegacyDomain() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sourceDomainName = "LegacyDefaultsMigrationTests.source.\(UUID().uuidString)"
        let destinationDomainName = "LegacyDefaultsMigrationTests.destination.\(UUID().uuidString)"
        let migrationFlagKey = "didMigrateLegacyDefaults"

        defaults.removePersistentDomain(forName: sourceDomainName)
        defaults.removePersistentDomain(forName: destinationDomainName)
        defer {
            defaults.removePersistentDomain(forName: sourceDomainName)
            defaults.removePersistentDomain(forName: destinationDomainName)
        }

        let migration = LegacyDefaultsMigration(
            userDefaults: defaults,
            sourceDomainName: sourceDomainName,
            destinationDomainName: destinationDomainName,
            migrationFlagKey: migrationFlagKey
        )

        migration.migrateIfNeeded()

        let migrated = try XCTUnwrap(defaults.persistentDomain(forName: destinationDomainName))
        XCTAssertEqual(migrated[migrationFlagKey] as? Bool, true)
        XCTAssertEqual(migrated.count, 1)
    }
}
