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

    for flag in parsed.unsupportedFlags {
        FileHandle.standardError.write(
            Data("\(ClearanceCommandLineTool.name): unsupported flag: \(flag)\n".utf8)
        )
    }

    let exitStatus: Int32 = parsed.unsupportedFlags.isEmpty ? 0 : 1
    if parsed.helpRequested {
        print(ClearanceCommandLineTool.helpText)
        exit(exitStatus)
    }

    // Flag-only invocation (unsupported flag, no files): warn but do not launch.
    if parsed.filePaths.isEmpty && !parsed.unsupportedFlags.isEmpty {
        exit(exitStatus)
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
    exit(exitStatus)
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
