import Foundation
import Testing
@testable import AppCore

struct LaunchctlTests {
    private final class FakeRunner {
        var calls: [[String]] = []
        var handler: ([String]) -> LaunchctlResult

        init(handler: @escaping ([String]) -> LaunchctlResult) {
            self.handler = handler
        }

        func run(_ arguments: [String]) -> LaunchctlResult {
            calls.append(arguments)
            return handler(arguments)
        }
    }

    private let success = LaunchctlResult(status: 0, stdout: "", stderr: "")

    private func makeScript(name: String = "web", startAtLogin: Bool = true) -> Script {
        Script(
            name: name,
            command: "web serve",
            workingDirectory: NSHomeDirectory(),
            startAtLogin: startAtLogin,
            restartOnCrash: true
        )
    }

    private func makeSystem(
        runner: @escaping Launchctl.Runner
    ) -> (launchctl: Launchctl, store: LaunchAgentStore) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchctlTests-\(UUID().uuidString)", isDirectory: true)
        let store = LaunchAgentStore(
            agentsDirectory: root.appendingPathComponent("LaunchAgents", isDirectory: true),
            logDirectory: root.appendingPathComponent("Logs", isDirectory: true)
        )
        let launchctl = Launchctl(store: store, uid: 501, pollInterval: 0.001, runner: runner)
        return (launchctl, store)
    }

    private func listOutput(pid: Int32?, status: Int32, label: String) -> String {
        let pidField = pid.map(String.init) ?? "-"
        return "PID\tStatus\tLabel\n\(pidField)\t\(status)\t\(label)\n"
    }

    // MARK: Parsing

    @Test func parseList() {
        let output = """
        PID\tStatus\tLabel
        1234\t0\tcom.example.running
        -\t1\tcom.example.exited
        40989\t-9\tcom.example.stale
        """

        let agents = LaunchctlOutput.parseList(output)

        #expect(agents.count == 3)
        #expect(agents["com.example.running"] == ListedAgent(pid: 1234, lastExitCode: 0))
        #expect(agents["com.example.exited"] == ListedAgent(pid: nil, lastExitCode: 1))
        #expect(agents["com.example.stale"] == ListedAgent(pid: 40989, lastExitCode: -9))
    }

    @Test func parseListSkipsHeaderAndMalformedRows() {
        let output = "PID\tStatus\tLabel\n\nnot a row\n-\t0\tvalid.label\n"

        #expect(LaunchctlOutput.parseList(output) == ["valid.label": ListedAgent(pid: nil, lastExitCode: 0)])
    }

    @Test func parseDisabled() {
        let output = """
        \tdisabled services = {
        \t\t"com.example.off" => disabled
        \t\t"com.example.on" => enabled
        \t\t"com.example.legacy-off" => true
        \t\t"com.example.legacy-on" => false
        \t}
        """

        #expect(
            LaunchctlOutput.parseDisabled(output)
                == ["com.example.off", "com.example.legacy-off"]
        )
    }

    @Test func snapshotStatus() {
        let snapshot = LaunchctlSnapshot(
            listed: [
                "app.running": ListedAgent(pid: 42, lastExitCode: 0),
                "app.exited": ListedAgent(pid: nil, lastExitCode: 2),
            ],
            disabled: ["app.disabled"]
        )

        #expect(snapshot.status(for: "app.running") == .running(pid: 42))
        #expect(snapshot.status(for: "app.exited") == .exited(code: 2))
        #expect(snapshot.status(for: "app.disabled") == .disabled)
        #expect(snapshot.status(for: "app.missing") == .notLoaded)
    }

    // MARK: Actions

    @Test func startBootstrapsAndKickstarts() throws {
        let script = makeScript()
        let fake = FakeRunner { _ in self.success }
        let (launchctl, store) = makeSystem(runner: fake.run)

        try launchctl.start(script)

        #expect(fake.calls == [
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["bootstrap", "gui/501", store.plistURL(for: script.name).path],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }

    @Test func startDisablesWhenNotStartingAtLogin() throws {
        let script = makeScript(startAtLogin: false)
        let fake = FakeRunner { _ in self.success }
        let (launchctl, store) = makeSystem(runner: fake.run)

        try launchctl.start(script)

        #expect(fake.calls == [
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["bootstrap", "gui/501", store.plistURL(for: script.name).path],
            ["kickstart", "gui/501/\(script.label)"],
            ["disable", "gui/501/\(script.label)"],
        ])
    }

    @Test func startSkipsBootstrapWhenAlreadyLoaded() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 7, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        try launchctl.start(script)

        #expect(fake.calls == [
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }

    @Test func startAcceptsAlreadyLoadedBootstrapError() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            if arguments.first == "bootstrap" {
                return LaunchctlResult(status: 5, stdout: "", stderr: "service already loaded")
            }
            return self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        #expect(throws: Never.self) { try launchctl.start(script) }
    }

    @Test func startSurfacesLaunchctlStderr() {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments.first == "enable"
                ? LaunchctlResult(status: 1, stdout: "", stderr: "Operation not permitted")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        #expect(throws: LaunchctlError.commandFailed(
            command: "launchctl enable gui/501/\(script.label)",
            status: 1,
            stderr: "Operation not permitted"
        )) {
            try launchctl.start(script)
        }
    }

    @Test func stopDisablesBootsOutAndWaits() throws {
        let script = makeScript()
        var listCalls = 0
        let fake = FakeRunner { arguments in
            guard arguments == ["list"] else { return self.success }
            listCalls += 1
            let output = listCalls == 1
                ? self.listOutput(pid: 9, status: 0, label: script.label)
                : ""
            return LaunchctlResult(status: 0, stdout: output, stderr: "")
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        try launchctl.stop(script)

        #expect(fake.calls == [
            ["disable", "gui/501/\(script.label)"],
            ["bootout", "gui/501/\(script.label)"],
            ["list"],
            ["list"],
        ])
    }

    @Test func stopAcceptsNotLoadedBootout() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            if arguments.first == "bootout" {
                return LaunchctlResult(status: 3, stdout: "", stderr: "Could not find service \"x\" in domain")
            }
            return self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        #expect(throws: Never.self) { try launchctl.stop(script) }
    }

    @Test func stopTimesOutWhenStillLoaded() {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 9, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        #expect(throws: LaunchctlError.timeout(label: script.label)) {
            try launchctl.waitUntilUnloaded(label: script.label, timeout: 0.05)
        }
    }

    @Test func restartLoadedUsesKickstartK() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 9, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        try launchctl.restart(script)

        #expect(fake.calls == [
            ["list"],
            ["kickstart", "-k", "gui/501/\(script.label)"],
        ])
    }

    @Test func restartUnloadedStarts() throws {
        let script = makeScript()
        let fake = FakeRunner { _ in self.success }
        let (launchctl, store) = makeSystem(runner: fake.run)

        try launchctl.restart(script)

        #expect(fake.calls == [
            ["list"],
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["bootstrap", "gui/501", store.plistURL(for: script.name).path],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }
}
