import Combine
import Foundation

@MainActor
final class ScriptListModel: ObservableObject {
    @Published private(set) var scripts: [Script] = []
    @Published private(set) var statuses: [String: LaunchctlStatus] = [:]
    @Published private(set) var isRefreshing = false
    /// Labels with an action queued or running.
    @Published private(set) var busyLabels: Set<String> = []
    @Published var errorMessage: String?

    private var refreshQueued = false
    /// The last refresh failure, so a persistent one is shown only once.
    private var lastRefreshError: String?
    /// Actions run one at a time, in the order they were requested.
    private var lastAction: Task<Void, Never>?

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
            refreshQueued = true
            return
        }
        isRefreshing = true

        let store = self.store
        let launchctl = self.launchctl
        Task.detached(priority: .userInitiated) {
            let outcome: Result<(scripts: [Script], snapshot: LaunchctlSnapshot), Error>
            do {
                let scripts = try store.list()
                for script in scripts {
                    try? LogFile.truncateIfNeeded(at: script.logURL(in: store.logDirectory))
                }
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
                    self.lastRefreshError = nil
                case .failure(let error):
                    let message = error.localizedDescription
                    if message != self.lastRefreshError {
                        self.present(message)
                    }
                    self.lastRefreshError = message
                }

                if self.refreshQueued {
                    self.refreshQueued = false
                    self.refresh()
                }
            }
        }
    }

    // MARK: Actions

    func start(_ script: Script) {
        let launchctl = self.launchctl
        perform(script.label) { try launchctl.start(script) }
    }

    func stop(_ script: Script) {
        let launchctl = self.launchctl
        perform(script.label) { try launchctl.stop(script) }
    }

    func restart(_ script: Script) {
        let launchctl = self.launchctl
        perform(script.label) { try launchctl.restart(script) }
    }

    func add(_ script: Script) {
        let store = self.store
        let launchctl = self.launchctl
        perform(script.label) {
            try store.validateNewName(script.name)
            try store.write(script)
            try launchctl.start(script)
        }
    }

    /// Reloads the agent with the new plist. If it was running or enabled, starts it
    /// again; if that fails, the old plist is restored and the old script restarted.
    func update(_ script: Script, to updated: Script) {
        let store = self.store
        let launchctl = self.launchctl
        perform(script.label) {
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
        perform(script.label) {
            try deleteScript(script, store: store, launchctl: launchctl)
        }
    }

    /// Checks against the loaded list; `add` re-checks the disk off the main actor.
    func validateNewName(_ name: String) throws {
        try ScriptName.validate(name, existing: Set(scripts.map(\.name)))
    }

    // MARK: Logs

    func logURL(for script: Script) -> URL {
        script.logURL(in: store.logDirectory)
    }

    // MARK: Helpers

    private func perform(_ label: String, _ work: @escaping @Sendable () throws -> Void) {
        busyLabels.insert(label)
        let previous = lastAction
        lastAction = Task.detached(priority: .userInitiated) {
            await previous?.value

            let message: String?
            do {
                try work()
                message = nil
            } catch {
                message = error.localizedDescription
            }

            await MainActor.run {
                self.busyLabels.remove(label)
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

private func deleteScript(_ script: Script, store: LaunchAgentStore, launchctl: Launchctl) throws {
    try launchctl.bootout(script.label)
    try launchctl.waitUntilUnloaded(label: script.label)
    try store.delete(name: script.name)
    try launchctl.enable(script.label)
}
