import Foundation
import Testing
@testable import AppCore

final class LaunchAgentStoreTests {
    private let root: URL
    private let store: LaunchAgentStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAgentStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = LaunchAgentStore(
            agentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true),
            logDirectory: root.appendingPathComponent("Logs/App", isDirectory: true)
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeScript(name: String = "web", command: String = "web serve") -> Script {
        Script(
            name: name,
            command: command,
            workingDirectory: NSHomeDirectory(),
            startAtLogin: true,
            restartOnCrash: false
        )
    }

    @Test func writeListRoundTrip() throws {
        let script = makeScript()

        try store.write(script)

        #expect(FileManager.default.fileExists(atPath: store.plistURL(for: "web").path))
        #expect(FileManager.default.fileExists(atPath: store.logDirectory.path))
        #expect(try store.list() == [script])
    }

    @Test func writtenPlistIsValidXmlPropertyList() throws {
        try store.write(makeScript(name: "api", command: "api serve"))
        let data = try Data(contentsOf: store.plistURL(for: "api"))
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        #expect(object is [String: Any])
        #expect((object as? [String: Any])?["AppCommand"] as? String == "api serve")
    }

    @Test func listSortsByName() throws {
        try store.write(makeScript(name: "api", command: "api serve"))
        try store.write(makeScript(name: "web"))

        #expect(try store.list().map(\.name) == ["api", "web"])
    }

    @Test func deleteRemovesOnlyThatPlist() throws {
        try store.write(makeScript(name: "web"))
        try store.write(makeScript(name: "api", command: "api serve"))

        try store.delete(name: "web")

        #expect(!FileManager.default.fileExists(atPath: store.plistURL(for: "web").path))
        #expect(try store.list().map(\.name) == ["api"])
    }

    @Test func deleteMissingScriptSucceeds() {
        #expect(throws: Never.self) { try self.store.delete(name: "web") }
    }

    @Test func malformedPlistIsSkipped() throws {
        try store.write(makeScript(name: "web"))
        try store.ensureDirectories()

        let broken = store.agentsDirectory.appendingPathComponent(AppInfo.agentLabelPrefix + "broken.plist")
        try Data("not a plist".utf8).write(to: broken)
        let foreign = store.agentsDirectory.appendingPathComponent("com.example.other.plist")
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict/></plist>".utf8).write(to: foreign)

        #expect(try store.list().map(\.name) == ["web"])
    }

    @Test func validateNewNameRejectsExistingLabel() throws {
        try store.write(makeScript(name: "web"))

        #expect(throws: ScriptError.duplicateName("web")) { try self.store.validateNewName("web") }
        #expect(throws: Never.self) { try self.store.validateNewName("api") }
    }

    @Test func writeRejectsInvalidName() {
        let script = makeScript(name: "bad name")

        #expect(throws: ScriptError.invalidName("bad name")) { try self.store.write(script) }
    }
}
