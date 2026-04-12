# AldorTax — Deferred & In-Progress

## Bugs

### Channel 1 still occasionally taken by AldorTaxSync
- The channel join logic that waits for General before joining was added in e4d2050/973a86e
- Still occasionally registers as channel #1, displacing General
- Root cause: the "wait for General" guard checks if *any* channel exists, but doesn't guarantee General is actually #1 yet
- Consider: join on first sync send instead of at load, or explicitly target a high channel number (e.g. 10+)
- Related: some users may not have General at all — need a fallback path

### Dev panel: switching between segmentation UI and calibration/compact UI requires reload
- Currently the panel type is set once at creation; toggling the checkbox doesn't rebuild
- Should dynamically switch without /reload
- The devpanel and testmsg slash commands should be removed from /atax and replaced with a single "Enable dev UI" checkbox in options that shows the dev panel + includes test tools inline

### Dev timer overlay (stopclock) is redundant
- WoW has a built-in stopwatch (`/stopwatch`); remove the custom devTimerFrame overlay entirely

## Transport Animation Data

### Match measured segments to TransportAnimation.csv definitions
- Six TransportIDs (176080–176085) correspond to the Deeprun Tram's three carts on two lines
- The CSV contains position keyframes (Y = track distance, Z = depth/elevation) with TimeIndex in milliseconds
- TID 176080 cycle: departs at t=0, arrives far end ~58.6s, dwells until ~71.7s, returns, arrives back ~130.3s, dwells until ~143.3s → **143.333s total cycle**
- This confirms the 143s hypothesis and gives exact segment boundaries
- Need a way to map measured in-game segments to the animation keyframes for validation
- Potential: use Z (depth) profile to show tunnel cross-section in a tram-specific UI

### Tram UI redesign
- Current bar UI doesn't convey the tram's nature well
- Consider a cross-section view showing three carts per line, with depth profile from Z data
- Show per-cart arrival timers — useful for "when does the next cart arrive at my platform?"
- The six TIDs have staggered start offsets (0, 433, 867ms between carts on same line)

## Calibration

### SSC Lift
- Cycle = 43.5s (confirmed via full-span same-phase analysis)
- Segments: fall=17, waitAtBottom=5, rise=13, waitAtTop=8.5
- epochOffset not yet converged — needs more in-game testing with corrected cycle time
- Zone/subzone names need in-game confirmation (`GetZoneText()` / `GetSubZoneText()` inside SSC)
- SSC lifts appear epoch-bound server-side (same cycle across instance IDs) — needs one more confirmation
- SSC branch exists separately; don't merge to main until SSC drops on anniversary

### Thunder Bluff Lift
- All timings copied from Great Lift — completely uncalibrated
- dualOffset (8.0) is a guess; user reported TB lift was "completely disorienting to use"
- Need in-game calibration session

### Deeprun Tram
- Animation data confirms: 58.633s transit, 13.033s dwell at far end, 143.333s cycle
- Three carts per line, staggered ~433ms apart
- epochOffset unknown — needs in-game calibration

### Aldor Rise
- epochOffset constant is 20.0 but server-time measurements consistently show ~14.1–14.7
- Timings are well calibrated otherwise

### Stormspire Lift (new, uncalibrated)
- Added to LIFTS table but all timings are placeholder copies from Aldor
- Needs in-game measurement of all segments and epoch

## Sync / Networking

### Sender latency in sync message
- Currently only receiver's world latency is used for compensation
- Adding sender's world latency to v6 message would allow: `(sender_world + receiver_world) / 2`
- Would halve the latency asymmetry error (~±50ms → ~±25ms)

### Rank-gated sync updates
- No priority system yet: any incoming sync overwrites the current one
- Desired: manual click > remote calibrated sync > remote relayed sync > saved sync

### Wednesday reset detection
- Server restarts shift the epoch — saved syncs become stale
- No automatic detection or invalidation yet

### Blocklist persistence
- Untested — deferred until there are enough users to interact with

## Features

### Fall-save alert (implemented, needs testing)
- IsFalling() detection + class-specific SecureActionButton
- Covers all classes with relevant abilities + Noggenfogger as fallback
- Needs in-game testing across classes; reagent checks for pre-Cata

### Passive sync (research)
- Could detect transport parenting via UNIT_FLAGS or similar for automatic calibration
- Research only, not started

## Housekeeping

### Credit Muerto in README
- Helped test channel sync functionality

### CurseForge retail tagging
- v0.4.0 shows as newest on retail because it was tagged retail
- No files should be tagged retail; fix on next CurseForge upload

## Done (v0.7.2)

- ~~ChatThrottleLib integration~~ — ALERT priority, fallback to raw C_ChatInfo
- ~~GetServerTime() tick-boundary calibration~~ — sub-frame (~16ms) precision
- ~~Network latency compensation~~ — receiver subtracts own world latency on sync receive
- ~~Per-lift enable/disable settings~~ — individual checkboxes in Interface Options
- ~~5s zone send cooldown~~ — prevents sends right after zoning
- ~~Click-sync refactored~~ — PerformCalibrationClick shared helper
- ~~Test suite~~ — 29 tests covering sync pipeline, CTL, cooldown, blocklist, multi-lift isolation
- ~~Channel guard: wait for General before joining~~ — e4d2050 (still has issues, see bugs)
