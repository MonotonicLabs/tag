import SwiftUI
import AppKit

struct FoldersTableView: View {
    @ObservedObject var store: TaggerStore
    @State private var selection: Set<String> = []
    @State private var selectedRoot: String? = nil  // nil = showing roots, non-nil = showing children
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickedPath: String?

    private var schedulerEnabled: Bool {
        store.schedulerInstalled && store.schedulerLoaded
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.schedulerNeedsReinstall {
                SchedulerReinstallBanner(store: store)
            } else if !schedulerEnabled && store.lastRunAt != nil {
                SchedulerPromptBanner(store: store)
            }

            if let error = store.lastErrorMessage {
                ErrorBannerView(message: error) {
                    store.lastErrorMessage = nil
                }
            }

            // Breadcrumb / Back navigation
            if let root = selectedRoot {
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRoot = nil
                            selection.removeAll()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("All Folders")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                    Text("/")
                        .foregroundStyle(.tertiary)

                    Text((root as NSString).lastPathComponent)
                        .fontWeight(.medium)

                    Spacer()

                    let summary = store.statusSummary(for: root)
                    if summary.hasResults {
                        Text("\(summary.total) repositories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)

                Divider()
            }

            // Table content
            if let root = selectedRoot {
                childrenTable(for: root)
            } else {
                rootsTable
            }

            StatusBarView(store: store)
        }
        .onDeleteCommand {
            if selectedRoot == nil {
                deleteSelectedRoots()
            }
        }
        .onKeyPress(.return) {
            if selectedRoot == nil, let selected = selection.first {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedRoot = selected
                    selection.removeAll()
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if selectedRoot != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedRoot = nil
                    selection.removeAll()
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Roots Table

    private var rootsTable: some View {
        Table(of: RootFolderRow.self, selection: $selection) {
            TableColumn("Folder") { row in
                DoubleClickableRow(
                    onDoubleClick: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRoot = row.path
                            selection.removeAll()
                        }
                    }
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.displayName)
                                .fontWeight(.medium)
                            Text(row.path)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .width(min: 200, ideal: 300)

            TableColumn("Status") { row in
                let summary = store.statusSummary(for: row.path)
                if store.isRunning && !summary.hasResults {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    StatusSummaryView(summary: summary)
                }
            }
            .width(min: 140, ideal: 180)

            TableColumn("Repos") { row in
                let summary = store.statusSummary(for: row.path)
                if summary.hasResults {
                    Text("\(summary.total)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(50)

            TableColumn("Last Scan") { row in
                if let lastScan = store.lastRunAt {
                    Text(lastScan, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(100)
        } rows: {
            ForEach(store.config.roots.map { RootFolderRow(path: $0) }) { row in
                TableRow(row)
                    .contextMenu {
                        Button("View Repositories") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedRoot = row.path
                                selection.removeAll()
                            }
                        }

                        Divider()

                        Button("Show in Finder") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: row.path)
                        }

                        Button("Open in Terminal") {
                            openInTerminal(path: row.path)
                        }

                        Divider()

                        Button("Remove", role: .destructive) {
                            if let index = store.config.roots.firstIndex(of: row.path) {
                                store.removeRoot(at: index)
                                store.save()
                            }
                        }
                    }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Children Table

    private func childrenTable(for root: String) -> some View {
        let children = store.childFolders(for: root)

        return Group {
            if children.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "folder")
                } description: {
                    Text("Run a scan to see the repositories in this folder")
                } actions: {
                    Button("Scan Now") {
                        Task { await store.runNow() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Table(of: ChildFolderRow.self, selection: $selection) {
                    TableColumn("Repository") { row in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                            Text(row.displayName)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .width(min: 150, ideal: 200)

                    TableColumn("Origin") { row in
                        if let origin = row.origin {
                            Text(origin)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(origin)
                        } else {
                            Text("—")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("Status") { row in
                        StatusTagView(status: row.folderStatus)
                    }
                    .width(100)
                } rows: {
                    ForEach(children.map { ChildFolderRow(path: $0.path, status: $0.status, origin: $0.origin, rootPath: root) }) { row in
                        TableRow(row)
                            .contextMenu {
                                Button("Show in Finder") {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: row.path)
                                }

                                Button("Open in Terminal") {
                                    openInTerminal(path: row.path)
                                }

                                if let origin = row.origin {
                                    Divider()
                                    Button("Copy Origin") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(origin, forType: .string)
                                    }
                                }
                            }
                    }
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Helpers

    private func deleteSelectedRoots() {
        for path in selection {
            if let index = store.config.roots.firstIndex(of: path) {
                store.removeRoot(at: index)
            }
        }
        selection.removeAll()
        store.save()
    }

    private func openInTerminal(path: String) {
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(escapedPath)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Row Types

struct RootFolderRow: Identifiable {
    let id: String
    let path: String
    let displayName: String

    init(path: String) {
        self.id = path
        self.path = path
        self.displayName = (path as NSString).lastPathComponent
    }
}

struct ChildFolderRow: Identifiable {
    let id: String
    let path: String
    let displayName: String
    let relativePath: String
    let folderStatus: FolderStatus
    let origin: String?

    init(path: String, status: FolderScanResult.Status, origin: String?, rootPath: String) {
        self.id = path
        self.path = path
        self.displayName = (path as NSString).lastPathComponent
        self.origin = origin

        if path.hasPrefix(rootPath) {
            let relative = String(path.dropFirst(rootPath.count))
            self.relativePath = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        } else {
            self.relativePath = path
        }

        switch status {
        case .synced: self.folderStatus = .synced
        case .localChanges: self.folderStatus = .localChanges
        case .localOnly: self.folderStatus = .localOnly
        case .noGit: self.folderStatus = .noGit
        case .file, .error: self.folderStatus = .pending
        }
    }
}

// MARK: - Double Click Handler

struct DoubleClickableRow<Content: View>: View {
    let onDoubleClick: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(DoubleClickHandler(onDoubleClick: onDoubleClick))
    }
}

struct DoubleClickHandler: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> DoubleClickNSView {
        let view = DoubleClickNSView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: DoubleClickNSView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }
}

class DoubleClickNSView: NSView {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }
}

// MARK: - String Identifiable

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Supporting Views

struct SchedulerPromptBanner: View {
    @ObservedObject var store: TaggerStore
    @State private var isEnabling = false
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable automatic scanning?")
                        .fontWeight(.medium)
                    Text("Keep your tags up to date in the background")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isEnabling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Enable") {
                        Task {
                            isEnabling = true
                            await store.installOrUpdateScheduler()
                            isEnabling = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    withAnimation {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
        }
    }
}

struct SchedulerReinstallBanner: View {
    @ObservedObject var store: TaggerStore
    @State private var isReinstalling = false
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduler settings changed")
                        .fontWeight(.medium)
                    Text("Reinstall the scheduler to apply your new scan interval")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isReinstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Reinstall") {
                        Task {
                            isReinstalling = true
                            await store.reinstallScheduler()
                            isReinstalling = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    withAnimation {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
        }
    }
}

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            Text(message)
                .font(.callout)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.15))
    }
}

#Preview {
    FoldersTableView(store: TaggerStore.shared)
        .frame(width: 600, height: 400)
}
