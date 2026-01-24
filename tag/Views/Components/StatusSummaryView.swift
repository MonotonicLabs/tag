import SwiftUI

struct StatusSummaryView: View {
    let summary: RootStatusSummary
    var compact: Bool = false

    var body: some View {
        if summary.hasResults {
            HStack(spacing: compact ? 8 : 12) {
                if summary.synced > 0 {
                    StatusCount(count: summary.synced, icon: "checkmark.circle.fill", color: .green)
                }
                if summary.localChanges > 0 {
                    StatusCount(count: summary.localChanges, icon: "exclamationmark.circle.fill", color: .orange)
                }
                if summary.localOnly > 0 {
                    StatusCount(count: summary.localOnly, icon: "arrow.triangle.branch", color: .gray)
                }
                if summary.noGit > 0 {
                    StatusCount(count: summary.noGit, icon: "folder.fill", color: .red)
                }
            }
        } else {
            Text("Not scanned")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct StatusCount: View {
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusSummaryView(summary: RootStatusSummary(
            synced: 5,
            localChanges: 2,
            localOnly: 1,
            noGit: 0,
            total: 8
        ))

        StatusSummaryView(summary: RootStatusSummary(
            synced: 10,
            localChanges: 0,
            localOnly: 0,
            noGit: 0,
            total: 10
        ))

        StatusSummaryView(summary: RootStatusSummary())
    }
    .padding()
}
