import Foundation

public struct Tile: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var address: String
    public var service: Service? { Service(rawValue: id) }

    public init(id: String = UUID().uuidString, name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }

    public static var defaults: [Tile] {
        Service.allCases.map { Tile(id: $0.rawValue, name: $0.title, address: $0.defaultAddress) }
    }
}

public enum TileError: Error, LocalizedError {
    case invalidName, duplicateName, invalidAddress, damagedStorage
    public var errorDescription: String? {
        switch self {
        case .invalidName: return "Enter a tile name containing letters or numbers."
        case .duplicateName: return "Choose a unique name that differs from the existing tiles and voice aliases."
        case .invalidAddress: return "Enter a valid full http:// or https:// address without credentials."
        case .damagedStorage: return "Saved tiles could not be read. The saved data has been preserved. Back up and repair launcher.tiles (or the legacy service settings) in UserDefaults before editing tiles."
        }
    }
}

public final class TileStore {
    public static let key = "launcher.tiles"
    private let defaults: UserDefaults
    private struct Document: Codable { var version: Int; var tiles: [Tile] }
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() throws -> [Tile] {
        if let stored = defaults.object(forKey: Self.key) {
            guard let data = stored as? Data,
                  let document = try? JSONDecoder().decode(Document.self, from: data),
                  document.version == 1,
                  (try? validate(document.tiles)) != nil else { throw TileError.damagedStorage }
            return document.tiles
        }
        var tiles = Tile.defaults
        for index in tiles.indices {
            if let legacy = defaults.object(forKey: "service.\(tiles[index].id)") {
                guard let address = legacy as? String else { throw TileError.damagedStorage }
                tiles[index].address = address.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        do { try save(tiles) } catch { throw TileError.damagedStorage }
        return tiles
    }

    public func save(_ tiles: [Tile]) throws {
        // A failed load must never become a silent reset on a later Save.
        if defaults.object(forKey: Self.key) != nil { _ = try load() }
        try validate(tiles)
        let data = try JSONEncoder().encode(Document(version: 1, tiles: tiles))
        defaults.set(data, forKey: Self.key)
    }

    public func adding(name: String, address: String, to tiles: [Tile]) throws -> [Tile] {
        let tile = Tile(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        address: address.trimmingCharacters(in: .whitespacesAndNewlines))
        let updated = tiles + [tile]
        try save(updated)
        return updated
    }

    private func validate(_ tiles: [Tile]) throws {
        guard tiles.count >= Service.allCases.count,
              Array(tiles.prefix(3).map(\.id)) == Service.allCases.map(\.rawValue),
              Set(tiles.map(\.id)).count == tiles.count,
              tiles.allSatisfy({ !$0.id.isEmpty }) else { throw TileError.damagedStorage }
        var names = Set<String>()
        for tile in tiles {
            let normalized = LauncherLogic.normalized(tile.name)
            guard !normalized.isEmpty else { throw TileError.invalidName }
            let aliases = tile.service.map { LauncherLogic.aliases(for: $0) } ?? [normalized]
            guard names.isDisjoint(with: aliases) else { throw TileError.duplicateName }
            names.formUnion(aliases)
            if let service = tile.service {
                guard tile.name == service.title else { throw TileError.invalidName }
            }
            guard (tile.id == Service.teevie.rawValue && tile.address.isEmpty) || LauncherLogic.webURL(tile.address) != nil else {
                throw TileError.invalidAddress
            }
        }
    }
}

/// Key-up is required before another toggle; Caps Lock and device flags do not affect the chord.
public struct VoiceShortcut {
    private var held = false
    public init() {}
    public mutating func reset() { held = false }
    public mutating func handle(keyCode: UInt16, keyDown: Bool, isRepeat: Bool,
                                command: Bool, shift: Bool, control: Bool, option: Bool,
                                inputActive: Bool) -> Bool {
        guard keyCode == 49 else { return false }
        if !keyDown { held = false; return false }
        guard !held, !isRepeat else { return false }
        held = true
        return !inputActive && command && shift && !control && !option
    }
}

/// Permission, recognition and delayed completion callbacks share one cancellable generation.
public struct VoiceSession {
    private var current: UUID?
    public init() {}
    public mutating func begin() -> UUID {
        let token = UUID()
        current = token
        return token
    }
    public func isCurrent(_ token: UUID) -> Bool { current == token }
    public mutating func cancel() { current = nil }
}
