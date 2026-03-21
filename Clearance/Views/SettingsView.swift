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

            LabeledContent("Default File Types") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AppSettings.allFileTypes, id: \.extension) { fileType in
                        Toggle(fileType.label, isOn: Binding(
                            get: { settings.enabledFileTypes.contains(fileType.extension) },
                            set: { enabled in
                                if enabled {
                                    settings.enabledFileTypes.insert(fileType.extension)
                                } else if settings.enabledFileTypes.count > 1 {
                                    settings.enabledFileTypes.remove(fileType.extension)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Text("Only selected file types will appear in projects and folder imports.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Install Command-Line Tool") {
                    installCommandLineTool()
                }

                Text("Adds `clearance` to `/usr/local/bin` so Terminal can open files and folders in Clearance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let commandLineToolStatus {
                    Text(commandLineToolStatus)
                        .font(.caption)
                        .foregroundStyle(commandLineToolStatusIsError ? .red : .secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
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
        } catch {
            commandLineToolStatus = error.localizedDescription
            commandLineToolStatusIsError = true
        }
    }
}
