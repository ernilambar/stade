import AppKit
import Combine
import Foundation

@MainActor
final class ScriptListModel: ObservableObject {
    @Published private(set) var scripts: [Script] = []
    @Published private(set) var statuses: [String: LaunchctlStatus] = [:]
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let store: LaunchAgentStore
    private let launchctl: Launchctl

    nonisolated init(store: LaunchAgentStore = LaunchAgentStore()) {
        self.store = store
        self.launchctl = Launchctl(store: store)
    }

    nonisolated init(store: LaunchAgentStore, launchctl: Launchctl) {
        self.store = store
        self.launchctl = launchctl
    }

    var logDirectory: URL {
        store.logDirectory
    }

    // MARK: Refresh

    func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true

        let store = self.store
        let launchctl = self.launchctl
        Task.detached(priority: .userInitiated) {
            let outcome: Result<(scripts: [Script], snapshot: LaunchctlSnapshot), Error>
            do {
                let scripts = try store.list()
                outcome = .success((scripts, try launchctl.snapshot()))
            } catch {
                outcome = .failure(error)
            }

            await MainActor.run {
                self.isRefreshing = false

                switch outcome {
                case .success(let result):
                    self.scripts = result.scripts
                    var statuses: [String: LaunchctlStatus] = [:]
                    for script in result.scripts {
                        statuses[script.label] = result.snapshot.status(for: script.label)
                    }
                    self.statuses = statuses
                case .failure(let error):
                    self.present(error)
                }
            }
        }
    }

    // MARK: Actions

    func start(_ script: Script) {
        let launchctl = self.launchctl
        perform { try launchctl.start(script) }
    }

    func stop(_ script: Script) {
        let launchctl = self.launchctl
        perform { try launchctl.stop(script) }
    }

    func restart(_ script: Script) {
        let launchctl = self.launchctl
        perform { try launchctl.restart(script) }
    }

    func add(_ script: Script) {
        let store = self.store
        let launchctl = self.launchctl
        perform {
            try store.write(script)
            try launchctl.start(script)
        }
    }

    /// Reloads the agent with the new plist. If it was running or enabled, starts it
    /// again; if that fails, the old plist is restored and the old script restarted.
    func update(_ script: Script, to updated: Script) {
        let store = self.store
        let launchctl = self.launchctl
        perform {
            guard updated.name == script.name else {
                throw ScriptError.invalidName(updated.name)
            }

            let snapshot = try launchctl.snapshot()
            let status = snapshot.status(for: script.label)
            let wasRunning: Bool
            if case .running = status {
                wasRunning = true
            } else {
                wasRunning = false
            }
            let shouldStart = wasRunning || !snapshot.disabled.contains(script.label)

            let oldPlist = try store.readPlistData(name: script.name)

            try launchctl.bootout(script.label)
            try launchctl.waitUntilUnloaded(label: script.label)

            do {
                try store.write(updated)
            } catch {
                if shouldStart {
                    try? launchctl.start(script)
                }
                throw error
            }

            guard shouldStart else {
                return
            }

            do {
                try launchctl.start(updated)
            } catch {
                guard let oldPlist else {
                    throw error
                }
                do {
                    try store.writePlistData(oldPlist, name: script.name)
                    try launchctl.start(script)
                } catch let rollbackError {
                    throw ScriptUpdateError(original: error, rollback: rollbackError)
                }
                throw error
            }
        }
    }

    /// Boot out, delete the plist, then clear the stored disabled entry. The log is kept.
    func remove(_ script: Script) {
        let store = self.store
        let launchctl = self.launchctl
        perform {
            try launchctl.bootout(script.label)
            try launchctl.waitUntilUnloaded(label: script.label)
            try store.delete(name: script.name)
            try launchctl.enable(script.label)
        }
    }

    func validateNewName(_ name: String) throws {
        try store.validateNewName(name)
    }

    // MARK: Logs

    func openLog(for script: Script) {
        let url = script.logURL(in: store.logDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "No log output yet."
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: Helpers

    private func perform(_ work: @escaping @Sendable () throws -> Void) {
        Task.detached(priority: .userInitiated) {
            let message: String?
            do {
                try work()
                message = nil
            } catch {
                message = error.localizedDescription
            }

            await MainActor.run {
                if let message {
                    self.present(message)
                }
                self.refresh()
            }
        }
    }

    private func present(_ error: Error) {
        present(error.localizedDescription)
    }

    private func present(_ message: String) {
        if errorMessage == nil {
            errorMessage = message
        }
    }
}

struct ScriptUpdateError: LocalizedError {
    let original: Error
    let rollback: Error

    var errorDescription: String? {
        "\(original.localizedDescription) The previous script could not be restarted: \(rollback.localizedDescription)"
    }
}
