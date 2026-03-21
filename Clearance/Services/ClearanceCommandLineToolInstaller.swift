import Foundation
import Security

// AuthorizationExecuteWithPrivileges is deprecated and unavailable in Swift.
// We redeclare it via @_silgen_name to call the underlying C symbol directly.
@_silgen_name("AuthorizationExecuteWithPrivileges")
private func _AuthorizationExecuteWithPrivileges(
    _ authorization: AuthorizationRef,
    _ pathToTool: UnsafePointer<CChar>,
    _ options: AuthorizationFlags,
    _ arguments: UnsafePointer<UnsafeMutablePointer<CChar>?>,
    _ communicationsPipe: UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
) -> OSStatus

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case existingInstallIsNotASymlink(URL)
    case installDirectoryNotWritable(URL)
    case privilegedInstallCancelled
    case privilegedInstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .existingInstallIsNotASymlink(let url):
            return "\(url.path) already exists and is not a symlink."
        case .installDirectoryNotWritable(let url):
            return "\(url.path) is not writable. Could not obtain admin privileges."
        case .privilegedInstallCancelled:
            return nil
        case .privilegedInstallFailed(let message):
            return message
        }
    }
}

struct ClearanceCommandLineToolInstaller {
    struct PrivilegedRunner: @unchecked Sendable {
        var run: (_ source: URL, _ destination: URL) throws -> Void

        init(_ run: @escaping (_ source: URL, _ destination: URL) throws -> Void) {
            self.run = run
        }

        static let live = PrivilegedRunner { source, destination in
            let helperBinary = Bundle.main.bundleURL
                .appending(path: "Contents", directoryHint: .isDirectory)
                .appending(path: "Helpers", directoryHint: .isDirectory)
                .appending(path: "ClearanceInstallHelper")
            guard FileManager.default.fileExists(atPath: helperBinary.path) else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "ClearanceInstallHelper not found in app bundle."
                )
            }
            var authRef: AuthorizationRef?
            let createStatus = AuthorizationCreate(nil, nil, [], &authRef)
            guard createStatus == errSecSuccess, let authRef else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Authorization failed (\(createStatus))."
                )
            }
            defer { AuthorizationFree(authRef, [.destroyRights]) }

            var copyStatus: OSStatus = errSecSuccess
            "system.privilege.admin".withCString { nameCStr in
                var item = AuthorizationItem(name: nameCStr, valueLength: 0, value: nil, flags: 0)
                withUnsafeMutablePointer(to: &item) { itemPtr in
                    var rights = AuthorizationRights(count: 1, items: itemPtr)
                    copyStatus = AuthorizationCopyRights(
                        authRef, &rights, nil,
                        [.interactionAllowed, .extendRights, .preAuthorize],
                        nil
                    )
                }
            }

            if copyStatus == errAuthorizationCanceled {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallCancelled
            }
            guard copyStatus == errSecSuccess else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Authorization failed (\(copyStatus))."
                )
            }

            var pipe: UnsafeMutablePointer<FILE>? = nil
            var execStatus: OSStatus = errSecSuccess
            source.path.withCString { sourceCStr in
                destination.path.withCString { destCStr in
                    var srcPtr = UnsafeMutablePointer(mutating: sourceCStr)
                    var dstPtr = UnsafeMutablePointer(mutating: destCStr)
                    var args: [UnsafeMutablePointer<CChar>?] = [srcPtr, dstPtr, nil]
                    execStatus = args.withUnsafeMutableBufferPointer { buf in
                        _AuthorizationExecuteWithPrivileges(
                            authRef, helperBinary.path, [], buf.baseAddress!, &pipe
                        )
                    }
                }
            }

            guard execStatus == errSecSuccess else {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(
                    "Could not launch installer (\(execStatus))."
                )
            }

            var output = ""
            if let pipe {
                var buffer = [CChar](repeating: 0, count: 512)
                while fgets(&buffer, Int32(buffer.count), pipe) != nil {
                    output += String(cString: buffer)
                }
                fclose(pipe)
            }

            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                throw ClearanceCommandLineToolInstallerError.privilegedInstallFailed(message)
            }
        }
    }

    static let installURL = URL(fileURLWithPath: "/usr/local/bin/clearance")

    static func install(
        helperExecutableURL: URL,
        at installURL: URL = installURL,
        fileManager: FileManager = .default,
        privilegedRunner: PrivilegedRunner = .live
    ) throws {
        let installDirectoryURL = installURL.deletingLastPathComponent()
        let directoryExists = fileManager.fileExists(atPath: installDirectoryURL.path)
        let directoryWritable = fileManager.isWritableFile(atPath: installDirectoryURL.path)

        if directoryExists && !directoryWritable {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
            return
        }

        do {
            try fileManager.createDirectory(
                at: installDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError
        {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
            return
        }

        if (try? fileManager.destinationOfSymbolicLink(atPath: installURL.path)) != nil {
            try fileManager.removeItem(at: installURL)
        } else if fileManager.fileExists(atPath: installURL.path) {
            throw ClearanceCommandLineToolInstallerError.existingInstallIsNotASymlink(installURL)
        }

        do {
            try fileManager.createSymbolicLink(at: installURL, withDestinationURL: helperExecutableURL)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError
        {
            try installWithPrivileges(
                helperExecutableURL: helperExecutableURL,
                installURL: installURL,
                privilegedRunner: privilegedRunner
            )
        }
    }

    private static func installWithPrivileges(
        helperExecutableURL: URL,
        installURL: URL,
        privilegedRunner: PrivilegedRunner
    ) throws {
        try privilegedRunner.run(helperExecutableURL, installURL)
    }
}
