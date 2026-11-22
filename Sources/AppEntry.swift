import AppKit
import SwiftUI

@main
struct AppEntry: App {
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

            CommandGroup(after: .appTermination) {
                Button("Remove All Scripts & Quit…") {
                    confirmRemoveAll()
                }
            }
        }
    }

    private func confirmRemoveAll() {
        let alert = NSAlert()
        alert.messageText = "Remove all scripts and quit?"
        alert.informativeText = "Every \(AppInfo.name) launch agent will be stopped and deleted. Log files are kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove All & Quit")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        model.removeAllAndQuit()
    }
}
