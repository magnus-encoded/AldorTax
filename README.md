# AldorTax

Transport timing addon for WoW Classic Anniversary. Tracks lift and tram cycles so you don't fall off the Aldor Rise or miss the Deeprun Tram.

## Supported Transports

- **Aldor Rise** (Shattrath City) -- 25.0s cycle
- **The Great Lift** (Thousand Needles / The Barrens) -- 29.8s cycle
- **Deeprun Tram** (IF-SW, beta) -- 143.0s cycle

The Great Lift is disabled on clients where it no longer exists (Cataclysm+).

## How It Works

Click a phase segment on the tracking bar when you see the transport reach that point. A 200ms reaction offset is applied automatically. Your sync is broadcast to nearby players via the AldorTaxSync channel and party/raid.

The UI switches between a full panel (when near the transport) and a compact view (when approaching).

## Slash Commands

| Command | Action |
|---------|--------|
| `/atax config` | Open settings |
| `/atax ui` | Toggle the sync panel |
| `/atax log` | Show/hide the diagnostic log |

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/aldor-tax).
2. Extract `AldorTax` to `Interface\AddOns\`.
3. `/reload`

## Thank You

Thanks to the [Operasjon Firkl0ver](https://o4k.no/) gaming community for testing, and to Sørlin for the window position persistence idea.

Developed by Fizziness.
