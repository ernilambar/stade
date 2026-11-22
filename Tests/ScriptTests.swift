import XCTest
@testable import AppCore

final class ScriptTests: XCTestCase {
    private let logDirectory = URL(fileURLWithPath: "/tmp/logs")

    private func makeScript(
        name: String = "web",
        command: String = "web serve",
        startAtLogin: Bool = true,
        restartOnCrash: Bool = true
    ) -> Script {
        Script(
            name: name,
            command: command,
            workingDirectory: "/Users/me",
            startAtLogin: startAtLogin,
            restartOnCrash: restartOnCrash
        )
    }

    func testPlistEncoding() throws {
        let plist = try makeScript().plist(logDirectory: logDirectory)

        XCTAssertEqual(plist["Label"] as? String, AppInfo.agentLabelPrefix + "web")
        XCTAssertEqual(plist["AppCommand"] as? String, "web serve")
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            ["/bin/zsh", "-l", "-i", "-c", "exec web serve"]
        )
        XCTAssertEqual(plist["WorkingDirectory"] as? String, "/Users/me")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? [String: Bool], ["SuccessfulExit": false])
        XCTAssertEqual(plist["StandardOutPath"] as? String, "/tmp/logs/web.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String, "/tmp/logs/web.log")
        XCTAssertEqual(plist["AssociatedBundleIdentifiers"] as? [String], [AppInfo.bundleID])
    }

    func testPlistEncodingRoundTrip() throws {
        let script = makeScript()
        let plist = try script.plist(logDirectory: logDirectory)

        XCTAssertEqual(Script(plist: plist), script)
    }

    func testRestartOnCrashOffOmitsKeepAlive() throws {
        let plist = try makeScript(restartOnCrash: false).plist(logDirectory: logDirectory)

        XCTAssertNil(plist["KeepAlive"])
        XCTAssertEqual(Script(plist: plist)?.restartOnCrash, false)
    }

    func testDecodingReadsCommandFromCustomKey() throws {
        let script = makeScript(command: "cd app && npm run dev")
        var plist = try script.plist(logDirectory: logDirectory)
        plist["ProgramArguments"] = ["/bin/sh", "-c", "something else"]

        XCTAssertEqual(Script(plist: plist)?.command, "cd app && npm run dev")
    }

    func testDecodingRejectsForeignOrMalformedPlists() throws {
        var foreign = try makeScript().plist(logDirectory: logDirectory)
        foreign["Label"] = "com.example.other"
        XCTAssertNil(Script(plist: foreign))

        var missingCommand = try makeScript().plist(logDirectory: logDirectory)
        missingCommand.removeValue(forKey: "AppCommand")
        XCTAssertNil(Script(plist: missingCommand))

        var badName = try makeScript().plist(logDirectory: logDirectory)
        badName["Label"] = AppInfo.agentLabelPrefix + "Not Valid"
        XCTAssertNil(Script(plist: badName))
    }

    func testWrapSimpleCommand() {
        XCTAssertEqual(CommandWrapper.wrap("web serve"), "exec web serve")
        XCTAssertEqual(CommandWrapper.wrap("  web serve\n"), "exec web serve")
        XCTAssertEqual(CommandWrapper.wrap("exec web serve"), "exec web serve")
    }

    func testWrapLeavesCompoundCommandsAlone() {
        let commands = [
            "cd app && npm run dev",
            "npm run build || exit 1",
            "a; b",
            "a | b",
            "a &",
            "a\nb",
        ]

        for command in commands {
            XCTAssertEqual(CommandWrapper.wrap(command), command)
            XCTAssertFalse(CommandWrapper.isSimple(command), command)
        }
    }

    func testNameRules() {
        for valid in ["web", "api", "web-2", "web_2", "a"] {
            XCTAssertTrue(ScriptName.isValid(valid), valid)
        }

        for invalid in ["", "Web", "web serve", "web.dev", "../web", "web/2", "wéb"] {
            XCTAssertFalse(ScriptName.isValid(invalid), invalid)
        }
    }

    func testNameValidationThrows() {
        XCTAssertThrowsError(try ScriptName.validate("")) { error in
            XCTAssertEqual(error as? ScriptError, .emptyName)
        }
        XCTAssertThrowsError(try ScriptName.validate("Bad Name")) { error in
            XCTAssertEqual(error as? ScriptError, .invalidName("Bad Name"))
        }
        XCTAssertThrowsError(try ScriptName.validate("web", existing: ["web"])) { error in
            XCTAssertEqual(error as? ScriptError, .duplicateName("web"))
        }
        XCTAssertNoThrow(try ScriptName.validate("web", existing: ["api"]))
    }

    func testEmptyCommandIsRejected() {
        let script = makeScript(command: " \n ")

        XCTAssertThrowsError(try script.plist(logDirectory: logDirectory)) { error in
            XCTAssertEqual(error as? ScriptError, .emptyCommand)
        }
    }
}
