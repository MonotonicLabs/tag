import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @ObservedObject var store: TaggerStore
    @State private var isDragOver = false
    @State private var showOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if store.config.roots.isEmpty {
                EmptyStateView(onAddFolders: {
                    store.pickAndAddRoots()
                    store.save()
                })
            } else {
                FoldersTableView(store: store)
            }
        }
        .frame(minWidth: 780, idealWidth: 780, minHeight: 400)
        .navigationTitle("Tag")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    store.pickAndAddRoots()
                    store.save()
                }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .help("Add folders to track (⌘O)")

                Button(action: { Task { await store.runNow() } }) {
                    if store.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Scan Now", systemImage: "play.fill")
                    }
                }
                .disabled(store.isRunning)
                .help("Scan all folders now (⌘R)")
            }
        }
        .animation(.default, value: store.config.roots.isEmpty)
        .overlay {
            if isDragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(Color.accentColor.opacity(0.1))
                    .padding(8)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onAppear {
            showOnboarding = !hasCompletedOnboarding
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            showOnboarding = !newValue
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(store: store, isPresented: $showOnboarding)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.hasDirectoryPath else { return }

                DispatchQueue.main.async {
                    let path = url.path
                    if !store.config.roots.contains(path) {
                        store.config.roots.append(path)
                        store.config.roots.sort()
                        store.save()
                    }
                }
            }
        }
    }
}

#Preview {
    MainView(store: TaggerStore.shared)
}
