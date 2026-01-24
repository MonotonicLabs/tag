import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            TagsSettingsView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }

            SchedulerSettingsView()
                .tabItem {
                    Label("Scheduler", systemImage: "clock")
                }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400, idealHeight: 450)
    }
}

#Preview {
    SettingsView()
}
