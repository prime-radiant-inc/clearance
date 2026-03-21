import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
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
                Button("Install Command-Line Tool") {
                    installCommandLineTool()
                }

                Text("Adds `clearance` to `/usr/local/bin` so Terminal can open files and folders in Clearance. That location may require admin privileges on some Macs.")
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

    private func installCommandLineTool() {
        guard let helperExecutableURL = ClearanceCommandLineTool.helperExecutableURL() else {
            commandLineToolStatus = "Bundled helper executable not found."
            commandLineToolStatusIsError = true
            return
        }

        do {
            try ClearanceCommandLineToolInstaller.install(helperExecutableURL: helperExecutableURL)
            commandLineToolStatus = "Installed `clearance` at \(ClearanceCommandLineToolInstaller.installURL.path)."
            commandLineToolStatusIsError = false
        } catch ClearanceCommandLineToolInstallerError.privilegedInstallCancelled {
            commandLineToolStatus = nil
            commandLineToolStatusIsError = false
        } catch {
            commandLineToolStatus = error.localizedDescription
            commandLineToolStatusIsError = true
        }
    }
}
