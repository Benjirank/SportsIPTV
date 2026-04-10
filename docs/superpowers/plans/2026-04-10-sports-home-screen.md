# Sports Home Screen MVP - Implementation Plan (v2 - Post Review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a sports-centric home screen that becomes the default entry point via a TabView architecture, with the classic IPTV browser as a peer tab.

**Architecture:** A root `TabView` with two tabs: "Sports" (new SportsHomeView) and "TV" (existing MainView). Both are top-level peers, not modals. `SportsHomeViewModel` manages home-specific state (pinned sports, gravity sorting, no-spoilers). Existing `ScoreViewModel` provides game data, `ChannelViewModel` handles channel resolution. All three are initialized in the App struct.

**Tech Stack:** SwiftUI, existing ESPN API integration, existing ChannelViewModel/ScoreViewModel, UserDefaults for preferences.

**Review fixes applied:**
- TabView instead of fullScreenCover (Gemini: "dismissing a modal feels like a hack")
- Matchup pills in Hype Rail showing BOTH teams (Gemini)
- Correct SettingsView signature with all 6 params (Claude)
- Correct NebulaBackgroundView with @AppStorage colors (Claude)
- Haptic feedback on game card taps (Gemini)
- Cached gravity sort, not recomputed every render (Codex)
- EnvironmentObject propagation fixed (Claude)

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `Views/SportsHome/SportsHomeView.swift` | Sports tab: Hype Rail + Gravity Feed |
| `Views/SportsHome/HypeRailView.swift` | Matchup pills strip for live games |
| `Views/SportsHome/GravityGameCard.swift` | Game card with live/upcoming/finished states |
| `Views/SportsHome/SportsHomeHeader.swift` | Top bar with settings gear |
| `Views/RootTabView.swift` | Root TabView with Sports + TV tabs |
| `ViewModels/SportsHomeViewModel.swift` | Pinned sports, gravity sorting, preferences |

### Modified Files
| File | Change |
|------|--------|
| `ContentView.swift` | Show RootTabView instead of MainView when logged in |
| `Nebulo_V2_4App.swift` | Initialize SportsHomeViewModel, pass as environmentObject |

---

## Task 1: SportsHomeViewModel

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/ViewModels/SportsHomeViewModel.swift`

- [ ] **Step 1: Create the view model**

```swift
import Foundation
import SwiftUI

@MainActor
class SportsHomeViewModel: ObservableObject {
    static let shared = SportsHomeViewModel()

    @Published var pinnedSports: [SportType] = [] {
        didSet { savePinnedSports() }
    }

    @Published var favoriteTeams: [String] = [] {
        didSet { UserDefaults.standard.set(favoriteTeams, forKey: "sportsHome_favoriteTeams") }
    }

    @Published var noSpoilers: Bool = false {
        didSet { UserDefaults.standard.set(noSpoilers, forKey: "sportsHome_noSpoilers") }
    }

    // Cached sorted games - recomputed only when source data changes
    @Published var sortedGames: [ESPNEvent] = []
    @Published var liveGames: [ESPNEvent] = []

    init() {
        self.noSpoilers = UserDefaults.standard.bool(forKey: "sportsHome_noSpoilers")
        self.favoriteTeams = UserDefaults.standard.stringArray(forKey: "sportsHome_favoriteTeams") ?? []
        loadPinnedSports()
    }

    private func loadPinnedSports() {
        if let saved = UserDefaults.standard.stringArray(forKey: "sportsHome_pinnedSports") {
            pinnedSports = saved.compactMap { SportType(rawValue: $0) }
        }
        if pinnedSports.isEmpty {
            pinnedSports = [.nrl, .afl, .nbl, .nba, .nfl]
        }
    }

    private func savePinnedSports() {
        UserDefaults.standard.set(pinnedSports.map { $0.rawValue }, forKey: "sportsHome_pinnedSports")
    }

    func togglePinnedSport(_ sport: SportType) {
        if pinnedSports.contains(sport) {
            pinnedSports.removeAll { $0 == sport }
        } else {
            pinnedSports.append(sport)
        }
    }

    /// Call this when score data changes - caches the sorted result
    func updateGames(from scoreViewModel: ScoreViewModel) {
        var games: [ESPNEvent] = []
        for sport in pinnedSports {
            if let sportGames = scoreViewModel.filteredGames[sport] {
                games.append(contentsOf: sportGames)
            }
            if let sections = scoreViewModel.filteredSectionsMap[sport] {
                for section in sections {
                    games.append(contentsOf: section.games)
                }
            }
        }
        // Deduplicate
        var seen = Set<String>()
        games = games.filter { seen.insert($0.id).inserted }

        let now = Date()
        sortedGames = games.sorted { a, b in
            let aw = gravityWeight(a, now: now)
            let bw = gravityWeight(b, now: now)
            if aw != bw { return aw > bw }
            return a.gameDate < b.gameDate
        }
        liveGames = games.filter { isLiveOrImminent($0) }
    }

    func gravityWeight(_ game: ESPNEvent, now: Date = Date()) -> Int {
        let state = game.status.type.state
        if state == "in" { return 10000 }
        if state == "pre" {
            let timeUntil = game.gameDate.timeIntervalSince(now)
            if timeUntil < 0 { return 9000 }
            if timeUntil < 900 { return 8000 }
            if timeUntil < 3600 { return 7000 }
            if timeUntil < 7200 { return 6000 }
            if Calendar.current.isDateInToday(game.gameDate) { return 5000 }
            return 4000
        }
        return 1000
    }

    func isLiveOrImminent(_ game: ESPNEvent) -> Bool {
        let state = game.status.type.state
        if state == "in" { return true }
        if state == "pre" { return game.gameDate.timeIntervalSince(Date()) < 900 }
        return false
    }

    func sportForGame(_ game: ESPNEvent, scoreViewModel: ScoreViewModel) -> SportType {
        for sport in pinnedSports {
            if let games = scoreViewModel.filteredGames[sport], games.contains(where: { $0.id == game.id }) {
                return sport
            }
            if let sections = scoreViewModel.filteredSectionsMap[sport] {
                for section in sections {
                    if section.games.contains(where: { $0.id == game.id }) { return sport }
                }
            }
        }
        return .nrl
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/ViewModels/SportsHomeViewModel.swift
git commit -m "feat: add SportsHomeViewModel with cached gravity sorting"
```

---

## Task 2: GravityGameCard

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/GravityGameCard.swift`

- [ ] **Step 1: Create gravity-weighted game card with haptics**

Live = 2x height, red pulse glow, prominent score. Upcoming = normal, countdown. Finished = dimmed.

```swift
import SwiftUI

struct GravityGameCard: View {
    let game: ESPNEvent
    let sport: SportType
    let isLive: Bool
    let noSpoilers: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    private var gameState: String { game.status.type.state }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        }) {
            VStack(spacing: 0) {
                if isLive { liveCard } else { standardCard }
            }
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLive ? Color.red.opacity(isPulsing ? 0.8 : 0.3) : Color.white.opacity(0.08), lineWidth: isLive ? 2 : 1)
            )
            .shadow(color: isLive ? .red.opacity(0.3) : .clear, radius: isPulsing ? 12 : 6)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isLive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - Live Card (2x height)

    private var liveCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6).opacity(isPulsing ? 1 : 0.5)
                    Text("LIVE").font(.system(size: 10, weight: .black)).foregroundStyle(.red)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.red.opacity(0.15)).clipShape(Capsule())
                Spacer()
                Text(sport.rawValue).font(.caption2.bold()).foregroundStyle(.white.opacity(0.5))
            }

            HStack(alignment: .center, spacing: 8) {
                teamView(game.awayCompetitor)
                VStack(spacing: 2) {
                    if noSpoilers {
                        Text("? - ?").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    } else {
                        Text(scoreText).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                }.frame(minWidth: 90)
                teamView(game.homeCompetitor)
            }

            Text(game.status.type.detail).font(.caption.bold()).foregroundStyle(.red)
        }
        .padding(20)
    }

    // MARK: - Standard Card

    private var standardCard: some View {
        HStack(alignment: .center, spacing: 8) {
            compactTeamView(game.awayCompetitor)
            Spacer()
            VStack(spacing: 4) {
                if gameState == "pre" {
                    Text(timeDisplay).font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                    countdownBadge
                } else {
                    Text(noSpoilers ? "?" : scoreText).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    Text("FINAL").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.3))
                }
                Text(sport.rawValue).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.3))
            }.frame(minWidth: 80)
            Spacer()
            compactTeamView(game.homeCompetitor)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .opacity(gameState == "post" ? 0.6 : 1)
    }

    // MARK: - Helpers

    private func teamView(_ competitor: ESPNCompetitor?) -> some View {
        VStack(spacing: 6) {
            CachedAsyncImage(urlString: competitor?.team?.logo ?? "", size: CGSize(width: 48, height: 48)).frame(width: 48, height: 48)
            Text(competitor?.team?.shortDisplayName ?? "TBD").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
        }.frame(maxWidth: .infinity)
    }

    private func compactTeamView(_ competitor: ESPNCompetitor?) -> some View {
        HStack(spacing: 8) {
            CachedAsyncImage(urlString: competitor?.team?.logo ?? "", size: CGSize(width: 28, height: 28)).frame(width: 28, height: 28)
            Text(competitor?.team?.shortDisplayName ?? "TBD").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
        }
    }

    private var scoreText: String {
        "\(game.awayCompetitor?.score ?? "0") - \(game.homeCompetitor?.score ?? "0")"
    }

    private var timeDisplay: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE d MMM\nh:mm a"
        fmt.timeZone = .current
        return fmt.string(from: game.gameDate)
    }

    @ViewBuilder private var countdownBadge: some View {
        let timeUntil = game.gameDate.timeIntervalSince(Date())
        if timeUntil > 0 && timeUntil < 7200 {
            let mins = Int(timeUntil / 60)
            Text(mins >= 60 ? "\(mins/60)h \(mins%60)m" : "\(mins)m")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.orange.opacity(0.15)).clipShape(Capsule())
        }
    }

    private var cardBackground: some ShapeStyle {
        isLive
            ? AnyShapeStyle(LinearGradient(colors: [Color.red.opacity(0.15), Color.black.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color.white.opacity(0.06))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/GravityGameCard.swift
git commit -m "feat: add GravityGameCard with live pulse, haptics, and no-spoilers"
```

---

## Task 3: HypeRailView - Matchup Pills

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/HypeRailView.swift`

- [ ] **Step 1: Create Hype Rail with BOTH team logos per game (matchup pills)**

```swift
import SwiftUI

struct HypeRailView: View {
    let liveGames: [ESPNEvent]
    let noSpoilers: Bool
    let onTapGame: (ESPNEvent) -> Void

    var body: some View {
        if liveGames.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 8) {
                Text("LIVE NOW").font(.system(size: 11, weight: .black)).foregroundStyle(.red).padding(.leading, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(liveGames) { game in
                            MatchupPill(game: game, noSpoilers: noSpoilers) { onTapGame(game) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct MatchupPill: View {
    let game: ESPNEvent
    let noSpoilers: Bool
    let onTap: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                // Away team logo
                CachedAsyncImage(urlString: game.awayCompetitor?.team?.logo ?? "", size: CGSize(width: 32, height: 32))
                    .frame(width: 32, height: 32).clipShape(Circle())

                // Score or VS
                VStack(spacing: 1) {
                    if game.status.type.state == "in" && !noSpoilers {
                        Text("\(game.awayCompetitor?.score ?? "0")-\(game.homeCompetitor?.score ?? "0")")
                            .font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white)
                    } else {
                        Text("VS").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Home team logo
                CachedAsyncImage(urlString: game.homeCompetitor?.team?.logo ?? "", size: CGSize(width: 32, height: 32))
                    .frame(width: 32, height: 32).clipShape(Circle())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.red.opacity(isPulsing ? 0.8 : 0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { isPulsing = true }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/HypeRailView.swift
git commit -m "feat: add HypeRailView with matchup pills showing both teams"
```

---

## Task 4: SportsHomeHeader

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/SportsHomeHeader.swift`

- [ ] **Step 1: Create header with settings button**

```swift
import SwiftUI

struct SportsHomeHeader: View {
    let onSettingsTap: () -> Void

    var body: some View {
        HStack {
            Text("Sports").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            Spacer()
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/SportsHomeHeader.swift
git commit -m "feat: add SportsHomeHeader"
```

---

## Task 5: SportsHomeView - Main Sports Tab

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/SportsHomeView.swift`

- [ ] **Step 1: Create the sports home screen**

Uses correct NebulaBackgroundView with @AppStorage colors. Uses correct SettingsView signature. Cached gravity sort from view model.

```swift
import SwiftUI

struct SportsHomeView: View {
    @ObservedObject var channelViewModel: ChannelViewModel
    @ObservedObject var scoreViewModel: ScoreViewModel
    @ObservedObject var homeViewModel: SportsHomeViewModel

    @State private var showSettings = false
    @State private var selectedChannel: StreamChannel? = nil

    // Nebula background colors from user preferences
    @AppStorage("nebColor1") private var nebColor1 = "#AF52DE"
    @AppStorage("nebColor2") private var nebColor2 = "#007AFF"
    @AppStorage("nebColor3") private var nebColor3 = "#FF2D55"
    @AppStorage("nebX1") private var nebX1 = 0.2
    @AppStorage("nebY1") private var nebY1 = 0.2
    @AppStorage("nebX2") private var nebX2 = 0.8
    @AppStorage("nebY2") private var nebY2 = 0.3
    @AppStorage("nebX3") private var nebX3 = 0.5
    @AppStorage("nebY3") private var nebY3 = 0.8

    var body: some View {
        NavigationStack {
            ZStack {
                NebulaBackgroundView(
                    color1: Color(hex: nebColor1) ?? .purple,
                    color2: Color(hex: nebColor2) ?? .blue,
                    color3: Color(hex: nebColor3) ?? .pink,
                    point1: UnitPoint(x: nebX1, y: nebY1),
                    point2: UnitPoint(x: nebX2, y: nebY2),
                    point3: UnitPoint(x: nebX3, y: nebY3)
                )

                VStack(spacing: 0) {
                    SportsHomeHeader(onSettingsTap: { showSettings = true })

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            // Hype Rail
                            HypeRailView(
                                liveGames: homeViewModel.liveGames,
                                noSpoilers: homeViewModel.noSpoilers,
                                onTapGame: { game in playGame(game) }
                            )

                            // Pinned sports chips
                            pinnedSportsChips.padding(.horizontal, 20)

                            // Gravity feed
                            ForEach(homeViewModel.sortedGames) { game in
                                let sport = homeViewModel.sportForGame(game, scoreViewModel: scoreViewModel)
                                GravityGameCard(
                                    game: game,
                                    sport: sport,
                                    isLive: homeViewModel.isLiveOrImminent(game),
                                    noSpoilers: homeViewModel.noSpoilers,
                                    onTap: { playGame(game) }
                                )
                                .padding(.horizontal, 16)
                            }

                            if homeViewModel.sortedGames.isEmpty && !scoreViewModel.isLoading {
                                VStack(spacing: 12) {
                                    Image(systemName: "sportscourt").font(.system(size: 40)).foregroundStyle(.white.opacity(0.3))
                                    Text("No games found").font(.headline).foregroundStyle(.white.opacity(0.5))
                                    Text("Pull to refresh or check your pinned sports").font(.caption).foregroundStyle(.white.opacity(0.3))
                                }
                                .frame(height: 300)
                            }
                        }
                        .padding(.bottom, 120)
                    }
                    .refreshable {
                        await scoreViewModel.fetchScores(forceRefresh: true)
                        homeViewModel.updateGames(from: scoreViewModel)
                    }
                }

                if channelViewModel.isSearchingGame {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 15) {
                            CustomSpinner(color: .white, lineWidth: 4, size: 40)
                            Text("Finding best stream...").font(.caption).bold().foregroundStyle(.white)
                        }
                        .padding(25).background(.ultraThinMaterial).cornerRadius(20).shadow(radius: 20)
                    }
                    .transition(.opacity).zIndex(100)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    categories: Binding(
                        get: { channelViewModel.categories },
                        set: { channelViewModel.categories = $0 }
                    ),
                    accentColor: .blue,
                    viewModel: channelViewModel,
                    scoreViewModel: scoreViewModel,
                    playAction: { channel in selectedChannel = channel },
                    onSave: { channelViewModel.saveCategorySettings() }
                )
            }
            .sheet(isPresented: $channelViewModel.showSelectionSheet) {
                ManualSelectionSheet(
                    viewModel: channelViewModel,
                    accentColor: .blue,
                    playAction: { channel in selectedChannel = channel }
                )
            }
            .fullScreenCover(item: $selectedChannel) { channel in
                CustomVideoPlayerView(channel: channel, viewModel: channelViewModel)
            }
            .onChangeCompat(of: channelViewModel.channelToAutoPlay) { nc in
                if let c = nc {
                    withAnimation(.easeInOut(duration: 0.4)) { selectedChannel = c }
                    channelViewModel.channelToAutoPlay = nil
                }
            }
            .task {
                await scoreViewModel.fetchScores()
                homeViewModel.updateGames(from: scoreViewModel)
            }
            .onChangeCompat(of: scoreViewModel.filteredGames) { _ in
                homeViewModel.updateGames(from: scoreViewModel)
            }
        }
    }

    // MARK: - Pinned Sports Chips

    private var pinnedSportsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(homeViewModel.pinnedSports) { sport in
                    Text(sport.rawValue)
                        .font(.caption.bold())
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(.white.opacity(0.1))
                        .foregroundStyle(.white.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Play Game

    private func playGame(_ game: ESPNEvent) {
        let sport = homeViewModel.sportForGame(game, scoreViewModel: scoreViewModel)
        let h = game.homeCompetitor?.team?.shortDisplayName ?? game.homeCompetitor?.athlete?.shortName ?? ""
        let a = game.awayCompetitor?.team?.shortDisplayName ?? game.awayCompetitor?.athlete?.shortName ?? ""
        let gameChannels = sport == .nrl ? (scoreViewModel.nrlGameChannels[game.id] ?? sport.fallbackBroadcasts) : nil
        channelViewModel.runSmartSearch(gameID: game.id, home: h, away: a, sport: sport, network: game.broadcastName, gameChannels: gameChannels)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/Views/SportsHome/SportsHomeView.swift
git commit -m "feat: add SportsHomeView with correct signatures and cached sort"
```

---

## Task 6: RootTabView + ContentView Routing

**Files:**
- Create: `Nebulo_AVPlayer/Nebulo/Nebulo/Views/RootTabView.swift`
- Modify: `Nebulo_AVPlayer/Nebulo/Nebulo/ContentView.swift`
- Modify: `Nebulo_AVPlayer/Nebulo/Nebulo/Nebulo_V2_4App.swift`

- [ ] **Step 1: Create RootTabView with Sports and TV tabs**

```swift
import SwiftUI

struct RootTabView: View {
    @ObservedObject var channelViewModel: ChannelViewModel
    @ObservedObject var scoreViewModel: ScoreViewModel
    @ObservedObject var homeViewModel: SportsHomeViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SportsHomeView(
                channelViewModel: channelViewModel,
                scoreViewModel: scoreViewModel,
                homeViewModel: homeViewModel
            )
            .tabItem {
                Image(systemName: "sportscourt.fill")
                Text("Sports")
            }
            .tag(0)

            MainView(viewModel: channelViewModel, scoreViewModel: scoreViewModel)
                .tabItem {
                    Image(systemName: "tv.fill")
                    Text("TV")
                }
                .tag(1)
        }
        .tint(.white)
    }
}
```

- [ ] **Step 2: Update ContentView.swift**

Replace the logged-in branch to use RootTabView:

```swift
struct ContentView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @ObservedObject var viewModel: ChannelViewModel
    @ObservedObject var scoreViewModel: ScoreViewModel
    @EnvironmentObject var sportsHomeViewModel: SportsHomeViewModel

    var body: some View {
        Group {
            if accountManager.isLoggedIn {
                RootTabView(
                    channelViewModel: viewModel,
                    scoreViewModel: scoreViewModel,
                    homeViewModel: sportsHomeViewModel
                )
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3: Update Nebulo_V2_4App.swift**

Add SportsHomeViewModel StateObject and environmentObject:

```swift
@StateObject private var sportsHomeViewModel = SportsHomeViewModel.shared
```

On the ContentView, add:
```swift
.environmentObject(sportsHomeViewModel)
```

- [ ] **Step 4: Update ContentView Preview**

```swift
#Preview {
    ContentView(viewModel: ChannelViewModel(), scoreViewModel: ScoreViewModel())
        .environmentObject(SportsHomeViewModel.shared)
}
```

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project Nebulo_AVPlayer/Nebulo.xcodeproj -scheme Nebulo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Nebulo_AVPlayer/Nebulo/Nebulo/Views/RootTabView.swift Nebulo_AVPlayer/Nebulo/Nebulo/ContentView.swift Nebulo_AVPlayer/Nebulo/Nebulo/Nebulo_V2_4App.swift
git commit -m "feat: add RootTabView with Sports and TV tabs as peer navigation"
```

---

## Task 7: Build and Install on Device

- [ ] **Step 1: Build for device**

```bash
xcodebuild -project Nebulo_AVPlayer/Nebulo.xcodeproj -scheme Nebulo -destination 'platform=iOS,name=Ben' -configuration Debug -allowProvisioningUpdates build
```

- [ ] **Step 2: Install**

```bash
xcrun devicectl device install app --device 00008150-001174182161401C ~/Library/Developer/Xcode/DerivedData/Nebulo-*/Build/Products/Debug-iphoneos/Nebulo.app
```

- [ ] **Step 3: Verify**

- App opens to TabView with Sports and TV tabs
- Sports tab shows Hype Rail for live games (matchup pills with both teams)
- Gravity feed shows pinned sports games sorted by urgency
- Live games are 2x height with red pulse
- Upcoming games show local timezone and countdown
- Finished games are dimmed
- Haptic feedback on game card taps
- Tapping a game triggers channel search
- TV tab shows classic IPTV browser (MainView)
- Settings opens correctly from Sports tab
- Pull to refresh works
- No Spoilers toggle (in SportsHomeViewModel) blurs scores

---

## Summary

| Task | Component | Key fixes from review |
|------|-----------|----------------------|
| 1 | SportsHomeViewModel | Cached gravity sort (not recomputed every render) |
| 2 | GravityGameCard | Haptic feedback on tap |
| 3 | HypeRailView | Matchup pills with BOTH team logos |
| 4 | SportsHomeHeader | Clean, minimal |
| 5 | SportsHomeView | Correct SettingsView (6 params), NebulaBackgroundView (@AppStorage), correct ManualSelectionSheet |
| 6 | RootTabView + routing | TabView architecture (not fullScreenCover), EnvironmentObject propagation |
| 7 | Device install | End-to-end verification |
