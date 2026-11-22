import Foundation

/// A launch agent managed by the app. The label is `<bundle id>.<name>`.
struct Script: Identifiable, Hashable {
    /// Lowercase letters, digits, `-` and `_` only.
    var name: String
    /// Original command text, preserved as typed.
    var command: String
    /// Absolute path; launchd does not expand `~`.
    var workingDirectory: String
    var startAtLogin: Bool
    var restartOnCrash: Bool

    var id: String { name }

    var label: String {
        AppInfo.agentLabelPrefix + name
    }

    func logURL(in directory: URL) -> URL {
        directory.appendingPathComponent(name).appendingPathExtension("log")
    }
}

// MARK: - Plist encoding

extension Script {
    private enum Key {
        static let label = "Label"
        static let command = "AppCommand"
        static let programArguments = "ProgramArguments"
        static let workingDirectory = "WorkingDirectory"
        static let runAtLoad = "RunAtLoad"
        static let keepAlive = "KeepAlive"
        static let successfulExit = "SuccessfulExit"
        static let standardOutPath = "StandardOutPath"
        static let standardErrorPath = "StandardErrorPath"
        static let associatedBundleIdentifiers = "AssociatedBundleIdentifiers"
    }

    /// The plist dictionary for launchd. Throws when the script cannot be written.
    func plist(logDirectory: URL) throws -> [String: Any] {
        try ScriptName.validate(name)
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScriptError.emptyCommand
        }

        let logPath = logURL(in: logDirectory).path
        var plist: [String: Any] = [
            Key.label: label,
            Key.command: command,
            Key.programArguments: [CommandWrapper.shellPath]
                + CommandWrapper.shellArguments
                + [CommandWrapper.wrap(command)],
            Key.workingDirectory: workingDirectory,
            Key.runAtLoad: startAtLogin,
            Key.standardOutPath: logPath,
            Key.standardErrorPath: logPath,
        ]

        if !AppInfo.bundleID.isEmpty {
            plist[Key.associatedBundleIdentifiers] = [AppInfo.bundleID]
        }

        if restartOnCrash {
            plist[Key.keepAlive] = [Key.successfulExit: false]
        }

        return plist
    }

    /// Returns `nil` for plists this app does not own or cannot understand.
    init?(plist: [String: Any]) {
        guard
            let label = plist[Key.label] as? String,
            label.hasPrefix(AppInfo.agentLabelPrefix),
            let command = plist[Key.command] as? String,
            !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let name = String(label.dropFirst(AppInfo.agentLabelPrefix.count))
        guard ScriptName.isValid(name) else {
            return nil
        }

        self.name = name
        self.command = command
        self.workingDirectory = plist[Key.workingDirectory] as? String
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        self.startAtLogin = plist[Key.runAtLoad] as? Bool ?? false
        self.restartOnCrash =
            (plist[Key.keepAlive] as? [String: Any])?[Key.successfulExit] as? Bool == false
    }
}

// MARK: - Command wrapping

enum CommandWrapper {
    static let shellPath = "/bin/zsh"
    static let shellArguments = ["-l", "-i", "-c"]

    /// Adds `exec` for simple commands so launchd tracks the real process.
    /// Compound commands are left untouched.
    static func wrap(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isSimple(trimmed) else {
            return trimmed
        }

        let firstWord = trimmed.prefix { !$0.isWhitespace }
        guard firstWord != "exec" else {
            return trimmed
        }

        return "exec " + trimmed
    }

    /// `&&`, `||`, `;`, `|`, `&` and newlines make a command compound.
    static func isSimple(_ command: String) -> Bool {
        !command.contains { character in
            character == "&" || character == "|" || character == ";" || character.isNewline
        }
    }
}

// MARK: - Names

enum ScriptName {
    static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty else {
            return false
        }

        return name.allSatisfy { character in
            switch character {
            case "a"..."z", "0"..."9", "-", "_":
                return true
            default:
                return false
            }
        }
    }

    static func validate(_ name: String) throws {
        guard !name.isEmpty else {
            throw ScriptError.emptyName
        }
        guard isValid(name) else {
            throw ScriptError.invalidName(name)
        }
    }

    static func validate(_ name: String, existing: Set<String>) throws {
        try validate(name)
        if existing.contains(name) {
            throw ScriptError.duplicateName(name)
        }
    }
}

enum ScriptError: LocalizedError, Equatable {
    case emptyName
    case invalidName(String)
    case duplicateName(String)
    case emptyCommand

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name is required."
        case .invalidName(let name):
            return "“\(name)” is not a valid name. Use lowercase letters, digits, - and _."
        case .duplicateName(let name):
            return "A script named “\(name)” already exists."
        case .emptyCommand:
            return "Command is required."
        }
    }
}
