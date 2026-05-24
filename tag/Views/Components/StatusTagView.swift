import SwiftUI

enum FolderStatus: String, CaseIterable {
    case synced
    case localChanges
    case localOnly
    case noGit
    case multipleGitRepos
    case pending
    case scanning

    var label: String {
        switch self {
        case .synced: return "Synced"
        case .localChanges: return "Changes"
        case .localOnly: return "Local Git"
        case .noGit: return "No Git"
        case .multipleGitRepos: return "Multi Repo"
        case .pending: return "Pending"
        case .scanning: return "Scanning"
        }
    }

    var color: Color {
        switch self {
        case .synced: return .green
        case .localChanges: return .orange
        case .localOnly: return .gray
        case .noGit: return .red
        case .multipleGitRepos: return .purple
        case .pending: return .secondary
        case .scanning: return .blue
        }
    }

    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .localChanges: return "exclamationmark.circle.fill"
        case .localOnly: return "arrow.triangle.branch"
        case .noGit: return "folder.fill"
        case .multipleGitRepos: return "folder.fill"
        case .pending: return "clock"
        case .scanning: return "arrow.clockwise"
        }
    }
}

struct StatusTagView: View {
    let status: FolderStatus
    var showLabel: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if status == .scanning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
            }

            if showLabel {
                Text(status.label)
                    .font(.callout)
                    .foregroundStyle(status == .pending ? .secondary : .primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(FolderStatus.allCases, id: \.self) { status in
            StatusTagView(status: status)
        }
    }
    .padding()
}
