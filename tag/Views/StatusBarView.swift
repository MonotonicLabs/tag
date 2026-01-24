import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: TaggerStore

    var body: some View {
        VStack(spacing: 0) {
            if store.isRunning, let progress = store.scanProgress {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
            }

            HStack(spacing: 12) {
                if store.isRunning {
                    ProgressView()
                        .controlSize(.small)

                    if let progress = store.scanProgress {
                        Text("Scanning... \(progress.completed)/\(progress.total)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Preparing scan...")
                            .foregroundStyle(.secondary)
                    }
                } else if let lastRun = store.lastRunAt {
                    let label = store.lastRunSource == .scheduled ? "Last scheduled scan" : "Last scan"
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(label): \(lastRun, format: .relative(presentation: .named))")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Not scanned yet")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SchedulerStatusBadge(
                    installed: store.schedulerInstalled,
                    loaded: store.schedulerLoaded
                )
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

#Preview {
    VStack(spacing: 0) {
        Spacer()
        StatusBarView(store: TaggerStore.shared)
    }
    .frame(height: 200)
}
