import Foundation
import Testing
@testable import AppCore

struct ScriptTests {
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

    @Test func plistEncoding() throws {
        let plist = try makeScript().plist(logDirectory: logDirectory)

        #expect(plist["Label"] as? String == AppInfo.agentLabelPrefix + "web")
        #expect(plist["AppCommand"] as? String == "web serve")
        #expect(
            plist["ProgramArguments"] as? [String]
                == ["/bin/zsh", "-l", "-i", "-c", "exec web serve"]
        )
        #expect(plist["WorkingDirectory"] as? String == "/Users/me")
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["KeepAlive"] as? [String: Bool] == ["SuccessfulExit": false])
        #expect(plist["StandardOutPath"] as? String == "/tmp/logs/web.log")
        #expect(plist["StandardErrorPath"] as? String == "/tmp/logs/web.log")
        // `swift test` runs outside an app bundle, so the bundle ID is empty
        // there and the key is omitted.
        let bundleIDs: [String]? = AppInfo.bundleID.isEmpty ? nil : [AppInfo.bundleID]
        #expect(plist["AssociatedBundleIdentifiers"] as? [String] == bundleIDs)
    }

    @Test func plistEncodingRoundTrip() throws {
        let script = makeScript()
        let plist = try script.plist(logDirectory: logDirectory)

        #expect(Script(plist: plist) == script)
    }

    @Test func restartOnCrashOffOmitsKeepAlive() throws {
        let plist = try makeScript(restartOnCrash: false).plist(logDirectory: logDirectory)

        #expect(plist["KeepAlive"] == nil)
        #expect(Script(plist: plist)?.restartOnCrash == false)
    }

    @Test func decodingReadsCommandFromCustomKey() throws {
        let script = makeScript(command: "cd app && npm run dev")
        var plist = try script.plist(logDirectory: logDirectory)
        plist["ProgramArguments"] = ["/bin/sh", "-c", "something else"]

        #expect(Script(plist: plist)?.command == "cd app && npm run dev")
    }

    @Test func decodingRejectsForeignOrMalformedPlists() throws {
        var foreign = try makeScript().plist(logDirectory: logDirectory)
        foreign["Label"] = "com.example.other"
        #expect(Script(plist: foreign) == nil)

        var missingCommand = try makeScript().plist(logDirectory: logDirectory)
        missingCommand.removeValue(forKey: "AppCommand")
        #expect(Script(plist: missingCommand) == nil)

        var badName = try makeScript().plist(logDirectory: logDirectory)
        badName["Label"] = AppInfo.agentLabelPrefix + "Not Valid"
        #expect(Script(plist: badName) == nil)
    }

    @Test func wrapSimpleCommand() {
        #expect(CommandWrapper.wrap("web serve") == "exec web serve")
        #expect(CommandWrapper.wrap("  web serve\n") == "exec web serve")
        #expect(CommandWrapper.wrap("exec web serve") == "exec web serve")
    }

    @Test func wrapLeavesCompoundCommandsAlone() {
        let commands = [
            "cd app && npm run dev",
            "npm run build || exit 1",
            "a; b",
            "a | b",
            "a &",
            "a\nb",
        ]

        for command in commands {
            #expect(CommandWrapper.wrap(command) == command)
            #expect(!CommandWrapper.isSimple(command), "\(command)")
        }
    }

    @Test func nameRules() {
        for valid in ["web", "api", "web-2", "web_2", "a"] {
            #expect(ScriptName.isValid(valid), "\(valid)")
        }

        for invalid in ["", "Web", "web serve", "web.dev", "../web", "web/2", "wéb"] {
            #expect(!ScriptName.isValid(invalid), "\(invalid)")
        }
    }

    @Test func nameValidationThrows() {
        #expect(throws: ScriptError.emptyName) {
            try ScriptName.validate("")
        }
        #expect(throws: ScriptError.invalidName("Bad Name")) {
            try ScriptName.validate("Bad Name")
        }
        #expect(throws: ScriptError.duplicateName("web")) {
            try ScriptName.validate("web", existing: ["web"])
        }
        #expect(throws: Never.self) { try ScriptName.validate("web", existing: ["api"]) }
    }

    @Test func emptyCommandIsRejected() {
        let script = makeScript(command: " \n ")

        #expect(throws: ScriptError.emptyCommand) {
            try script.plist(logDirectory: logDirectory)
        }
    }
}
