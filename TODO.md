# AldorTax — Deferred & In-Progress

## Calibration

### SSC Lift
- Cycle = 43.5s (confirmed via full-span same-phase analysis: TOP 1214s/28=43.36, BOTTOM 1170/27=43.33, FALL 1128/26=43.38 — 43.5 chosen as clean design number)
- Segments: fall=17, waitAtBottom=5, rise=13, waitAtTop=8.5 (corrected from earlier estimates)
- epochOffset not yet converged — needs more in-game testing with corrected cycle time
- Zone/subzone names need in-game confirmation (`GetZoneText()` / `GetSubZoneText()` inside SSC)
- SSC lifts appear epoch-bound server-side (same cycle across instance IDs Fizzideath/Fizziness) — needs one more confirmation with calibration clicks from both IDs
- Do tests done in MoP hold for TBC?

### Thunder Bluff Lift
- All timings copied from Great Lift — completely uncalibrated
- dualOffset (8.0) is a guess

### Deeprun Tram
- Timing hypothesis: 58.5s transit (symmetric), 13s dwell, 143s cycle — needs more in-game verification

### Aldor Rise
- epochOffset constant is 20.0 but server-time measurements consistently show ~14.1–14.7
- Timings are well calibrated otherwise

## Sync / Networking

### Sender latency in sync message
- Currently only receiver's world latency is used for compensation
- Adding sender's world latency to v6 message would allow computing actual one-way transit: `(sender_world + receiver_world) / 2`
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

### Passive sync (research)
- Could detect transport parenting via UNIT_FLAGS or similar for automatic calibration
- Research only, not started

## Housekeeping

### Credit Muerto in README
- Helped test channel sync functionality

## Done (v0.7.0)

- ~~ChatThrottleLib integration~~ — ALERT priority, fallback to raw C_ChatInfo
- ~~GetServerTime() tick-boundary calibration~~ — sub-frame (~16ms) precision instead of ~1s
- ~~Network latency compensation~~ — receiver subtracts own world latency on sync receive
- ~~Per-lift enable/disable settings~~ — individual checkboxes in Interface Options
- ~~5s zone send cooldown~~ — prevents sends right after zoning (server rate-limiter)
- ~~Click-sync refactored~~ — PerformCalibrationClick shared helper eliminates 4x duplication
- ~~Test suite~~ — 29 tests covering sync pipeline, CTL, cooldown, blocklist, multi-lift isolation
