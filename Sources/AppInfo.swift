import Foundation

/// Name-related values are read from the bundle, so the app name and bundle ID
/// are defined only in `Config/App.xcconfig`.
enum AppInfo {
    /// Display name from the generated Info.plist.
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "App"
    }

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    /// Prefix for launchd agent labels, e.g. `com.example.app.`.
    static var agentLabelPrefix: String {
        bundleID + "."
    }

    /// `~/Library/Logs/<app name>`.
    static var logDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
}
