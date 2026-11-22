import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ScriptListModel

    @State private var selection: String?
    @State private var presentedSheet: PresentedSheet?
    @State private var pendingRemoval: Script?

    private let refreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if model.scripts.isEmpty {
                Text("No scripts. Click + to add one.")
                    .foregroundStyle(.secondary)
            } else {
                List(selection: $selection) {
                    ForEach(model.scripts) { script in
                        ScriptRow(
                            script: script,
                            status: model.statuses[script.label] ?? .notLoaded,
                            model: model
                        ) {
                            presentedSheet = .log(script)
                        }
                        .tag(script.id)
                    }
                }
            }
        }
        .frame(minWidth: 780, minHeight: 420)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                Text("macOS may show “Background item added”. Keep \(AppInfo.name) allowed in System Settings → General → Login Items → Allow in the Background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    presentedSheet = .addScript
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add Script")

                Button {
                    if let selectedScript {
                        presentedSheet = .editScript(selectedScript)
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(selectedScript == nil)
                .help("Edit Script")

                Button {
                    pendingRemoval = selectedScript
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedScript == nil)
                .help("Remove Script")

                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh Status")
            }
        }
        .onAppear {
            model.refresh()
        }
        .onReceive(refreshTimer) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addScript:
                EditScriptView(model: model)
            case .editScript(let script):
                EditScriptView(model: model, script: script)
            case .log(let script):
                LogView(script: script, logURL: model.logURL(for: script))
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Remove script?", isPresented: removalBinding, presenting: pendingRemoval) { script in
            Button("Remove", role: .destructive) {
                model.remove(script)
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: { _ in
            Text("This stops the script and deletes its launch agent. The log file is kept.")
        }
    }

    private var selectedScript: Script? {
        guard let selection else {
            return nil
        }
        return model.scripts.first { $0.id == selection }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorMessage = nil
                }
            }
        )
    }

    private var removalBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRemoval = nil
                }
            }
        )
    }
}

private struct ScriptRow: View {
    let script: Script
    let status: LaunchctlStatus
    @ObservedObject var model: ScriptListModel
    let onShowLog: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: status)
                .help(statusDescription)

            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.headline)
                Text(script.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if case .exited(let code) = status, code != 0 {
                    Text("Keeps exiting. launchd retries every ~10 s. Check the log.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 12)

            Text(statusText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)

            HStack(spacing: 8) {
                Button("Start") {
                    model.start(script)
                }
                Button("Stop") {
                    model.stop(script)
                }
                Button("Restart") {
                    model.restart(script)
                }
                Button("Logs") {
                    onShowLog()
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch status {
        case .running(let pid):
            return "PID \(pid)"
        case .exited(let code):
            return "Exit \(code)"
        case .disabled:
            return "Stopped"
        case .notLoaded:
            return "Not loaded"
        }
    }

    private var statusDescription: String {
        switch status {
        case .running(let pid):
            return "Running (PID \(pid))"
        case .exited(let code):
            return "Exited (code \(code))"
        case .disabled:
            return "Stopped and disabled at login"
        case .notLoaded:
            return "Not loaded"
        }
    }
}

private struct StatusDot: View {
    let status: LaunchctlStatus

    var body: some View {
        Group {
            switch status {
            case .running:
                Circle().fill(Color.green)
            case .exited(let code) where code != 0:
                Circle().fill(Color.red)
            case .exited, .disabled:
                Circle().fill(Color.secondary)
            case .notLoaded:
                Circle().strokeBorder(Color.secondary, lineWidth: 1.5)
            }
        }
        .frame(width: 10, height: 10)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch status {
        case .running:
            return "Running"
        case .exited(let code):
            return "Exited with code \(code)"
        case .disabled:
            return "Stopped"
        case .notLoaded:
            return "Not loaded"
        }
    }
}

private enum PresentedSheet: Identifiable {
    case addScript
    case editScript(Script)
    case log(Script)

    var id: String {
        switch self {
        case .addScript:
            return "add"
        case .editScript(let script):
            return "edit-\(script.id)"
        case .log(let script):
            return "log-\(script.id)"
        }
    }
}
