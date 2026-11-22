import AppKit
import SwiftUI

struct EditScriptView: View {
    @ObservedObject var model: ScriptListModel
    /// `nil` when adding.
    let script: Script?

    @Environment(\.dismiss) private var dismiss

    @StateBox private var name: String
    @StateBox private var command: String
    @StateBox private var workingDirectory: String
    @StateBox private var startAtLogin: Bool
    @StateBox private var restartOnCrash: Bool
    @StateBox private var errorMessage: String?

    init(model: ScriptListModel, script: Script? = nil) {
        self.model = model
        self.script = script
        _name = State(initialValue: script?.name ?? "")
        _command = State(initialValue: script?.command ?? "")
        _workingDirectory = State(initialValue: script?.workingDirectory ?? NSHomeDirectory())
        _startAtLogin = State(initialValue: script?.startAtLogin ?? true)
        _restartOnCrash = State(initialValue: script?.restartOnCrash ?? true)
    }

    private var isEditing: Bool {
        script != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Script" : "Add Script")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name")
                    TextField("my-app", text: $name)
                        .disabled(isEditing)
                }
                GridRow {
                    Text("Command")
                    TextField("npm run dev", text: $command)
                }
                GridRow {
                    Text("Directory")
                    HStack(spacing: 8) {
                        TextField("/Users/you/Code/app", text: $workingDirectory)
                        Button("Choose…") {
                            chooseDirectory()
                        }
                    }
                }
            }

            if isEditing {
                Text("The name identifies the launch agent. To rename, remove it and add it again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Name: lowercase letters, digits, - and _ only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Start at login", isOn: $startAtLogin)
            Toggle("Restart on crash", isOn: $restartOnCrash)

            if looksLikeBackgroundCommand {
                Text("This command looks like it runs in the background. launchd needs a foreground process, so it may be restarted over and over.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560, height: 400)
    }

    private var looksLikeBackgroundCommand: Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return false
        }
        return trimmed.hasSuffix("&")
            || trimmed.contains("pm2 start")
            || trimmed.contains("nohup")
            || trimmed.contains("--daemon")
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(
            fileURLWithPath: (workingDirectory as NSString).expandingTildeInPath,
            isDirectory: true
        )

        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedDirectory = (workingDirectory as NSString).expandingTildeInPath

        do {
            if let script {
                try ScriptName.validate(script.name)
            } else {
                try model.validateNewName(trimmedName)
            }

            guard !trimmedCommand.isEmpty else {
                throw ScriptError.emptyCommand
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expandedDirectory, isDirectory: &isDirectory),
                  isDirectory.boolValue
            else {
                errorMessage = "Working directory does not exist."
                return
            }

            let updated = Script(
                name: isEditing ? (script?.name ?? trimmedName) : trimmedName,
                command: command,
                workingDirectory: expandedDirectory,
                startAtLogin: startAtLogin,
                restartOnCrash: restartOnCrash
            )

            if let script {
                model.update(script, to: updated)
            } else {
                model.add(updated)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
