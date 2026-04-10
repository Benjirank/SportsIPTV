import Foundation

struct NRLDrawResponse: Codable, Sendable {
    let fixtures: [NRLFixture]?
}

struct NRLFixture: Codable, Sendable {
    let matchMode: String?
    let homeTeam: NRLTeam?
    let awayTeam: NRLTeam?
    let videoProviders: [NRLVideoProvider]?
}

struct NRLTeam: Codable, Sendable {
    let nickName: String?
}

struct NRLVideoProvider: Codable, Sendable {
    let id: String
    let name: String?
}

actor NRLService {
    static let shared = NRLService()

    // Maps NRL provider IDs to IPTV channel name patterns
    static let providerChannelMap: [String: [String]] = [
        "FOX": ["Fox Sports 502", "Fox Sports 504"],
        "NINE": ["Channel Nine"],
    ]

    private var cachedBroadcasts: [String: [String]] = [:]
    private var lastFetchTime: Date = .distantPast

    /// Fetch broadcast channels for NRL games in the current round.
    /// Returns a dictionary keyed by "homeNickname_vs_awayNickname" → [IPTV channel patterns]
    func fetchBroadcasts() async -> [String: [String]] {
        if !cachedBroadcasts.isEmpty && Date().timeIntervalSince(lastFetchTime) < 300 {
            return cachedBroadcasts
        }

        let urlStr = "https://www.nrl.com/draw/data?competition=111&season=2026"
        guard let url = URL(string: urlStr) else { return [:] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(NRLDrawResponse.self, from: data)

            var result: [String: [String]] = [:]
            for fixture in response.fixtures ?? [] {
                guard let home = fixture.homeTeam?.nickName?.lowercased(),
                      let away = fixture.awayTeam?.nickName?.lowercased() else { continue }

                let providers = fixture.videoProviders ?? []
                var channels: [String] = []
                for provider in providers {
                    if let mapped = NRLService.providerChannelMap[provider.id] {
                        channels.append(contentsOf: mapped)
                    }
                }
                if !channels.isEmpty {
                    let key = "\(home)_vs_\(away)"
                    result[key] = channels
                }
            }

            cachedBroadcasts = result
            lastFetchTime = Date()
            return result
        } catch {
            return cachedBroadcasts
        }
    }

    /// Look up IPTV channels for a specific game by team nicknames
    func channelsForGame(home: String, away: String) -> [String] {
        let key = "\(home.lowercased())_vs_\(away.lowercased())"
        return cachedBroadcasts[key] ?? []
    }
}
