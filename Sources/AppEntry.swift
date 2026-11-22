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
            CommandGroup(after: .help) {
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
    func applicationDidUpdate(_ notification: Notification) {
        hideViewMenu()
    }

    // SwiftUI has no placement for the View menu's window-view commands, so it
    // cannot be removed through `.commands`. Hide it; this app defines no
    // view-specific commands. Reasserted because AppKit rebuilds the menu.
    private func hideViewMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        let viewItem = mainMenu.items.first { item in
            item.title == "View" || item.submenu?.items.contains {
                $0.action == #selector(NSWindow.toggleFullScreen(_:))
            } == true
        }
        viewItem?.isHidden = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
