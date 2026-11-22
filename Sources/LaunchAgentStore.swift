import Foundation
import os

/// Reads and writes launch agent plists. The plists are the source of truth.
final class LaunchAgentStore {
    let fileManager: FileManager
    let agentsDirectory: URL
    let logDirectory: URL

    private let logger = Logger(
        subsystem: AppInfo.bundleID.isEmpty ? "app" : AppInfo.bundleID,
        category: "LaunchAgentStore"
    )

    init(
        fileManager: FileManager = .default,
        agentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true),
        logDirectory: URL = AppInfo.logDirectory
    ) {
        self.fileManager = fileManager
        self.agentsDirectory = agentsDirectory
        self.logDirectory = logDirectory
    }

    func plistURL(for name: String) -> URL {
        agentsDirectory.appendingPathComponent(AppInfo.agentLabelPrefix + name + ".plist")
    }

    func ensureDirectories() throws {
        try fileManager.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    /// Every readable script, sorted by name. Malformed plists are skipped.
    func list() throws -> [Script] {
        try ensureDirectories()

        let urls = try fileManager.contentsOfDirectory(
            at: agentsDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )

        var scripts: [Script] = []
        for url in urls {
            guard url.pathExtension == "plist",
                  url.lastPathComponent.hasPrefix(AppInfo.agentLabelPrefix)
            else {
                continue
            }

            guard
                let data = try? Data(contentsOf: url),
                let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                let plist = object as? [String: Any],
                let script = Script(plist: plist)
            else {
                logger.error("Skipping unreadable launch agent: \(url.lastPathComponent, privacy: .public)")
                continue
            }

            scripts.append(script)
        }

        return scripts.sorted { $0.name < $1.name }
    }

    func write(_ script: Script) throws {
        try ensureDirectories()

        let plist = try script.plist(logDirectory: logDirectory)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL(for: script.name), options: .atomic)
    }

    func delete(name: String) throws {
        try ScriptName.validate(name)

        let url = plistURL(for: name)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    /// Checks the name rules and rejects labels that already exist.
    func validateNewName(_ name: String) throws {
        try ScriptName.validate(name, existing: Set(try list().map(\.name)))
    }
}
