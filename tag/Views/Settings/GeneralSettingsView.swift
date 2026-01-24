import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var store = TaggerStore.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var concurrencyBinding: Binding<Int> {
        Binding(
            get: { store.config.concurrency ?? 0 },
            set: { store.config.concurrency = $0 == 0 ? nil : $0 }
        )
    }

    private var scheduleBinding: Binding<Int> {
        Binding(
            get: { store.config.scheduleSeconds ?? TaggerDefaults.scheduleSeconds },
            set: { store.config.scheduleSeconds = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Scan Interval") {
                    Picker("", selection: scheduleBinding) {
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                        Text("15 minutes").tag(900)
                        Text("30 minutes").tag(1800)
                        Text("1 hour").tag(3600)
                        Text("2 hours").tag(7200)
                        Text("6 hours").tag(21600)
                        Text("12 hours").tag(43200)
                        Text("24 hours").tag(86400)
                    }
                    .frame(width: 140)
                }

                LabeledContent("Concurrency") {
                    Picker("", selection: concurrencyBinding) {
                        Text("Auto").tag(0)
                        ForEach(1...16, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .frame(width: 100)
                }
            } header: {
                Text("Performance")
            } footer: {
                Text("Concurrency controls how many folders are scanned in parallel. Auto uses the number of CPU cores.")
            }

            Section {
                Toggle("Write Finder comment from git origin", isOn: $store.config.writeFinderComment)
            } header: {
                Text("Finder Integration")
            } footer: {
                Text("When enabled, the git repository name (owner/repo) will be written as the Finder comment for each folder.")
            }

            Section {
                Button("Reset Onboarding") {
                    hasCompletedOnboarding = false
                }
                .disabled(!hasCompletedOnboarding)
            } header: {
                Text("Onboarding")
            } footer: {
                Text("Resets the onboarding flow so it shows again.")
            }

            Section {
                HStack {
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

#Preview {
    GeneralSettingsView()
        .frame(width: 480, height: 340)
}
