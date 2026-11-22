import XCTest
@testable import AppCore

final class LaunchAgentStoreTests: XCTestCase {
    private var root: URL!
    private var store: LaunchAgentStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAgentStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = LaunchAgentStore(
            agentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true),
            logDirectory: root.appendingPathComponent("Logs/App", isDirectory: true)
        )
    }

    override func tearDownWithError() throws {
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

    func testWriteListRoundTrip() throws {
        let script = makeScript()

        try store.write(script)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.plistURL(for: "web").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.logDirectory.path))
        XCTAssertEqual(try store.list(), [script])
    }

    func testWrittenPlistIsValidXmlPropertyList() throws {
        try store.write(makeScript(name: "api", command: "api serve"))
        let data = try Data(contentsOf: store.plistURL(for: "api"))
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        XCTAssertTrue(object is [String: Any])
        XCTAssertEqual((object as? [String: Any])?["AppCommand"] as? String, "api serve")
    }

    func testListSortsByName() throws {
        try store.write(makeScript(name: "api", command: "api serve"))
        try store.write(makeScript(name: "web"))

        XCTAssertEqual(try store.list().map(\.name), ["api", "web"])
    }

    func testDeleteRemovesOnlyThatPlist() throws {
        try store.write(makeScript(name: "web"))
        try store.write(makeScript(name: "api", command: "api serve"))

        try store.delete(name: "web")

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.plistURL(for: "web").path))
        XCTAssertEqual(try store.list().map(\.name), ["api"])
    }

    func testDeleteMissingScriptSucceeds() throws {
        XCTAssertNoThrow(try store.delete(name: "web"))
    }

    func testMalformedPlistIsSkipped() throws {
        try store.write(makeScript(name: "web"))
        try store.ensureDirectories()

        let broken = store.agentsDirectory.appendingPathComponent(AppInfo.agentLabelPrefix + "broken.plist")
        try Data("not a plist".utf8).write(to: broken)
        let foreign = store.agentsDirectory.appendingPathComponent("com.example.other.plist")
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict/></plist>".utf8).write(to: foreign)

        XCTAssertEqual(try store.list().map(\.name), ["web"])
    }

    func testValidateNewNameRejectsExistingLabel() throws {
        try store.write(makeScript(name: "web"))

        XCTAssertThrowsError(try store.validateNewName("web")) { error in
            XCTAssertEqual(error as? ScriptError, .duplicateName("web"))
        }
        XCTAssertNoThrow(try store.validateNewName("api"))
    }

    func testWriteRejectsInvalidName() {
        let script = makeScript(name: "bad name")

        XCTAssertThrowsError(try store.write(script)) { error in
            XCTAssertEqual(error as? ScriptError, .invalidName("bad name"))
        }
    }
}
