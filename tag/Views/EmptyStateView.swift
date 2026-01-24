import SwiftUI

struct EmptyStateView: View {
    let onAddFolders: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Folders", systemImage: "folder.badge.plus")
        } description: {
            Text("Add folders to track their git status.\nFolders will be tagged based on whether they have uncommitted changes, unpushed commits, or are fully synced.\n\nYou can also drag and drop folders here.")
        } actions: {
            Button("Add Folders...", action: onAddFolders)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(onAddFolders: {})
}
