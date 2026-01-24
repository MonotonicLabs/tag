import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var store: TaggerStore
    @Binding var isPresented: Bool
    @State private var currentStep: OnboardingStep = .welcome
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case automation
        case addFolders
        case enableScheduler
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView()
                case .automation:
                    AutomationStepView()
                case .addFolders:
                    AddFoldersStepView(store: store)
                case .enableScheduler:
                    EnableSchedulerStepView(store: store)
                case .done:
                    DoneStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation buttons
            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        withAnimation {
                            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = prev
                            }
                        }
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                }

                Spacer()

                if currentStep == .done {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") {
                        withAnimation {
                            if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                                currentStep = next
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 420)
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Step Views

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Tag")
                .font(.title)
                .fontWeight(.semibold)

            Text("Tag automatically applies Finder tags to your folders based on their git status, helping you see at a glance which projects need attention.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "checkmark.circle.fill", color: .green, text: "Synced - fully pushed to remote")
                FeatureRow(icon: "exclamationmark.circle.fill", color: .orange, text: "Changes - uncommitted or unpushed work")
                FeatureRow(icon: "arrow.triangle.branch", color: .gray, text: "Local only - no remote configured")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AutomationStepView: View {
    @State private var testResult: AutomationTestResult = .unknown

    enum AutomationTestResult {
        case unknown, testing, granted, denied
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "applescript")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Automation Permission")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tag uses AppleScript to set Finder comments with the git repository name. When prompted, please allow Tag to control Finder.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    switch testResult {
                    case .unknown:
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                        Text("Not tested yet")
                            .foregroundStyle(.secondary)
                    case .testing:
                        ProgressView()
                            .controlSize(.small)
                        Text("Testing...")
                            .foregroundStyle(.secondary)
                    case .granted:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Automation permission granted")
                    case .denied:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Permission denied - check System Settings")
                    }
                }

                Button("Test Automation") {
                    testAutomation()
                }
            }
            .padding(.top, 8)

            Text("If you don't want Finder comments, you can disable this in Settings and skip this step.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private func testAutomation() {
        testResult = .testing

        let script = """
        tell application "Finder"
            return name of startup disk
        end tell
        """

        DispatchQueue.global().async {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    testResult = error == nil ? .granted : .denied
                }
            }
        }
    }
}

private struct AddFoldersStepView: View {
    @ObservedObject var store: TaggerStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Add Your Project Folders")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add the parent directories that contain your git repositories. Tag will scan each folder inside and apply the appropriate tags.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            VStack(spacing: 12) {
                if store.config.roots.isEmpty {
                    Text("No folders added yet")
                        .foregroundStyle(.tertiary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(store.config.roots, id: \.self) { path in
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.secondary)
                                    Text((path as NSString).lastPathComponent)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 80)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Button("Add Folders...") {
                    store.pickAndAddRoots()
                    store.save()
                }
            }
            .padding(.top, 8)

            Text("You can add more folders later from the File menu or by dragging them into the app.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

private struct EnableSchedulerStepView: View {
    @ObservedObject var store: TaggerStore
    @State private var isEnabling = false

    var isEnabled: Bool {
        store.schedulerInstalled && store.schedulerLoaded
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Enable Background Scanning")
                .font(.title2)
                .fontWeight(.semibold)

            Text("For the best experience, enable the background scheduler. Tag will automatically scan your folders and update tags every 5 minutes, even when the app is closed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text(isEnabled ? "Scheduler is enabled" : "Scheduler is not enabled")
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                }

                if !isEnabled {
                    Button("Enable Scheduler") {
                        Task {
                            isEnabling = true
                            await store.installOrUpdateScheduler()
                            isEnabling = false
                        }
                    }
                    .disabled(isEnabling)
                } else {
                    Text("You're all set!")
                        .foregroundStyle(.green)
                }

                if isEnabling {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.top, 8)

            Text("You can change the scan interval or disable the scheduler anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .onAppear {
            store.refreshSchedulerStatus()
        }
    }
}

private struct DoneStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.semibold)

            Text("Tag is ready to go. Your folders will be scanned and tagged automatically. You can always access settings with ⌘, or run a scan manually with ⌘R.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(keys: "⌘R", description: "Scan folders now")
                ShortcutRow(keys: "⌘O", description: "Add more folders")
                ShortcutRow(keys: "⌘,", description: "Open Settings")
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(description)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    OnboardingView(store: TaggerStore.shared, isPresented: .constant(true))
}
