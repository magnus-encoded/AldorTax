# Aldor Tax

**Aldor Tax** is a lightweight World of Warcraft: TBC Classic Anniversary addon that tracks the Aldor Rise elevator cycle in Shattrath City, warns you before it departs, and shares timing data automatically with nearby players.

## Features

- **Departure warnings** — blinking red alert when the elevator is about to leave the top, orange warning when approaching and the lift is leaving soon
- **Progress bar UI** — colour-coded bar showing the current phase of the elevator cycle (FALL / BOTTOM / RISE / TOP) with a live cursor and countdown
- **Click-to-calibrate** — click each segment of the bar as that phase begins to measure exact timings; FALL and RISE are tracked independently since they differ
- **Player sync** — calibration data is broadcast automatically every 45 seconds while you are in Shattrath, and once more as you leave, so other players running the addon stay in sync without needing to be on the lift
- **Sync attribution** — the UI shows whether the current timer is local or received from another player
- **Death detection** — dying in Shattrath auto-reports the sync source and clears your timer; repeated deaths from the same source auto-block that player
- **Layer detection** — detects your server layer from NPC GUIDs and logs cross-layer timing divergence
- **Say countdown** — optional /say announcements on Aldor Rise before the lift departs ("leaving in 2", "leaving in 1", "falling")
- **Settings panel** — Interface > AddOns > AldorTax with checkboxes for sync channels and say countdown
- **Copyable log** — all calibration and sync events are written to a panel you can select and copy
- **Persistent** — calibrated timings and last-known sync point are saved across sessions

## How It Works

The elevator runs on a fixed repeating cycle: it falls to the bottom, waits, rises to the top, waits, then repeats. The default segment durations are approximately:

| Segment | Duration |
|---------|----------|
| FALL    | 7.25 s   |
| BOTTOM  | 5.00 s   |
| RISE    | 7.25 s   |
| TOP     | 5.00 s   |

Click each segment on the progress bar as it starts to calibrate the exact timings for your realm. The more players calibrate and sync, the more accurate the shared timer becomes.

## Usage

1. Travel to Shattrath City (not Aldor Rise) — the sync UI appears automatically
2. Click each segment of the progress bar as that phase begins to calibrate
3. The timer is broadcast to other players in the zone automatically
4. A warning appears at the top of your screen when the elevator is about to depart

## Commands

| Command | Description |
|---------|-------------|
| `/atax ui` | Toggle the sync / calibration panel |
| `/atax sync` | Manually record a departure and broadcast |
| `/atax reset` | Clear the current timer |
| `/atax config` | Open the settings panel |
| `/atax log` | Toggle the copyable log panel |
| `/atax debug` | Toggle the debug info panel |
| `/atax testmsg` | Whisper yourself to verify addon messaging works |
| `/atax unblock Name-Realm` | Remove a player from the blocklist |

## Installation

1. Copy the `AldorTax` folder into your World of Warcraft AddOns directory:
   `World of Warcraft\_anniversary_\Interface\AddOns\`
2. Reload your UI (`/reload`) if the game is already running.

## Notes

- Requires **TBC Classic Anniversary** (interface version 20504)
- Sync messages use the `ALDORTAX` addon message prefix over group, raid, or the `AldorTaxSync` custom channel
