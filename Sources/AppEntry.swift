import AppKit
import SwiftUI

@main
struct AppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ScriptListModel()

    var body: some Scene {
        Window(AppInfo.name, id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 900, height: 560)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppInfo.name)") {
                    AboutPanel.show()
                }
            }
            // Replacing the whole Help group drops the automatic "<App name>
            // Help" item AppKit adds, which only ever offers "Help isn't
            // available for <App name>".
            // Emptying the View menu's groups (with window tabbing off) lets
            // SwiftUI drop the menu before it is drawn.
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .help) {
                Button("\(AppInfo.name) Repository") {
                    NSWorkspace.shared.open(AboutPanel.repositoryURL)
                }
                Button("License") {
                    NSWorkspace.shared.open(AboutPanel.licenseURL)
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
