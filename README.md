# Aldor Tax

**Aldor Tax** is a lightweight World of Warcraft: TBC Classic Anniversary addon that tracks the Aldor Rise elevator cycle in Shattrath City, warns you before it departs, and shares timing data automatically with nearby players.

## Features

- **Departure warnings** — blinking red alert when the elevator is about to leave the top, orange warning when approaching and the lift is leaving soon
- **Progress bar UI** — colour-coded bar showing the current phase of the elevator cycle (FALL / BOTTOM / RISE / TOP) with a live cursor and countdown
- **Click-to-sync** — click any segment of the bar as that phase begins to sync the timer to the live elevator; a 200ms reaction-time offset is applied automatically
- **Player sync** — timing data is broadcast automatically every 45 seconds while you are in Shattrath, and once more as you leave, so other players running the addon stay in sync without needing to be on the lift
- **Sync attribution** — the UI shows whether the current timer is local or received from another player
- **Say Warning button** — click to announce the lift departure countdown in /say so nearby players without the addon can benefit; works outdoors because button clicks are hardware events
- **Proximity-aware UI** — full panel with labels and buttons when near the lift, compact progress-bar-only mode when elsewhere in Shattrath
- **Death detection** — dying in Shattrath auto-reports the sync source and clears your timer; repeated deaths from the same source auto-block that player
- **Settings panel** — Interface > AddOns > AldorTax with checkboxes for sync channels
- **Copyable log** — all sync events are written to a panel you can select and copy
- **Persistent** — last-known sync point is saved across sessions

## How It Works

The elevator runs on a fixed 25-second repeating cycle: it falls to the bottom, waits, rises to the top, waits, then repeats. The segment durations are:

| Segment | Duration |
|---------|----------|
| FALL    | 6.5 s    |
| BOTTOM  | 5.0 s    |
| RISE    | 7.5 s    |
| TOP     | 6.0 s    |

Click any segment on the progress bar as that phase begins to sync the addon's timer to the live elevator cycle. A 200ms human reaction-time offset is subtracted automatically so the sync lands closer to the true transition.

## Usage

1. Travel to Shattrath City — the sync UI appears automatically
2. Click a segment on the progress bar as that phase begins to sync the timer
3. The timer is broadcast to other players in the zone automatically
4. A warning appears at the top of your screen when the elevator is about to depart

## Commands

| Command | Description |
|---------|-------------|
| `/atax ui` | Toggle the sync panel |
| `/atax sync` | Manually record a departure and broadcast |
| `/atax reset` | Clear the current timer |
| `/atax config` | Open the settings panel |
| `/atax log` | Toggle the copyable log panel |
| `/atax testmsg` | Whisper yourself to verify addon messaging works |
| `/atax unblock Name-Realm` | Remove a player from the blocklist |

## Installation

1. Copy the `AldorTax` folder into your World of Warcraft AddOns directory:
   `World of Warcraft\_anniversary_\Interface\AddOns\`
2. Reload your UI (`/reload`) if the game is already running.

## Notes

- Requires **TBC Classic Anniversary** (interface version 20504)
- Sync messages use the `ALDORTAX` addon message prefix over party/raid, guild, or the `AldorTaxSync` custom channel
- Automated /say countdown from timers is impossible (Blizzard blocks `SendChatMessage("SAY")` from software events outdoors since patch 8.2.5), but the Say Warning button works because button clicks count as hardware events
