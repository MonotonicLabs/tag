//
//  tagApp.swift
//  tag
//
//  Created by Oliy on 1/23/26.
//

import AppKit
import SwiftUI

private enum AppMode {
    case ui
    case runOnce

    static func fromArguments(_ args: [String]) -> AppMode {
        args.contains("--run-once") ? .runOnce : .ui
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mode = AppMode.fromArguments(CommandLine.arguments)

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard mode == .runOnce else { return }
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard mode == .runOnce else { return }
        Task.detached {
            let code = await HeadlessRunner.runOnce()
            exit(code)
        }
    }
}

@main
struct tagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let mode = AppMode.fromArguments(CommandLine.arguments)

    var body: some Scene {
        WindowGroup {
            if mode == .ui {
                MainView(store: TaggerStore.shared)
            } else {
                EmptyView()
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .newItem) {
                Button("Add Folders...") {
                    TaggerStore.shared.pickAndAddRoots()
                    TaggerStore.shared.save()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Scan") {
                Button("Scan Now") {
                    Task { await TaggerStore.shared.runNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(TaggerStore.shared.isRunning)

                Divider()

                Button("Refresh Scheduler Status") {
                    TaggerStore.shared.refreshSchedulerStatus()
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
