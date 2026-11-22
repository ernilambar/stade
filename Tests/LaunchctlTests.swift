import XCTest
@testable import AppCore

final class LaunchctlTests: XCTestCase {
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

    private func makeScript(name: String = "glot") -> Script {
        Script(
            name: name,
            command: "glot serve",
            workingDirectory: NSHomeDirectory(),
            startAtLogin: true,
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

    func testParseList() {
        let output = """
        PID\tStatus\tLabel
        1234\t0\tcom.example.running
        -\t1\tcom.example.exited
        40989\t-9\tcom.example.stale
        """

        let agents = LaunchctlOutput.parseList(output)

        XCTAssertEqual(agents.count, 3)
        XCTAssertEqual(agents["com.example.running"], ListedAgent(pid: 1234, lastExitCode: 0))
        XCTAssertEqual(agents["com.example.exited"], ListedAgent(pid: nil, lastExitCode: 1))
        XCTAssertEqual(agents["com.example.stale"], ListedAgent(pid: 40989, lastExitCode: -9))
    }

    func testParseListSkipsHeaderAndMalformedRows() {
        let output = "PID\tStatus\tLabel\n\nnot a row\n-\t0\tvalid.label\n"

        XCTAssertEqual(LaunchctlOutput.parseList(output), ["valid.label": ListedAgent(pid: nil, lastExitCode: 0)])
    }

    func testParseDisabled() {
        let output = """
        \tdisabled services = {
        \t\t"com.example.off" => disabled
        \t\t"com.example.on" => enabled
        \t\t"com.example.legacy-off" => true
        \t\t"com.example.legacy-on" => false
        \t}
        """

        XCTAssertEqual(
            LaunchctlOutput.parseDisabled(output),
            ["com.example.off", "com.example.legacy-off"]
        )
    }

    func testSnapshotStatus() {
        let snapshot = LaunchctlSnapshot(
            listed: [
                "app.running": ListedAgent(pid: 42, lastExitCode: 0),
                "app.exited": ListedAgent(pid: nil, lastExitCode: 2),
            ],
            disabled: ["app.disabled"]
        )

        XCTAssertEqual(snapshot.status(for: "app.running"), .running(pid: 42))
        XCTAssertEqual(snapshot.status(for: "app.exited"), .exited(code: 2))
        XCTAssertEqual(snapshot.status(for: "app.disabled"), .disabled)
        XCTAssertEqual(snapshot.status(for: "app.missing"), .notLoaded)
    }

    // MARK: Actions

    func testStartBootstrapsAndKickstarts() throws {
        let script = makeScript()
        let fake = FakeRunner { _ in self.success }
        let (launchctl, store) = makeSystem(runner: fake.run)

        try launchctl.start(script)

        XCTAssertEqual(fake.calls, [
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["bootstrap", "gui/501", store.plistURL(for: script.name).path],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }

    func testStartSkipsBootstrapWhenAlreadyLoaded() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 7, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        try launchctl.start(script)

        XCTAssertEqual(fake.calls, [
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }

    func testStartAcceptsAlreadyLoadedBootstrapError() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            if arguments.first == "bootstrap" {
                return LaunchctlResult(status: 5, stdout: "", stderr: "service already loaded")
            }
            return self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        XCTAssertNoThrow(try launchctl.start(script))
    }

    func testStartSurfacesLaunchctlStderr() {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments.first == "enable"
                ? LaunchctlResult(status: 1, stdout: "", stderr: "Operation not permitted")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        XCTAssertThrowsError(try launchctl.start(script)) { error in
            XCTAssertEqual(
                error as? LaunchctlError,
                .commandFailed(
                    command: "launchctl enable gui/501/\(script.label)",
                    status: 1,
                    stderr: "Operation not permitted"
                )
            )
        }
    }

    func testStopDisablesBootsOutAndWaits() throws {
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

        XCTAssertEqual(fake.calls, [
            ["disable", "gui/501/\(script.label)"],
            ["bootout", "gui/501/\(script.label)"],
            ["list"],
            ["list"],
        ])
    }

    func testStopAcceptsNotLoadedBootout() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            if arguments.first == "bootout" {
                return LaunchctlResult(status: 3, stdout: "", stderr: "Could not find service \"x\" in domain")
            }
            return self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        XCTAssertNoThrow(try launchctl.stop(script))
    }

    func testStopTimesOutWhenStillLoaded() {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 9, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        XCTAssertThrowsError(try launchctl.waitUntilUnloaded(label: script.label, timeout: 0.05)) { error in
            XCTAssertEqual(error as? LaunchctlError, .timeout(label: script.label))
        }
    }

    func testRestartLoadedUsesKickstartK() throws {
        let script = makeScript()
        let fake = FakeRunner { arguments in
            arguments == ["list"]
                ? LaunchctlResult(status: 0, stdout: self.listOutput(pid: 9, status: 0, label: script.label), stderr: "")
                : self.success
        }
        let (launchctl, _) = makeSystem(runner: fake.run)

        try launchctl.restart(script)

        XCTAssertEqual(fake.calls, [
            ["list"],
            ["kickstart", "-k", "gui/501/\(script.label)"],
        ])
    }

    func testRestartUnloadedStarts() throws {
        let script = makeScript()
        let fake = FakeRunner { _ in self.success }
        let (launchctl, store) = makeSystem(runner: fake.run)

        try launchctl.restart(script)

        XCTAssertEqual(fake.calls, [
            ["list"],
            ["enable", "gui/501/\(script.label)"],
            ["list"],
            ["bootstrap", "gui/501", store.plistURL(for: script.name).path],
            ["kickstart", "gui/501/\(script.label)"],
        ])
    }
}
