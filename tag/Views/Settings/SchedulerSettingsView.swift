import AppKit
import SwiftUI

struct SchedulerSettingsView: View {
    @ObservedObject private var store = TaggerStore.shared
    @State private var isInstalling = false
    @State private var isUninstalling = false

    private var isActive: Bool {
        store.schedulerInstalled && store.schedulerLoaded
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isActive ? "Scheduler is Active" : "Scheduler is Off")
                            .fontWeight(.medium)

                        if isActive {
                            Text("Folders are scanned automatically in the background")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Enable the scheduler to scan folders automatically")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    if isActive {
                        Button("Run Now") {
                            Task { await store.runScheduledNow() }
                        }

                        Button("Disable Scheduler") {
                            Task {
                                isUninstalling = true
                                await store.uninstallScheduler()
                                isUninstalling = false
                            }
                        }
                        .disabled(isUninstalling)
                    } else {
                        Button("Enable Scheduler") {
                            Task {
                                isInstalling = true
                                await store.installOrUpdateScheduler()
                                isInstalling = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling)
                    }

                    if isInstalling || isUninstalling {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } header: {
                Text("Background Scheduler")
            }

            Section {
                LabeledContent("Last Scheduled Scan") {
                    if let date = store.lastScheduledRunAt {
                        Text(date, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.tertiary)
                    }
                }

                LabeledContent("Last Manual Scan") {
                    if let date = store.lastManualRunAt {
                        Text(date, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Last Run")
            } footer: {
                Text("Scans are persisted to disk so results can be shown when the app launches, even if the scheduler ran while the app was closed.")
            }

            Section {
                LabeledContent("LaunchAgent") {
                    Text(TaggerPaths.launchAgentLabel())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Plist Location") {
                    Text(TaggerPaths.launchAgentPlistURL().path)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                LabeledContent("Log Directory") {
                    HStack {
                        Text(TaggerPaths.logsDirectoryURL().path)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TaggerPaths.logsDirectoryURL().path)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Open in Finder")
                    }
                }

                LabeledContent("Scheduler Debug Log") {
                    HStack {
                        Text(TaggerPaths.schedulerOutLogURL().path)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            revealLogFile(TaggerPaths.schedulerOutLogURL())
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal log file in Finder")
                    }
                }

                LabeledContent("Scheduler Error Log") {
                    HStack {
                        Text(TaggerPaths.schedulerErrLogURL().path)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            revealLogFile(TaggerPaths.schedulerErrLogURL())
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.borderless)
                        .help("Reveal log file in Finder")
                    }
                }
            } header: {
                Text("Technical Details")
            } footer: {
                Text("The scheduler runs as a macOS LaunchAgent in the background, even when this app is closed.")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Refresh Status") {
                        store.refreshSchedulerStatus()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func revealLogFile(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: TaggerPaths.logsDirectoryURL().path)
        }
    }
}

#Preview {
    SchedulerSettingsView()
        .frame(width: 480, height: 400)
}
