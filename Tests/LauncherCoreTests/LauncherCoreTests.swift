import XCTest
@testable import LauncherCore

final class LauncherCoreTests: XCTestCase {
    func testNavigationWrapsInBothDirections() {
        XCTAssertEqual(LauncherLogic.moved(0, by: -1, count: 3), 2)
        XCTAssertEqual(LauncherLogic.moved(2, by: 1, count: 3), 0)
        XCTAssertEqual(LauncherLogic.moved(1, by: 1, count: 3), 2)
        XCTAssertEqual(LauncherLogic.moved(0, by: -1, count: 0), 0)
    }

    func testRecognizesServiceNamesAndSpeechVariants() {
        XCTAssertEqual(LauncherLogic.service(for: "Open YouTube"), .youtube)
        XCTAssertEqual(LauncherLogic.service(for: "open you tube"), .youtube)
        XCTAssertEqual(LauncherLogic.service(for: "NETFLIX!"), .netflix)
        XCTAssertEqual(LauncherLogic.service(for: "netflex"), .netflix)
        XCTAssertEqual(LauncherLogic.service(for: "Open tee vee"), .teevie)
    }

    func testRejectsUnknownAndAmbiguousSpeech() {
        XCTAssertNil(LauncherLogic.service(for: ""))
        XCTAssertNil(LauncherLogic.service(for: "open settings"))
        XCTAssertNil(LauncherLogic.service(for: "notyoutube"))
        XCTAssertNil(LauncherLogic.service(for: "YouTube or Netflix"))
    }

    func testOnlyWebAddressesAreAccepted() {
        XCTAssertNotNil(LauncherLogic.webURL(" https://example.com/watch?q=tv "))
        XCTAssertNotNil(LauncherLogic.webURL("http://localhost:8080"))
        for invalid in ["", "netflix.com", "https://", "file:///tmp/video", "javascript:alert(1)", "https://user:password@example.com"] {
            XCTAssertNil(LauncherLogic.webURL(invalid), invalid)
        }
    }
}
