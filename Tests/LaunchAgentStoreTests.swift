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

    private func makeScript(name: String = "glot", command: String = "glot serve") -> Script {
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

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.plistURL(for: "glot").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.logDirectory.path))
        XCTAssertEqual(try store.list(), [script])
    }

    func testWrittenPlistIsValidXmlPropertyList() throws {
        try store.write(makeScript(name: "uplet", command: "uplet serve"))
        let data = try Data(contentsOf: store.plistURL(for: "uplet"))
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        XCTAssertTrue(object is [String: Any])
        XCTAssertEqual((object as? [String: Any])?["AppCommand"] as? String, "uplet serve")
    }

    func testListSortsByName() throws {
        try store.write(makeScript(name: "uplet", command: "uplet serve"))
        try store.write(makeScript(name: "glot"))

        XCTAssertEqual(try store.list().map(\.name), ["glot", "uplet"])
    }

    func testDeleteRemovesOnlyThatPlist() throws {
        try store.write(makeScript(name: "glot"))
        try store.write(makeScript(name: "uplet", command: "uplet serve"))

        try store.delete(name: "glot")

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.plistURL(for: "glot").path))
        XCTAssertEqual(try store.list().map(\.name), ["uplet"])
    }

    func testDeleteMissingScriptSucceeds() throws {
        XCTAssertNoThrow(try store.delete(name: "glot"))
    }

    func testMalformedPlistIsSkipped() throws {
        try store.write(makeScript(name: "glot"))
        try store.ensureDirectories()

        let broken = store.agentsDirectory.appendingPathComponent(AppInfo.agentLabelPrefix + "broken.plist")
        try Data("not a plist".utf8).write(to: broken)
        let foreign = store.agentsDirectory.appendingPathComponent("com.example.other.plist")
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict/></plist>".utf8).write(to: foreign)

        XCTAssertEqual(try store.list().map(\.name), ["glot"])
    }

    func testValidateNewNameRejectsExistingLabel() throws {
        try store.write(makeScript(name: "glot"))

        XCTAssertThrowsError(try store.validateNewName("glot")) { error in
            XCTAssertEqual(error as? ScriptError, .duplicateName("glot"))
        }
        XCTAssertNoThrow(try store.validateNewName("uplet"))
    }

    func testWriteRejectsInvalidName() {
        let script = makeScript(name: "bad name")

        XCTAssertThrowsError(try store.write(script)) { error in
            XCTAssertEqual(error as? ScriptError, .invalidName("bad name"))
        }
    }
}
