import AppKit
import SwiftUI

@main
struct AppEntry: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ScriptListModel()

    var body: some Scene {
        WindowGroup(AppInfo.name) {
            ContentView(model: model)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppInfo.name)") {
                    AboutPanel.show()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
