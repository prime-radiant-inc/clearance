import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var commandLineToolInstallLocation: ClearanceCommandLineToolInstallLocation = .systemBin
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
                Picker("Install Location", selection: $commandLineToolInstallLocation) {
                    ForEach(ClearanceCommandLineToolInstallLocation.allCases) { location in
                        Text(location.title).tag(location)
                    }
                }
                .pickerStyle(.segmented)

                Button("Install Command-Line Tool") {
                    installCommandLineTool()
                }

                Text(commandLineToolInstallDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let commandLineToolStatus {
                    Text(commandLineToolStatus)
                        .font(.caption)
                        .foregroundStyle(commandLineToolStatusIsError ? .red : .secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 440)
    }

    private var commandLineToolInstallDescription: String {
        switch commandLineToolInstallLocation {
        case .systemBin:
            return "Adds `clearance` to `/usr/local/bin` using the bundled installer package. This may require admin privileges."
        case .localBin:
            return "Adds `clearance` to `~/.local/bin` for this user without admin privileges. Make sure `~/.local/bin` is on your shell PATH."
        }
    }

    private func installCommandLineTool() {
        do {
            try ClearanceCommandLineToolInstaller.install(to: commandLineToolInstallLocation)
            commandLineToolStatus = commandLineToolInstallSuccessMessage
            commandLineToolStatusIsError = false
        } catch {
            commandLineToolStatus = error.localizedDescription
            commandLineToolStatusIsError = true
        }
    }

    private var commandLineToolInstallSuccessMessage: String {
        switch commandLineToolInstallLocation {
        case .systemBin:
            return "Opened the command-line installer package in Installer."
        case .localBin:
            return "Installed clearance in ~/.local/bin."
        }
    }
}
