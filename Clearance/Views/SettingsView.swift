import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

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
        }
        .padding(24)
        .frame(width: 480)
    }
}
