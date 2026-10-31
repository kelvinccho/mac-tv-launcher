import XCTest
@testable import LauncherCore

final class TileStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        suite = "TVLauncherTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testLegacyAddressesSurviveMigrationAndRepeatedLoad() throws {
        let addresses = ["https://example.org/youtube", "http://localhost:8090/netflix", "https://example.org/teevie"]
        for (service, address) in zip(Service.allCases, addresses) {
            defaults.set(address, forKey: "service.\(service.rawValue)")
        }
        let first = try TileStore(defaults: defaults).load()
        XCTAssertEqual(first.map(\.address), addresses)
        let saved = defaults.data(forKey: TileStore.key)
        for _ in 0..<3 { XCTAssertEqual(try TileStore(defaults: defaults).load(), first) }
        XCTAssertEqual(defaults.data(forKey: TileStore.key), saved)
        XCTAssertEqual(defaults.string(forKey: "service.teevie"), addresses[2])
    }

    func testDefaultsKeepTeeVeeUnconfigured() throws {
        XCTAssertEqual(try TileStore(defaults: defaults).load(), Tile.defaults)
        XCTAssertNil(LauncherLogic.webURL(try TileStore(defaults: defaults).load()[2].address))
    }

    func testAddPersistsNameURLAndStableIdentityAcrossNewStore() throws {
        let store = TileStore(defaults: defaults)
        let tiles = try store.adding(name: "  BBC News  ", address: " https://example.org/news?q=tv ", to: store.load())
        XCTAssertEqual(tiles.last?.name, "BBC News")
        XCTAssertEqual(tiles.last?.address, "https://example.org/news?q=tv")
        XCTAssertEqual(try TileStore(defaults: defaults).load(), tiles)
        XCTAssertEqual(LauncherLogic.tile(for: "open bbc news", in: tiles), tiles.last)
    }

    func testInvalidAddAndInvalidSettingsPreserveSavedData() throws {
        let store = TileStore(defaults: defaults)
        let original = try store.load()
        let bytes = defaults.data(forKey: TileStore.key)
        for name in ["", "  !!!  ", "YouTube", "you tube", "NETFLEX", "Tee Vee"] {
            XCTAssertThrowsError(try store.adding(name: name, address: "https://example.org", to: original), name)
        }
        for url in ["", "example.org", "file:///tmp/a", "https://user:pass@example.org"] {
            XCTAssertThrowsError(try store.adding(name: "News", address: url, to: original))
        }
        var edit = original
        edit[0].address = "invalid"
        XCTAssertThrowsError(try store.save(edit))
        XCTAssertEqual(defaults.data(forKey: TileStore.key), bytes)
        XCTAssertEqual(try store.load(), original)
    }

    func testMalformedOrFutureStorageCannotBeSilentlyReplaced() throws {
        let valid = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Tile.defaults)) as! [[String: Any]]
        let badDocuments: [Any] = ["not data", Data("broken".utf8),
            try JSONSerialization.data(withJSONObject: ["version": 2, "tiles": valid]),
            try JSONSerialization.data(withJSONObject: ["version": 1, "tiles": []]),
            try JSONSerialization.data(withJSONObject: ["version": 1, "tiles": valid + [valid[0]]])]
        for document in badDocuments {
            defaults.set(document, forKey: TileStore.key)
            let before = defaults.object(forKey: TileStore.key) as! NSObject
            let store = TileStore(defaults: defaults)
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.save(Tile.defaults))
            XCTAssertEqual(defaults.object(forKey: TileStore.key) as? NSObject, before)
        }
    }

    func testMalformedLegacySettingsRemainUntouched() {
        for bad in ["not a URL", 42] as [Any] {
            defaults.set(bad, forKey: "service.youtube")
            XCTAssertThrowsError(try TileStore(defaults: defaults).load())
            XCTAssertNil(defaults.object(forKey: TileStore.key))
            XCTAssertEqual(defaults.object(forKey: "service.youtube") as? NSObject, bad as? NSObject)
        }
    }

    func testLargeCollectionRemainsNavigableAndPersists() throws {
        let store = TileStore(defaults: defaults)
        var tiles = try store.load()
        for index in 0..<40 { tiles = try store.adding(name: "Channel \(index)", address: "https://example.org/\(index)", to: tiles) }
        XCTAssertEqual(try store.load(), tiles)
        XCTAssertEqual(LauncherLogic.moved(0, by: -1, count: tiles.count), 42)
        XCTAssertEqual(LauncherLogic.moved(42, by: 1, count: tiles.count), 0)
        XCTAssertEqual(LauncherLogic.tile(for: "Channel 39", in: tiles), tiles.last)
        XCTAssertEqual(Array(tiles.prefix(3).compactMap(\.service)), Service.allCases)
    }

    func testCustomSpeechRequiresCompleteUnambiguousName() {
        let news = Tile(name: "BBC News", address: "https://example.org")
        let tiles = Tile.defaults + [news]
        XCTAssertEqual(LauncherLogic.tile(for: "OPEN BBC News!", in: tiles), news)
        for transcript in ["news", "BBC", "open unknown", "open BBC News or Netflix", "don't open Netflix", "YouTube Netflix"] {
            XCTAssertNil(LauncherLogic.tile(for: transcript, in: tiles), transcript)
        }
        XCTAssertNil(LauncherLogic.tile(for: "BBC News", in: tiles + [Tile(name: "bbc news", address: "https://example.net")]))
        XCTAssertNil(LauncherLogic.tile(for: "open Netflix", in: tiles + [Tile(name: "Open Netflix", address: "https://example.net")]))
    }
}

final class VoiceShortcutTests: XCTestCase {
    func testOneTogglePerPhysicalPressAndRelease() {
        var shortcut = VoiceShortcut()
        func event(_ down: Bool = true, repeat repeating: Bool = false, input: Bool = false) -> Bool {
            shortcut.handle(keyCode: 49, keyDown: down, isRepeat: repeating, command: true, shift: true, control: false, option: false, inputActive: input)
        }
        XCTAssertTrue(event())
        XCTAssertFalse(event(repeat: true))
        XCTAssertFalse(event())
        XCTAssertFalse(event(false))
        XCTAssertTrue(event())
        shortcut.reset()
        XCTAssertFalse(event(repeat: true))
        XCTAssertFalse(event(false))
        XCTAssertFalse(event(input: true))
        XCTAssertFalse(event(false, input: true))
        XCTAssertTrue(event())
    }

    func testOnlyExactCommandShiftChordOutsideInput() {
        for command in [false, true] {
            for shift in [false, true] {
                for control in [false, true] {
                    for option in [false, true] {
                        var shortcut = VoiceShortcut()
                        XCTAssertEqual(shortcut.handle(keyCode: 49, keyDown: true, isRepeat: false, command: command, shift: shift, control: control, option: option, inputActive: false), command && shift && !control && !option)
                    }
                }
            }
        }
        var shortcut = VoiceShortcut()
        XCTAssertFalse(shortcut.handle(keyCode: 36, keyDown: true, isRepeat: false, command: true, shift: true, control: false, option: false, inputActive: false))
    }
}

final class VoiceSessionTests: XCTestCase {
    func testCancellationInvalidatesPendingPermissionAndTranscriptCallbacks() {
        var session = VoiceSession()
        let pending = session.begin()
        XCTAssertTrue(session.isCurrent(pending))
        session.cancel()
        XCTAssertFalse(session.isCurrent(pending))
        let next = session.begin()
        XCTAssertFalse(session.isCurrent(pending))
        XCTAssertTrue(session.isCurrent(next))
    }

    func testNewRecognitionInvalidatesOldResultsAndCompletionIsOneShot() {
        var session = VoiceSession()
        let old = session.begin()
        let current = session.begin()
        XCTAssertFalse(session.isCurrent(old))
        var launches = 0
        for _ in 0..<2 {
            if session.isCurrent(current) { session.cancel(); launches += 1 }
        }
        XCTAssertEqual(launches, 1)
    }
}
