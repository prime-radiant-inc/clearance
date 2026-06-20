import Foundation

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("\(ClearanceCommandLineTool.name): \(error.localizedDescription)\n".utf8))
    exit(1)
}

private func run() throws {
    let parsed = ClearanceCommandLineTool.parseArguments(
        Array(CommandLine.arguments.dropFirst())
    )

    if parsed.helpRequested {
        print(ClearanceCommandLineTool.helpText)
        exit(0)
    }

    for flag in parsed.unsupportedFlags {
        FileHandle.standardError.write(
            Data("\(ClearanceCommandLineTool.name): unsupported flag: \(flag)\n".utf8)
        )
    }

    // Flag-only invocation (unsupported flag, no files): warn but do not launch.
    if parsed.filePaths.isEmpty && !parsed.unsupportedFlags.isEmpty {
        exit(0)
    }

    guard let helperExecutableURL = Bundle.main.executableURL,
          let appURL = ClearanceCommandLineTool.appURL(forExecutableURL: helperExecutableURL) else {
        throw CommandError.appBundleNotFound
    }

    let documentURLs = try ClearanceCommandLineTool.prepareDocumentURLs(
        forArguments: parsed.filePaths
    )

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", appURL.path] + documentURLs.map(\.path)
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw CommandError.openFailed(process.terminationStatus)
    }
}

private enum CommandError: LocalizedError {
    case appBundleNotFound
    case openFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .appBundleNotFound:
            return "Could not locate \(ClearanceCommandLineTool.appBundleIdentifier)."
        case .openFailed(let status):
            return "`open` exited with status \(status)."
        }
    }
}
