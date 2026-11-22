import SwiftUI

struct AddScriptView: View {
    @ObservedObject var model: ScriptListModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = NSHomeDirectory()
    @State private var startAtLogin = true
    @State private var restartOnCrash = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Script")
                .font(.title3.weight(.semibold))

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Name")
                    TextField("glot", text: $name)
                }
                GridRow {
                    Text("Command")
                    TextField("glot serve", text: $command)
                }
                GridRow {
                    Text("Directory")
                    TextField("/Users/you", text: $workingDirectory)
                }
            }

            Text("Name: lowercase letters, digits, - and _ only.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Start at login", isOn: $startAtLogin)
            Toggle("Restart on crash", isOn: $restartOnCrash)

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

                Button("Add") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || command.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 340)
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedDirectory = (workingDirectory as NSString).expandingTildeInPath

        do {
            try model.validateNewName(trimmedName)

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

            model.add(
                Script(
                    name: trimmedName,
                    command: command,
                    workingDirectory: expandedDirectory,
                    startAtLogin: startAtLogin,
                    restartOnCrash: restartOnCrash
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
