# AldorTax Testing Checklist

Manual in-game verification for each feature. Mark items `[x]` as you test.

## Options Panel

- [ ] Panel appears under Interface > AddOns > AldorTax on login
- [ ] `/atax config` opens the options panel directly
- [ ] "Party / Raid" checkbox toggles `syncParty` setting
- [ ] "AldorTaxSync channel" checkbox toggles `syncChannel` setting
- [ ] "Guild" checkbox toggles `syncGuild` setting
- [ ] "Announce departure in /say" checkbox toggles `sayCountdown` setting
- [ ] Checkbox states persist across `/reload`
- [ ] Checkbox states persist across full logout/login

## Sync UI

- [ ] UI appears automatically when entering Shattrath City (not Aldor Rise)
- [ ] UI hides automatically when leaving Shattrath City
- [ ] UI hides automatically when entering Aldor Rise subzone
- [ ] `/atax ui` toggles the sync panel manually
- [ ] White cursor tracks current cycle position when synced
- [ ] Cursor parks off-screen when no sync is active
- [ ] Source label shows "local" after a manual calibration click
- [ ] Source label shows "received from PlayerName" after a remote sync
- [ ] Source label shows "no sync" when timer is cleared
- [ ] Time-remaining label updates above the cursor
- [ ] Panel is draggable via left-click drag
- [ ] "I Died" button clears sync and broadcasts death report

## Calibration

- [ ] Clicking a segment sets a local sync reference (cursor jumps to that phase)
- [ ] Clicking consecutive segments (e.g. FALL then BOTTOM) calibrates the previous segment duration
- [ ] Re-clicking the same segment resets reference without calibrating
- [ ] Per-segment bounds validation rejects values outside allowed ranges (FALL/RISE: 3-15s, BOTTOM/TOP: 2-12s)
- [ ] Cycle total validation rejects calibrations that would put total outside 22.5-26.5s
- [ ] Calibrated FALL, RISE, BOTTOM, TOP durations persist to `AldorTaxDB` across `/reload`
- [ ] Calibrated durations persist across full logout/login
- [ ] Out-of-bounds saved calibration is discarded on load with a log message
- [ ] Legacy symmetric `cycleTime` saved variable is correctly split on upgrade

## Say Countdown

- [ ] With `sayCountdown` enabled and on Aldor Rise / Terrace of Light:
  - [ ] "AldorTax: leaving in 2" fires in /say at ~2s before departure
  - [ ] "AldorTax: leaving in 1" fires in /say at ~1s before departure
  - [ ] "AldorTax: falling" fires in /say when the fall phase begins
- [ ] Each message fires only once per departure cycle (no duplicates)
- [ ] Messages do not fire when `sayCountdown` is disabled
- [ ] Messages do not fire outside Aldor Rise / Terrace of Light

## Sync Broadcast

- [ ] Auto-broadcasts every 45 seconds while in Shattrath with a valid sync
- [ ] Auto-broadcast only fires when at least one send channel is available
- [ ] One final broadcast fires when leaving Shattrath
- [ ] Broadcasts go to party/raid when `syncParty` is enabled and in a group
- [ ] Broadcasts go to AldorTaxSync channel when `syncChannel` is enabled and channel joined
- [ ] Broadcasts go to guild when `syncGuild` is enabled
- [ ] `/atax sync` manually records a departure and broadcasts
- [ ] Self-broadcasts are ignored (no echo loop) except for test messages
- [ ] Received sync from another player updates local timer and source label
- [ ] Received sync includes sender's calibration data (fall/bottom/rise/top)

## Death Detection

- [ ] Dying in Shattrath City clears local sync (`lastSync = 0`)
- [ ] Dying in Shattrath broadcasts a death report (`D|` message)
- [ ] Death report only broadcasts if sync came from a remote source (not local)
- [ ] Receiving 3 death reports about a player soft-blocks their syncs
- [ ] Receiving 6 death reports about a player hard-blocks them permanently
- [ ] Soft-blocked sync source is logged but ignored
- [ ] Hard-blocked sync source is silently ignored
- [ ] Active sync from a newly soft-blocked source is invalidated immediately
- [ ] `/atax unblock Name-Realm` removes a player from the blocklist

## Layer Detection

- [ ] Targeting an NPC in Shattrath detects layer from creature GUID zoneID field
- [ ] Layer ID is logged when first detected or when it changes
- [ ] Cross-layer sync from a player on a different layer logs timing divergence
- [ ] Cross-layer sync with matching timings logs "timings match" message
- [ ] Cross-layer sync without local calibration logs "no local calibration to compare"
- [ ] Layer ID is included in outgoing sync broadcasts (v2 format)

## Slash Commands

- [ ] `/atax` (no args) prints the help/usage list
- [ ] `/aldortax` also works as an alias
- [ ] `/atax sync` records departure and broadcasts
- [ ] `/atax reset` clears the timer and hides warnings
- [ ] `/atax log` toggles the copyable log panel
- [ ] `/atax ui` toggles the sync/calibration panel
- [ ] `/atax config` opens the Interface Options panel
- [ ] `/atax debug` toggles the debug info panel
- [ ] `/atax testmsg` whispers yourself and confirms addon messaging works
- [ ] `/atax unblock Name-Realm` removes a player from the blocklist

## Warning Display

- [ ] Blinking red "!!! LEAVING IN: X.Xs !!!" shows on Aldor Rise when lift departs within TOP wait time
- [ ] Orange "LIFT LEAVING IN: X.Xs!" shows when approaching and within 10s of departure
- [ ] Warnings hide when sync UI is visible (no double display)
- [ ] Warnings hide when timer is reset

## Addon Messaging

- [ ] Addon prefix "ALDORTAX" registers successfully on load
- [ ] AldorTaxSync custom channel is joined on load
- [ ] Channel join retries up to 3 times if initial join fails
- [ ] `/atax testmsg` sends and receives a test whisper to self
- [ ] Messages with unknown/future version numbers are ignored with a log entry
- [ ] v2 message format: `S|ver|phase|name|realm|fall|bottom|rise|top|layerID`

## Persistence

- [ ] `AldorTaxDB` saved variable is initialized on first load
- [ ] Blocklist persists across sessions
- [ ] Settings persist across sessions
- [ ] Calibration data persists across sessions
- [ ] Last sync real-time reference persists and restores timer on reload
- [ ] Sync source attribution is NOT restored across reloads (intentional)
