import Foundation

struct LaunchctlResult: Equatable {
    var status: Int32
    var stdout: String
    var stderr: String
}

struct ListedAgent: Equatable {
    /// `nil` when launchd reports `-` instead of a PID.
    var pid: Int32?
    var lastExitCode: Int32
}

enum LaunchctlStatus: Equatable {
    case running(pid: Int32)
    case exited(code: Int32)
    case disabled
    case notLoaded
}

/// Parsed `launchctl list` and `launchctl print-disabled` output.
struct LaunchctlSnapshot: Equatable {
    var listed: [String: ListedAgent]
    var disabled: Set<String>

    func status(for label: String) -> LaunchctlStatus {
        if let agent = listed[label] {
            if let pid = agent.pid {
                return .running(pid: pid)
            }
            return .exited(code: agent.lastExitCode)
        }
        if disabled.contains(label) {
            return .disabled
        }
        return .notLoaded
    }

    func isLoaded(_ label: String) -> Bool {
        listed[label] != nil
    }
}

enum LaunchctlError: LocalizedError, Equatable {
    case commandFailed(command: String, status: Int32, stderr: String)
    case timeout(label: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let status, let stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "\(command) failed with status \(status)." : message
        case .timeout(let label):
            return "Timed out waiting for \(label) to stop."
        }
    }
}

// MARK: - Output parsing

enum LaunchctlOutput {
    /// Rows are `PID<TAB>Status<TAB>Label`; `-` means no PID.
    static func parseList(_ output: String) -> [String: ListedAgent] {
        var agents: [String: ListedAgent] = [:]

        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(
                maxSplits: 2,
                omittingEmptySubsequences: true,
                whereSeparator: { $0 == "\t" || $0 == " " }
            )
            guard fields.count == 3, fields[0] != "PID", fields[1] != "Status" else {
                continue
            }

            let pidText = String(fields[0])
            let pid: Int32?
            if pidText == "-" {
                pid = nil
            } else if let parsed = Int32(pidText) {
                pid = parsed
            } else {
                continue
            }

            guard let lastExitCode = Int32(String(fields[1])) else {
                continue
            }

            let label = String(fields[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                continue
            }

            agents[label] = ListedAgent(pid: pid, lastExitCode: lastExitCode)
        }

        return agents
    }

    /// Rows are `"label" => disabled` (older systems: `=> true`).
    static func parseDisabled(_ output: String) -> Set<String> {
        var disabled: Set<String> = []

        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            guard let arrow = trimmed.range(of: "=>") else {
                continue
            }

            let rawLabel = String(trimmed[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
            let state = String(trimmed[arrow.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard rawLabel.hasPrefix("\""), rawLabel.hasSuffix("\""), rawLabel.count >= 2 else {
                continue
            }

            if state == "disabled" || state == "true" {
                disabled.insert(String(rawLabel.dropFirst().dropLast()))
            }
        }

        return disabled
    }
}

// MARK: - launchctl

/// Wraps `/bin/launchctl` for the current GUI session.
struct Launchctl: @unchecked Sendable {
    typealias Runner = ([String]) throws -> LaunchctlResult

    private static let executablePath = "/bin/launchctl"
    private static let pollInterval: TimeInterval = 0.2

    private let store: LaunchAgentStore
    private let uid: uid_t
    private let pollInterval: TimeInterval
    private let runner: Runner

    init(
        store: LaunchAgentStore = LaunchAgentStore(),
        uid: uid_t = getuid(),
        pollInterval: TimeInterval = Launchctl.pollInterval,
        runner: @escaping Runner = Launchctl.runProcess
    ) {
        self.store = store
        self.uid = uid
        self.pollInterval = pollInterval
        self.runner = runner
    }

    var domain: String {
        "gui/\(uid)"
    }

    func target(for label: String) -> String {
        "\(domain)/\(label)"
    }

    // MARK: Low-level calls

    func bootstrap(_ script: Script) throws {
        let arguments = ["bootstrap", domain, store.plistURL(for: script.name).path]
        let result = try runner(arguments)
        if result.status != 0 && !isAlreadyLoaded(result.stderr) {
            throw failure(result, arguments: arguments)
        }
    }

    func bootout(_ label: String) throws {
        let arguments = ["bootout", target(for: label)]
        let result = try runner(arguments)
        if result.status != 0 && !isNotLoaded(result.stderr) {
            throw failure(result, arguments: arguments)
        }
    }

    func kickstart(_ label: String, restart: Bool = false) throws {
        var arguments = ["kickstart"]
        if restart {
            arguments.append("-k")
        }
        arguments.append(target(for: label))
        try checked(arguments)
    }

    func enable(_ label: String) throws {
        try checked(["enable", target(for: label)])
    }

    func disable(_ label: String) throws {
        try checked(["disable", target(for: label)])
    }

    // MARK: Inspection

    /// One `launchctl list` call.
    func list() throws -> [String: ListedAgent] {
        let result = try checked(["list"])
        return LaunchctlOutput.parseList(result.stdout)
    }

    func disabledLabels() throws -> Set<String> {
        let arguments = ["print-disabled", domain]
        let result = try checked(arguments)
        return LaunchctlOutput.parseDisabled(result.stdout)
    }

    /// One `launchctl list` and one `print-disabled` call per refresh.
    func snapshot() throws -> LaunchctlSnapshot {
        LaunchctlSnapshot(listed: try list(), disabled: try disabledLabels())
    }

    func isLoaded(_ label: String) throws -> Bool {
        try list()[label] != nil
    }

    /// `bootout` returns before the process exits; bootstrapping too soon fails.
    /// The default outlasts launchd's 20 s `ExitTimeOut` before it sends SIGKILL.
    func waitUntilUnloaded(label: String, timeout: TimeInterval = 30) throws {
        let deadline = Date().addingTimeInterval(timeout)

        while try isLoaded(label) {
            guard Date() < deadline else {
                throw LaunchctlError.timeout(label: label)
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    // MARK: Actions

    /// `KeepAlive.SuccessfulExit` implies `RunAtLoad`, so a script that must not
    /// start at login is disabled once running. Disabling a loaded job keeps its
    /// crash restarts but stops launchd from loading it at the next login.
    func start(_ script: Script) throws {
        try enable(script.label)
        if !(try isLoaded(script.label)) {
            try bootstrap(script)
        }
        try kickstart(script.label)
        if !script.startAtLogin {
            try disable(script.label)
        }
    }

    func stop(_ script: Script) throws {
        try disable(script.label)
        try bootout(script.label)
        try waitUntilUnloaded(label: script.label)
    }

    func restart(_ script: Script) throws {
        if try isLoaded(script.label) {
            try kickstart(script.label, restart: true)
        } else {
            try start(script)
        }
    }

    // MARK: Helpers

    @discardableResult
    private func checked(_ arguments: [String]) throws -> LaunchctlResult {
        let result = try runner(arguments)
        if result.status != 0 {
            throw failure(result, arguments: arguments)
        }
        return result
    }

    private func failure(_ result: LaunchctlResult, arguments: [String]) -> LaunchctlError {
        .commandFailed(
            command: "launchctl " + arguments.joined(separator: " "),
            status: result.status,
            stderr: result.stderr
        )
    }

    private func isAlreadyLoaded(_ stderr: String) -> Bool {
        stderr.localizedCaseInsensitiveContains("already loaded")
    }

    private func isNotLoaded(_ stderr: String) -> Bool {
        let message = stderr.lowercased()
        return message.contains("could not find service")
            || message.contains("no such process")
            || message.contains("not loaded")
    }

    // MARK: Process

    static func runProcess(_ arguments: [String]) throws -> LaunchctlResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let stdoutBox = DataBox()
        let stderrBox = DataBox()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutBox.data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrBox.data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        process.waitUntilExit()
        group.wait()

        return LaunchctlResult(
            status: process.terminationStatus,
            stdout: String(decoding: stdoutBox.data, as: UTF8.self),
            stderr: String(decoding: stderrBox.data, as: UTF8.self)
        )
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}
