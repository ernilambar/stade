import XCTest
@testable import AppCore

final class AppInfoTests: XCTestCase {
    func testBundleMetadataIsWired() {
        XCTAssertFalse(AppInfo.name.isEmpty)
        XCTAssertTrue(AppInfo.bundleID.contains("."), "Bundle ID missing from Info.plist")
        XCTAssertEqual(AppInfo.agentLabelPrefix, AppInfo.bundleID + ".")
    }
}
