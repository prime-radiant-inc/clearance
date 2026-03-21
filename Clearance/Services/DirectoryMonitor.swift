import CoreServices
import Foundation

@MainActor
final class DirectoryMonitor: ObservableObject {
    @Published private(set) var treesByDirectory: [String: ProjectFileNode] = [:]

    private var monitoredPaths: Set<String> = []
    private var excludedPaths: Set<String> = []
    private var eventStream: FSEventStreamRef?
    private(set) var defaultExtensions: Set<String> = ["md", "markdown", "txt"]
    private var extensionOverrides: [String: Set<String>] = [:]

    func updateDefaultExtensions(_ extensions: Set<String>) {
        guard extensions != defaultExtensions else { return }
        defaultExtensions = extensions
        if !monitoredPaths.isEmpty {
            enumerateAllDirectories()
        }
    }

    func updateExtensionOverrides(_ overrides: [String: Set<String>]) {
        guard overrides != extensionOverrides else { return }
        let changedPaths = Set(overrides.keys).symmetricDifference(extensionOverrides.keys)
            .union(overrides.filter { extensionOverrides[$0.key] != $0.value }.keys)
        extensionOverrides = overrides
        let pathsToReenumerate = monitoredPaths.intersection(changedPaths)
        if !pathsToReenumerate.isEmpty {
            enumerateDirectories(pathsToReenumerate)
        }
    }

    private func extensions(for path: String) -> Set<String> {
        extensionOverrides[path] ?? defaultExtensions
    }

    func updateMonitoredDirectories(_ paths: Set<String>, excludedPaths: Set<String> = []) {
        let excludedChanged = excludedPaths != self.excludedPaths
        self.excludedPaths = excludedPaths

        if paths == monitoredPaths && !excludedChanged {
            return
        }

        stopStream()

        let previousPaths = monitoredPaths
        monitoredPaths = paths

        var newTrees: [String: ProjectFileNode] = [:]
        for path in paths {
            if let existing = treesByDirectory[path] {
                newTrees[path] = existing
            }
        }
        treesByDirectory = newTrees

        guard !paths.isEmpty else {
            return
        }

        let pathsToEnumerate = excludedChanged ? paths : paths.subtracting(previousPaths)
        if !pathsToEnumerate.isEmpty {
            enumerateDirectories(pathsToEnumerate)
        }
        startStream()
    }

    func stopAll() {
        stopStream()
        monitoredPaths.removeAll()
        treesByDirectory.removeAll()
    }

    private static let backgroundQueue = DispatchQueue(
        label: "com.jesse.Clearance.DirectoryMonitor",
        qos: .userInitiated
    )

    private func enumerateAllDirectories() {
        enumerateDirectories(monitoredPaths)
    }

    private func enumerateDirectories(_ paths: Set<String>) {
        let extensionsByPath = Dictionary(uniqueKeysWithValues: paths.map { ($0, extensions(for: $0)) })
        let excluded = excludedPaths

        Self.backgroundQueue.async { [weak self] in
            var results: [String: ProjectFileNode] = [:]
            for path in paths {
                let exts = extensionsByPath[path] ?? []
                results[path] = DirectoryMonitor.enumerateDirectory(path, supportedExtensions: exts, excludedPaths: excluded)
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                for (path, tree) in results {
                    if self.monitoredPaths.contains(path) {
                        self.treesByDirectory[path] = tree
                    }
                }
            }
        }
    }

    fileprivate func reenumerateAffectedPaths(_ changedPaths: [String]) {
        let roots = monitoredPaths
        let excluded = excludedPaths

        var affectedRoots: Set<String> = []
        for changedPath in changedPaths {
            for root in roots where changedPath.hasPrefix(root) {
                affectedRoots.insert(root)
            }
        }

        guard !affectedRoots.isEmpty else {
            return
        }

        let extensionsByRoot = Dictionary(uniqueKeysWithValues: affectedRoots.map { ($0, extensions(for: $0)) })

        Self.backgroundQueue.async { [weak self] in
            var results: [String: ProjectFileNode] = [:]
            for root in affectedRoots {
                let exts = extensionsByRoot[root] ?? []
                results[root] = DirectoryMonitor.enumerateDirectory(root, supportedExtensions: exts, excludedPaths: excluded)
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                for (path, tree) in results {
                    if self.monitoredPaths.contains(path) {
                        self.treesByDirectory[path] = tree
                    }
                }
            }
        }
    }

    nonisolated private static func enumerateDirectory(
        _ directoryPath: String,
        supportedExtensions: Set<String>,
        excludedPaths: Set<String>
    ) -> ProjectFileNode {
        let rootURL = URL(fileURLWithPath: directoryPath)

        // Try git ls-files first — respects .gitignore
        if let gitFiles = gitListFiles(in: directoryPath, supportedExtensions: supportedExtensions, excludedPaths: excludedPaths) {
            return buildTreeFromPaths(
                rootPath: directoryPath,
                rootName: rootURL.lastPathComponent,
                filePaths: gitFiles
            )
        }

        // Fall back to FileManager enumeration for non-git directories
        return enumerateDirectoryWithFileManager(directoryPath, supportedExtensions: supportedExtensions, excludedPaths: excludedPaths)
    }

    /// Use `git ls-files` to list tracked and untracked non-ignored files.
    nonisolated private static func gitListFiles(
        in directoryPath: String,
        supportedExtensions: Set<String>,
        excludedPaths: Set<String>
    ) -> [String]? {
        // Check if this is inside a git repo
        let gitCheck = Process()
        gitCheck.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitCheck.arguments = ["-C", directoryPath, "rev-parse", "--git-dir"]
        gitCheck.standardOutput = FileHandle.nullDevice
        gitCheck.standardError = FileHandle.nullDevice
        do {
            try gitCheck.run()
            gitCheck.waitUntilExit()
            guard gitCheck.terminationStatus == 0 else { return nil }
        } catch {
            return nil
        }

        let patterns = supportedExtensions.flatMap { ext in
            ["--", "*.\(ext)"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directoryPath, "ls-files", "--cached", "--others", "--exclude-standard"] + patterns
        process.currentDirectoryURL = URL(fileURLWithPath: directoryPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let relativePaths = output.split(separator: "\n", omittingEmptySubsequences: true)
        let rootPath = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"

        let excludedPrefixes = excludedPaths.map { $0.hasSuffix("/") ? $0 : $0 + "/" }

        return relativePaths
            .map { rootPath + $0 }
            .filter { path in
                !excludedPrefixes.contains { path.hasPrefix($0) }
            }
    }

    nonisolated private static func buildTreeFromPaths(
        rootPath: String,
        rootName: String,
        filePaths: [String]
    ) -> ProjectFileNode {
        var filesByDirectory: [String: [ProjectFileNode]] = [:]

        for path in filePaths {
            let url = URL(fileURLWithPath: path)
            let parentPath = url.deletingLastPathComponent().path
            let fileNode = ProjectFileNode(
                path: path,
                name: url.lastPathComponent,
                isDirectory: false,
                children: []
            )
            filesByDirectory[parentPath, default: []].append(fileNode)
        }

        return buildTree(
            rootPath: rootPath,
            rootName: rootName,
            filesByDirectory: filesByDirectory
        )
    }

    nonisolated private static let skippedDirectoryNames: Set<String> = [
        "node_modules", ".build", "DerivedData", "Pods",
        ".venv", "venv", "__pycache__", ".tox",
        "target", "build", "dist", ".gradle",
    ]

    nonisolated private static func enumerateDirectoryWithFileManager(
        _ directoryPath: String,
        supportedExtensions: Set<String>,
        excludedPaths: Set<String>
    ) -> ProjectFileNode {
        let rootURL = URL(fileURLWithPath: directoryPath)
        var filesByDirectory: [String: [ProjectFileNode]] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ProjectFileNode(
                path: directoryPath,
                name: rootURL.lastPathComponent,
                isDirectory: true,
                children: []
            )
        }

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
                continue
            }

            if values.isDirectory == true {
                if skippedDirectoryNames.contains(url.lastPathComponent) || excludedPaths.contains(url.path) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            let parentPath = url.deletingLastPathComponent().path
            let fileNode = ProjectFileNode(
                path: url.path,
                name: url.lastPathComponent,
                isDirectory: false,
                children: []
            )
            filesByDirectory[parentPath, default: []].append(fileNode)
        }

        return buildTree(
            rootPath: directoryPath,
            rootName: rootURL.lastPathComponent,
            filesByDirectory: filesByDirectory
        )
    }

    nonisolated private static func buildTree(
        rootPath: String,
        rootName: String,
        filesByDirectory: [String: [ProjectFileNode]]
    ) -> ProjectFileNode {
        var allDirectoryPaths: Set<String> = []
        for dirPath in filesByDirectory.keys {
            var current = dirPath
            while current.hasPrefix(rootPath) && current != rootPath {
                allDirectoryPaths.insert(current)
                current = (current as NSString).deletingLastPathComponent
            }
        }

        let sortedDirectoryPaths = allDirectoryPaths.sorted { $0 > $1 }

        var directoryNodes: [String: ProjectFileNode] = [:]

        for dirPath in sortedDirectoryPaths {
            let name = (dirPath as NSString).lastPathComponent
            var children: [ProjectFileNode] = []

            if let files = filesByDirectory[dirPath] {
                children.append(contentsOf: files.sorted { $0.name < $1.name })
            }

            let childDirPaths = allDirectoryPaths.filter {
                ($0 as NSString).deletingLastPathComponent == dirPath
            }.sorted()

            for childDirPath in childDirPaths {
                if let childNode = directoryNodes[childDirPath] {
                    children.append(childNode)
                    directoryNodes.removeValue(forKey: childDirPath)
                }
            }

            directoryNodes[dirPath] = ProjectFileNode(
                path: dirPath,
                name: name,
                isDirectory: true,
                children: children
            )
        }

        var rootChildren: [ProjectFileNode] = []

        if let rootFiles = filesByDirectory[rootPath] {
            rootChildren.append(contentsOf: rootFiles.sorted {
                $0.name < $1.name
            })
        }

        let topLevelDirPaths = directoryNodes.keys.filter {
            ($0 as NSString).deletingLastPathComponent == rootPath
        }.sorted()

        for dirPath in topLevelDirPaths {
            if let node = directoryNodes[dirPath] {
                rootChildren.append(node)
            }
        }

        return ProjectFileNode(
            path: rootPath,
            name: rootName,
            isDirectory: true,
            children: rootChildren
        )
    }

    private func startStream() {
        guard !monitoredPaths.isEmpty else {
            return
        }

        let pathsArray = Array(monitoredPaths) as CFArray
        let contextPtr = Unmanaged.passUnretained(self).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: contextPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsArray as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    private func stopStream() {
        guard let stream = eventStream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }
}

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientCallBackInfo else {
        return
    }

    let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()

    guard let cfPaths = unsafeBitCast(eventPaths, to: CFArray?.self) else {
        return
    }

    var changedPaths: [String] = []
    for i in 0..<numEvents {
        if let path = unsafeBitCast(CFArrayGetValueAtIndex(cfPaths, i), to: CFString?.self) as String? {
            changedPaths.append(path)
        }
    }

    Task { @MainActor in
        monitor.reenumerateAffectedPaths(changedPaths)
    }
}
