import XCTest

final class SmokeTests: XCTestCase {
    func testProjectCompiles() {
        XCTAssertTrue(true)
    }

    func testDMGBuilderStagesAppWithApplicationsAlias() throws {
        let macOSRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scriptURL = macOSRoot.appendingPathComponent("Packaging/build-app-dmg.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))

        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fakeBinURL = workURL.appendingPathComponent("bin", isDirectory: true)
        let appURL = workURL.appendingPathComponent("Clearance.app", isDirectory: true)
        let outputURL = workURL.appendingPathComponent("Clearance.dmg")
        let hdiutilLogURL = workURL.appendingPathComponent("hdiutil.log")

        try FileManager.default.createDirectory(at: fakeBinURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: appURL.appendingPathComponent("Contents", isDirectory: true),
            withIntermediateDirectories: true
        )

        let fakeHdiutilURL = fakeBinURL.appendingPathComponent("hdiutil")
        try """
        #!/usr/bin/env bash
        set -euo pipefail
        srcfolder=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -srcfolder)
              shift
              srcfolder="$1"
              ;;
          esac
          shift || true
        done
        {
          printf 'srcfolder=%s\\n' "$srcfolder"
          if [[ -d "$srcfolder/Clearance.app" ]]; then
            printf 'app=yes\\n'
          else
            printf 'app=no\\n'
          fi
          printf 'applications=%s\\n' "$(readlink "$srcfolder/Applications")"
        } > "$HDIUTIL_LOG"
        """.write(to: fakeHdiutilURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fakeHdiutilURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, appURL.path, outputURL.path, "Clearance"]
        process.environment = [
            "PATH": "\(fakeBinURL.path):/usr/bin:/bin:/usr/sbin:/sbin",
            "HDIUTIL_LOG": hdiutilLogURL.path
        ]

        try process.run()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)
        let log = try String(contentsOf: hdiutilLogURL, encoding: .utf8)
        XCTAssertTrue(log.contains("app=yes"))
        XCTAssertTrue(log.contains("applications=/Applications"))
    }
}
