// ClearanceInstallHelper/main.swift
import Foundation

guard CommandLine.arguments.count == 3 else {
    print("Usage: ClearanceInstallHelper <source> <destination>")
    exit(1)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2])

do {
    try HelperInstaller.install(source: source, destination: destination)
    // Empty stdout on success — the app reads empty pipe as success
} catch {
    print(error.localizedDescription)
    exit(1)
}
