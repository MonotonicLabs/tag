import SwiftUI

struct TagsSettingsView: View {
    @ObservedObject private var store = TaggerStore.shared

    var body: some View {
        Form {
            Section {
                TagSettingRow(
                    title: "Git Synced",
                    description: "Folder has a git repo with remote, no uncommitted or unpushed changes",
                    tag: $store.config.tags.gitSynced
                )

                TagSettingRow(
                    title: "Local Changes",
                    description: "Folder has uncommitted changes or unpushed commits",
                    tag: $store.config.tags.gitLocalChanges
                )

                TagSettingRow(
                    title: "Local Git Only",
                    description: "Folder has a git repo but no remote origin configured",
                    tag: $store.config.tags.localGitOnly
                )

                TagSettingRow(
                    title: "No Git Repo",
                    description: "Folder does not contain a git repository",
                    tag: $store.config.tags.noGitRepo
                )

                TagSettingRow(
                    title: "Multiple Git Repos",
                    description: "Folder groups multiple child repositories",
                    tag: $store.config.tags.multipleGitRepos
                )

                TagSettingRow(
                    title: "Unexpected File",
                    description: "Item is a file instead of a folder (usually disabled)",
                    tag: $store.config.tags.unexpectedFile
                )
            } header: {
                Text("Status Tags")
            } footer: {
                Text("Configure which Finder tags are applied based on git status. Uncheck to skip applying that tag.")
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        store.config.tags = TaggerConfig.default.tags
                        store.save()
                    }

                    Spacer()

                    Button("Save Changes") {
                        store.save()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct TagSettingRow: View {
    let title: String
    let description: String
    @Binding var tag: TagDefinition

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $tag.enabled)
                .toggleStyle(.checkbox)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                TextField("Tag Name", text: $tag.name)
                    .textFieldStyle(.plain)
                    .fontWeight(.medium)
                    .disabled(!tag.enabled)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            FinderColorPicker(colorIndex: $tag.colorIndex)
                .disabled(!tag.enabled)
                .frame(width: 100)
        }
        .padding(.vertical, 4)
        .opacity(tag.enabled ? 1 : 0.6)
    }
}

#Preview {
    TagsSettingsView()
        .frame(width: 480, height: 400)
}
