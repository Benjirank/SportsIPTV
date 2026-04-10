# Sports Home Screen Brainstorm - Round 2

## Round 2 Consensus

### CUT from MVP
- **Kickoff Cascade (6 stages)** - All three AIs agreed: over-scoped. Ship 2 states (normal + LIVE pulse)
- **Siren-to-Siren (auto-launch)** - iOS can't auto-launch streams from background. Ship as kickoff notification + deep link

### PROMOTED into MVP
- **Lock Screen Widget** - Highest-frequency touchpoint, free marketing
- **Morning Catch-up** - THE killer Australian feature for overnight games

## Codex Round 2

### MVP Critique
- Kickoff Cascade: ship 2-state version (normal -> live pulse)
- Siren-to-Siren: must be notification + deep link (iOS limitation)
- Hype Rail + Gravitational Pull may be redundant - keep both but one strong live signal
- Missing: "What's Live Now" filter chip
- Missing: Stream health signal (loading/failing/backup)

### Top 5
1. Gravitational Pull feed
2. Sport DNA onboarding
3. No Spoilers toggle
4. Siren-to-Siren (notification version)
5. Same Time Detector

### New Feature: "Dead Stream Rescue"
Stream stalls/errors → instantly show ranked fallback channels for same match, one-tap switch

### Technical Risks
- Animation load: cap concurrent animated views
- Timer complexity: use shared scheduler, not per-cell timers
- Background limits: notifications + deep links only
- Spoiler safety: must block in widgets, VoiceOver, push notifications
- Data freshness: aggressive diffing to avoid re-render storms

---

## Gemini Round 2

### MVP Critique
- Needs "One-Tap to Stadium" mechanism
- Siren-to-Siren needs Live Activities/Dynamic Island
- Kickoff Cascade over-scoped

### Top 5
1. Siren-to-Siren (notification version)
2. No Spoilers Toggle
3. Hype Rail
4. Same Time Detector
5. Sport DNA Onboarding

### New Feature: "Clutch-Switch"
Uses EPG + live scores to detect high-leverage moments (final 5 min, close margin). Shows floating "Jump to Live" button to instantly swap streams.

### Cultural Insight: "Cross-Code Priority"
Aussies follow TEAMS across codes, not sports. A Richmond (AFL) + Storm (NRL) fan wants both in the same Hype Rail. Prioritize by Team, not by Sport Category.

---

## Claude Round 2

### CUT
- Kickoff Cascade: simplify to 2 states
- Siren-to-Siren: too fragile, needs backend

### PROMOTE
- Lock Screen Widget: "borderline criminal to leave out"
- Morning Catch-up: "if you don't nail the morning experience, you've missed the plot"

### Top 5
1. Sport DNA Onboarding + Morning Catch-up (merged)
2. Gravitational Pull Feed (simplified: 3 states - live/upcoming/finished)
3. Hype Rail
4. No Spoilers Toggle
5. Lock Screen Widget

### New Feature: "Timezone Ghost"
Every game shows two times: actual kickoff + relative ("in 4h 22m"). Plus lifestyle icon:
- Moon = overnight (11PM-6AM)
- Coffee = early morning (6-9AM)
- Sun = daytime
Solves "can I watch this live or catch up in the morning?" at a glance.

### First Launch Experience (5 screens, <90 seconds)
1. **Silent Stadium** - dark screen, subtle crowd noise, wordmark fade-in (2s)
2. **Pick Your Sports** - grid of sport icons, tap to light up in sport colors, micro-copy responses
3. **Pick Your Teams** - team badges with bounce haptic, golden ring on selected
4. **Timezone & Spoilers** - auto-detected TZ, two-card spoiler preference choice
5. **Your Home Screen** - team badges animate INTO the Hype Rail, feed assembles around them

### "Holy Shit" Moment
Team badges physically fly from selection grid into the Hype Rail. Feed populates instantly. 0.8 seconds. No loading spinner. "This is YOUR app now."

---

## FINAL MVP FEATURE LIST

| # | Feature | Complexity |
|---|---------|-----------|
| 1 | Sport DNA Onboarding | Medium |
| 2 | Gravitational Pull Feed | Medium |
| 3 | Hype Rail | Low |
| 4 | No Spoilers Toggle | Low |
| 5 | Morning Catch-up | Medium |
| 6 | Lock Screen Widget | Low-Medium |
| 7 | Kickoff Notification | Low |

## V2 Features
- Full Kickoff Cascade (6 stages)
- Same Time Detector → auto Multi-View
- Clutch-Switch (high-leverage moment alerts)
- Dead Stream Rescue (fallback channels)
- Timezone Ghost (lifestyle icons)
- Phantom Remote (swipe gestures)
- Pub Mode Audio (radio sync)
- Season Rings / Spotify Wrapped
- Event Takeover (Origin/Grand Final)
- Fan Pressure Heatmap
- Live Score Pip-in-Pip
