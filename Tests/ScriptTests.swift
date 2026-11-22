import XCTest
@testable import AppCore

final class ScriptTests: XCTestCase {
    private let logDirectory = URL(fileURLWithPath: "/tmp/logs")

    private func makeScript(
        name: String = "glot",
        command: String = "glot serve",
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

        XCTAssertEqual(plist["Label"] as? String, AppInfo.agentLabelPrefix + "glot")
        XCTAssertEqual(plist["AppCommand"] as? String, "glot serve")
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            ["/bin/zsh", "-l", "-i", "-c", "exec glot serve"]
        )
        XCTAssertEqual(plist["WorkingDirectory"] as? String, "/Users/me")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? [String: Bool], ["SuccessfulExit": false])
        XCTAssertEqual(plist["StandardOutPath"] as? String, "/tmp/logs/glot.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String, "/tmp/logs/glot.log")
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
        XCTAssertEqual(CommandWrapper.wrap("glot serve"), "exec glot serve")
        XCTAssertEqual(CommandWrapper.wrap("  glot serve\n"), "exec glot serve")
        XCTAssertEqual(CommandWrapper.wrap("exec glot serve"), "exec glot serve")
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
        for valid in ["glot", "uplet", "glot-2", "glot_2", "a"] {
            XCTAssertTrue(ScriptName.isValid(valid), valid)
        }

        for invalid in ["", "Glot", "glot serve", "glot.dev", "../glot", "glot/2", "glôt"] {
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
        XCTAssertThrowsError(try ScriptName.validate("glot", existing: ["glot"])) { error in
            XCTAssertEqual(error as? ScriptError, .duplicateName("glot"))
        }
        XCTAssertNoThrow(try ScriptName.validate("glot", existing: ["uplet"]))
    }

    func testEmptyCommandIsRejected() {
        let script = makeScript(command: " \n ")

        XCTAssertThrowsError(try script.plist(logDirectory: logDirectory)) { error in
            XCTAssertEqual(error as? ScriptError, .emptyCommand)
        }
    }
}
