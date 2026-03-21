import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var installLocation: CLIInstallLocation = .dotLocalBin
    @State private var commandLineToolStatus: String?
    @State private var commandLineToolStatusIsError = false

    var body: some View {
        Form {
            Picker("Default Open Mode", selection: $settings.defaultOpenMode) {
                ForEach(WorkspaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Newly opened files start in this mode.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.radioGroup)

            Text(settings.theme.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppearancePreference.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Picker("Install Location", selection: $installLocation) {
                    ForEach(CLIInstallLocation.allCases) { location in
                        Text(location.title).tag(location)
                    }
                }
                .pickerStyle(.segmented)

                Button("Install Command-Line Tool") {
                    installCommandLineTool()
                }

                Text(commandLineToolDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let commandLineToolStatus {
                    Text(commandLineToolStatus)
                        .font(.caption)
                        .foregroundStyle(commandLineToolStatusIsError ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(width: 440)
    }

    private var commandLineToolDescription: String {
        switch installLocation {
        case .usrLocalBin:
            "Adds `clearance` to `/usr/local/bin` so Terminal can open files and folders in Clearance. Opens a package installer that may require admin privileges."
        case .dotLocalBin:
            "Adds `clearance` to `~/.local/bin` so Terminal can open files and folders in Clearance. No admin privileges required."
        }
    }

    private func installCommandLineTool() {
        do {
            try ClearanceCommandLineToolInstaller.install(to: installLocation)
            switch installLocation {
            case .usrLocalBin:
                commandLineToolStatus = "Opened the command-line installer package in Installer."
            case .dotLocalBin:
                commandLineToolStatus = "Symlink created at ~/.local/bin/clearance."
            }
            commandLineToolStatusIsError = false
        } catch {
            commandLineToolStatus = error.localizedDescription
            commandLineToolStatusIsError = true
        }
    }
}
