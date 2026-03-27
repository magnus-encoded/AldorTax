# Aldor Tax (v0.4.3)

**Aldor Tax** is a high-precision transport tracking and synchronization addon for **World of Warcraft: TBC Classic Anniversary**. It eliminates the "Elevator Boss" by providing real-time, shared timers for lifts and trams, ensuring you never miss a departure or fall to your death.

---

## 🚀 Key Features

- **🎯 High-Precision Tracking:** Automated tracking for elevators and trams with sub-second accuracy.
- **📡 P2P Synchronization:** Automatically shares timing data with other players in the zone via addon messaging.
- **🚥 Multi-Phase UI:** Color-coded bars track every stage of the cycle (FALL / BOTTOM / RISE / TOP).
- **🚇 Deeprun Tram Support (BETA):** specialized horizontal tracking for the North/South tram lines, including orientation guides and track labels.
- **⚠️ Smart Warnings:** Visual screen alerts blink when a transport is about to depart or arrive.
- **📱 Proximity-Aware UI:** Automatically switches between a full control panel (when near) and a minimalist compact view (when approaching).
- **🗣️ Hardware-Event Reporting:** A "Report Position" button that bypasses Blizzard's `/say` restrictions, allowing you to announce timings to nearby players without the addon.

---

## 🗺️ Supported Transports

| Transport | Zone | Cycle Time |
|-----------|------|------------|
| **Aldor Rise** | Shattrath City | 25.0s |
| **The Great Lift** | Thousand Needles | 30.0s |
| **Deeprun Tram** | Deeprun Tram (Instance) | 143.0s |

*Note: The Great Lift is dynamically disabled on Cataclysm/MoP/Retail clients as the structure was destroyed in the lore.*

---

## 🛠️ How It Works

### The Sync Cycle
Aldor Tax calibrates your local game time against the server's time. When you see a transport begin a phase (e.g., it starts to fall), you click the corresponding segment on the bar. 
- **Reaction Offset:** A 200ms offset is applied to account for human reaction time.
- **Broadcast:** Your sync is immediately shared with all players in the `AldorTaxSync` channel and your party/raid.

### Deeprun Tram Orientation
The tram UI is designed for spatial awareness:
- **Bottom Bar (hbar1):** The **North Track** (closer to the instance entrance/exit portals).
- **Top Bar (hbar2):** The **South Track**.
- **Portal Icons:** Visual anchors for Ironforge (Blue) and Stormwind (Orange) to help you find the correct platform.

---

## ⌨️ Slash Commands

| Command | Action |
|---------|--------|
| `/atax config` | Open the options and experimental settings. |
| `/atax ui` | Toggle the visibility of the sync panel. |
| `/atax log` | Show/hide the copyable diagnostic log. |
| `/atax where` | **(Dev Only)** Dump NPC and coordinate data for station detection. |
| `/atax testmsg` | Send a test whisper to yourself to verify addon messaging. |
| `/atax unblock [Name-Realm]` | Remove a player from the automatic death-report blocklist. |

---

## 📦 Installation

1. Download the latest release.
2. Extract the `AldorTax` folder to:
   `World of Warcraft\_anniversary_\Interface\AddOns\`
3. Ensure the folder is named exactly `AldorTax`.
4. Restart or reload (`/reload`) your game.

---

## 🛡️ Reliability & Security

- **Death Detection:** If a player reports a sync that leads to multiple deaths, the addon automatically blocks that player to prevent griefing.
- **Lightweight:** Minimal memory footprint and throttled proximity checks (1.0s) ensure zero impact on game performance.
- **Safe Messaging:** Does not use hidden chat channels that interfere with normal gameplay.

---

## 📝 Feedback & Contributions

Aldor Tax is an evolving project. If you have suggestions or timing corrections, please visit our [CurseForge Page](https://www.curseforge.com/wow/addons/aldor-tax).

*Developed by Fizziness & The Gemini Team.*
