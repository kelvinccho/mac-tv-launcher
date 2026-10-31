import Foundation

public enum Service: String, CaseIterable, Codable, Identifiable {
    case youtube, netflix, teevie
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .youtube: return "YouTube"
        case .netflix: return "Netflix"
        case .teevie: return "TeeVee"
        }
    }
    public var defaultAddress: String {
        switch self {
        case .youtube: return "https://www.youtube.com/tv"
        case .netflix: return "https://www.netflix.com"
        case .teevie: return ""
        }
    }
}

public enum LauncherLogic {
    public static func moved(_ index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index + delta) % count + count) % count
    }

    public static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static func aliases(for service: Service) -> [String] {
        switch service {
        case .youtube: return ["youtube", "you tube"]
        case .netflix: return ["netflix", "netflex"]
        case .teevie: return ["teevie", "tee vee"]
        }
    }

    public static func tile(for transcript: String, in tiles: [Tile]) -> Tile? {
        let phrase = normalized(transcript)
        let commands = [phrase] + ["open ", "launch ", "play "].compactMap {
            phrase.hasPrefix($0) ? String(phrase.dropFirst($0.count)) : nil
        }
        let matches = tiles.filter { tile in
            let names = tile.service.map { aliases(for: $0) } ?? [normalized(tile.name)]
            return names.contains { !$0.isEmpty && commands.contains($0) }
        }
        return matches.count == 1 ? matches[0] : nil
    }

    public static func service(for transcript: String) -> Service? {
        tile(for: transcript, in: Tile.defaults)?.service
    }

    public static func webURL(_ address: String) -> URL? {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
}
