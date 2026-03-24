# Aldor Tax

**Aldor Tax** is a lightweight World of Warcraft: TBC Classic Anniversary addon that tracks elevator cycles, warns you before departure, and shares timing data automatically with nearby players.

## Supported Elevators

| Elevator | Zone | Cycle |
|----------|------|-------|
| **Aldor Rise** | Shattrath City | 25 s |
| **Great Lift** | Barrens / Thousand Needles | 30 s |
| **Deeprun Tram** | Deeprun Tram (Experimental) | 143 s |

The UI appears automatically when you enter one of these zones. Deeprun Tram support must be enabled in the Interface options.

## Features

- **Departure warnings** — blinking red alert when the elevator is about to leave the top, orange warning when approaching and the lift is leaving soon
- **Progress bar UI** — colour-coded bar showing the current phase of the elevator cycle (FALL / BOTTOM / RISE / TOP) with a live cursor and countdown
- **Dual-lift/Tram display** — the Great Lift has two complementary platforms; the Deeprun Tram has two trams. The UI shows two bars tracking each.
- **Horizontal & Vertical layouts** — the UI adapts to show vertical bars for elevators and horizontal tracks for the tram.
- **Orientation guides** — the Deeprun Tram UI includes "North/South" track labels and entrance portal icons to help you find the next departing tram.
- **Click-to-sync** — click any segment of the bar as that phase begins to sync the timer to the live elevator; a 200ms reaction-time offset is applied automatically
- **Player sync** — timing data is broadcast automatically every 45 seconds while you are near a tracked lift, and once more as you leave, so other players running the addon stay in sync
- **Sync attribution** — the UI shows whether the current timer is local or received from another player
- **Say Warning button** — click to announce the lift departure countdown in /say so nearby players without the addon can benefit; works outdoors because button clicks are hardware events
- **Proximity-aware UI** — full panel with labels and buttons when near the lift, compact mode when elsewhere in the zone
- **Death detection** — dying near a tracked lift auto-reports the sync source and clears your timer; repeated deaths from the same source auto-block that player
- **Settings panel** — Interface > AddOns > AldorTax with checkboxes for sync channels and behaviour
- **Copyable log** — all sync events are written to a panel you can select and copy
- **Persistent** — last-known sync point is saved per lift across sessions

## Elevator Timings

### Aldor Rise (Shattrath City)

| Segment | Duration |
|---------|----------|
| FALL    | 6.5 s    |
| BOTTOM  | 5.0 s    |
| RISE    | 7.5 s    |
| TOP     | 6.0 s    |

### Great Lift (Barrens / Thousand Needles)

| Segment | Duration |
|---------|----------|
| FALL    | 11.0 s   |
| BOTTOM  | 4.0 s    |
| RISE    | 11.0 s   |
| TOP     | 4.0 s    |

The Great Lift has two platforms running on complementary cycles — when one is at the top, the other is at the bottom.

### Deeprun Tram (Experimental)

| Segment | Duration |
|---------|----------|
| IF -> SW | 59.0 s   |
| AT SW    | 13.0 s   |
| SW -> IF | 58.0 s   |
| AT IF    | 13.0 s   |

The Deeprun Tram uses a 143-second cycle with two trams offset by half a cycle. Support for the tram is currently experimental and disabled by default. Enable it in the AldorTax settings panel.

## Usage

1. Travel to a zone with a tracked elevator — the sync UI appears automatically
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
