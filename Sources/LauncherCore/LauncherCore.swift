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

    // Only known services can be launched by speech; ambiguous commands do nothing.
    public static func service(for transcript: String) -> Service? {
        let words = transcript.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let phrase = " " + words.joined(separator: " ") + " "
        var matches: [Service] = []
        if words.contains("youtube") || phrase.contains(" you tube ") { matches.append(.youtube) }
        if words.contains("netflix") || words.contains("netflex") { matches.append(.netflix) }
        if words.contains("teevie") || phrase.contains(" tee vee ") { matches.append(.teevie) }
        return matches.count == 1 ? matches[0] : nil
    }

    public static func webURL(_ address: String) -> URL? {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
}
