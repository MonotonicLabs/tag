import SwiftUI

struct SchedulerStatusBadge: View {
    let installed: Bool
    let loaded: Bool

    private var isActive: Bool {
        installed && loaded
    }

    var body: some View {
        SettingsLink {
            HStack(spacing: 4) {
                Circle()
                    .fill(isActive ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                Text(isActive ? "Scheduler Active" : "Scheduler Off")
                    .font(.caption)
                    .foregroundColor(isActive ? .secondary : .orange)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isActive ? "Scheduler is running in the background" : "Click to open Settings and enable scheduler")
    }
}

#Preview {
    VStack(spacing: 12) {
        SchedulerStatusBadge(installed: true, loaded: true)
        SchedulerStatusBadge(installed: true, loaded: false)
        SchedulerStatusBadge(installed: false, loaded: false)
    }
    .padding()
}
