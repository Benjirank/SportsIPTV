# Sports Home Screen Brainstorm - Round 1

## Codex (Technical Architect)

### Layout
- ScrollView + LazyVStack(pinnedViews:) for premium visual control
- LiveNowHeroSection: full-width animated LIVE cards
- PinnedSportsSection: user-prioritized sports rail
- UpcomingBySportSection: grouped by pinned sports, local TZ
- QuickWatchSection: jump to relevant IPTV channels

### Architecture
- GameCenterStore: centralized observable state
- Polling: 15s live, 60-120s upcoming, diff-based updates
- TimelineView for countdown badges
- PinnedSportsStore with ordered entities, CloudKit sync option
- Animation budget: throttle in Low Power Mode, respect Reduce Motion

### UX Ideas
1. **Live Match Marquee Hero** - auto-cycling TabView with pulsing red LIVE via PhaseAnimator
2. **Pinned Sports Rail with Drag Reorder** - horizontal chips, long-press reorder
3. **Upcoming Timeline** - per sport, next 3 games on horizontal timeline with countdown
4. **Instant "Watch Live" CTA** - every card has primary play button with fast failover

### Performance Constraints
- Never bind 20k channel objects to home screen
- Prebuild normalized lookup tables off-main-thread
- Aggressive image resizing + disk cache
- EPG/API: batch requests, jitter, backoff, stale-while-revalidate

---

## Gemini (Lateral Thinker)

### Mental Model
- Move from "grid of posters" IPTV trope to "Live Stadium" model

### Patterns Stolen from Other Apps
- **Kayo "Drag-to-Multi"** - long-press live game reveals drop zone for multi-view
- **Flashscore "Match Momentum"** - tiny sparkline graph next to live scores
- **DAZN "Key Moments"** - mark goals/tries on progress bar
- **Instagram "Live Stories" Hype Rail** - circular team logos, pulsing borders when exciting
- **Apple Fitness "Season Rings"** - gamify loyalty ("watched 80% of Storm games")
- **Spotify "Wrapped"** - end-of-season summary ("48 hours watching Storm, 12 wins")

### Australia-Specific Features
- **"Morning Catch-up"** (6-10 AM only) - overnight action replays for EPL/NBA/NFL
- **State of Origin / Grand Final "Takeover"** - entire app background shifts colors
- **"Pub Mode" Audio** - sync radio commentary (ABC Grandstand/Triple M) over IPTV

### Micro-interactions
- **Haptic "Score Thump"** - double-tap haptic + scoreboard digit flip on score change
- **"Live" Breathing** - repeating pulse glow reflecting team colors
- **Parallax Team Cards** - scrollTransition modifier for depth effect

### Surprising Ideas
1. **"No Spoilers" Physical Toggle** - prominent switch, blurs all scores with "eye" icons
2. **"Fan Pressure" Heatmap** - show Nebulo user density per stream, card vibrates when surging
3. **"Siren-to-Siren" Automation** - pick your team, auto-launch stream at kickoff, game-over notification

### Implementation Tips
- matchedGeometryEffect for hero transitions card -> player
- Canvas for animated Nebula background responding to sport colors
- PhaseAnimator to cycle upcoming cards through time/venue/weather

---

## Claude (Pattern Spotter)

### Core Paradox: "The 20,000-Channel Paradox"
The 20k channels are the engine, not the interface. The interface should have the complexity of a TV guide with 6 items on it. Nebulo's question: "What's on right now that I care about?" - answer visible in under 1 second with zero taps.

### Named Patterns

| Pattern | Description |
|---------|-------------|
| **Gravitational Pull** | Visual weight proportional to relevance and liveness. Live game = 2x height, pulsing. Upcoming = smaller, muted. |
| **Kickoff Cascade** | Progressive visual escalation: static (>2hr) -> brightens (1-2hr) -> pulses (15-60min) -> glows team colors (5-15min) -> auto-expands (<5min) -> full live |
| **Matchday Mode** | Auto-activated dashboard when pinned games go live. Pub-screen layout. |
| **Sport DNA Profile** | First-launch: pick sport + team. Track implicit signals from watch history. Zero-config personalization. |
| **Phantom Remote** | Swipe right = play, left-short = pin, left-long = multi-view, double-tap = hide score |
| **Same Time Detector** | Auto-suggest Multi-View when two pinned games are live simultaneously |

### Hierarchy (Challenged)
1. MY TEAM LIVE (if playing, this IS the entire screen)
2. MY TEAM NEXT (countdown)
3. LIVE NOW across pinned sports
4. STARTING SOON (<2 hours)
5. TODAY
6. THIS WEEK (collapsed)

Key insight: Pinned sports = the LENS, not a category.

### "Show Your Mates" Features
1. **Live Score Pip-in-Pip** - floating score widget while watching any channel
2. **iOS Lock Screen Widget** - next pinned game with countdown, tap to play
3. **Rivalry Mode** - split-color card treatment when two pinned teams play each other
4. **"Same Time" Detector** - auto-suggest Multi-View for concurrent games
5. **Post-Game Auto-Highlights** - card transforms to show YouTube highlights button

---

## Proposed Killer Combination (MVP)

| # | Feature | Sources |
|---|---------|---------|
| 1 | Gravitational Pull feed - single scroll, live cards 2x with pulse | Claude + Codex |
| 2 | Sport DNA onboarding - pick sports + teams, AU defaults | Claude + Gemini |
| 3 | Kickoff Cascade - cards escalate as game approaches | Claude |
| 4 | No Spoilers toggle - prominent, haptic, blurs scores | Gemini |
| 5 | Hype Rail - circular team logos at top for live games | Gemini |
| 6 | Siren-to-Siren - follow team, auto-stream at kickoff | Gemini |

## V2 Features
- Morning Catch-up (6-10 AM)
- Swipe gestures (Phantom Remote)
- Same Time Detector -> auto Multi-View
- Season Rings / Spotify Wrapped
- Pub Mode radio audio sync
- Event Takeover (Origin/Grand Final)
- Fan Pressure Heatmap
- Live Score Pip-in-Pip
- iOS Lock Screen Widget
