-- POST-PHASE-4 SPEC. Not part of the current test suite.
-- This file references AldorTaxFallUI / AldorTaxArrivalUI, which only
-- exist after Phase 4 of the UI reform (see TODO.md). On HEAD, only
-- AldorTaxSyncUI exists, so the assertions cannot run. When Phase 4
-- lands, delete the skip below and verify the assertions are still
-- meaningful against the new frames.
print("SKIP: tests/spec_post_phase4_ui_transitions.lua (post-Phase-4 spec)")
os.exit(0)

-- Characterization test for the UI state-leak bug during lift transitions.
--
-- Symptom (reported 2026-04-18): traveling Aldor Rise → Thunder Bluff →
-- Great Lift → Aldor Rise leaves the sync UI with a partially-stuck
-- background and segments outside the background fill.
--
-- Post Phase 4: fall lifts (Aldor) route to AldorTaxFallUI; dual/tram lifts
-- (TB, Great Lift, Deeprun) route to AldorTaxArrivalUI. The state-leak path
-- is broken by construction because the fall, arrival, and legacy sync
-- layouts now live in separate frames — but we still verify Aldor's fallUI
-- dimensions are stable across the round-trip, which is the externally-
-- visible signature of the bug.
--
-- Expected lifetime: DELETE when Phase 5 of the UI reform lands.
--
-- Run with: lua tests/test_ui_transitions.lua (from the addon root)

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H = require("test_harness")
local assert_eq, assert_true, section = H.assert_eq, H.assert_true, H.section

-- Pre-seed settings so TB + Great Lift are enabled (TB is off by default)
AldorTaxDB = {
    settings = {
        enableTBLift    = true,
        enableGreatLift = true,
        enableAldor     = true,
    },
}

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
MockAPI.SetZone("Shattrath City", "Aldor Rise")
MockAPI.SetMapPosition(0.4169, 0.3860)

dofile("AldorTax.lua")
MockAPI.InitAddon()

-- Helper: move to a zone and fire the event
local function goTo(zone, subzone, mapX, mapY)
    MockAPI.SetZone(zone, subzone)
    MockAPI.SetMapPosition(mapX, mapY)
    MockAPI.FireEvent("ZONE_CHANGED")
    MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")
end

local function activeUI()
    -- Fall lifts use AldorTaxFallUI; dual/tram lifts use AldorTaxArrivalUI;
    -- legacy segmented sync UI (AldorTaxSyncUI) is only used when the dev
    -- segmentInput override is on. Whichever is shown is the active one.
    local f = _G.AldorTaxFallUI
    local a = _G.AldorTaxArrivalUI
    local s = _G.AldorTaxSyncUI
    if f and f:IsShown() then return f, "fall"    end
    if a and a:IsShown() then return a, "arrival" end
    if s and s:IsShown() then return s, "sync"    end
    return nil, nil
end

local function snapshot()
    local ui, kind = activeUI()
    if not ui then return { kind = "none" } end
    local barBg = ui.barBg
    return {
        kind     = kind,
        w        = ui._w or 0,
        h        = ui._h or 0,
        visible  = ui:IsShown(),
        liftID   = ui.curLiftID,
        barBgW   = barBg and (barBg._w or 0) or 0,
    }
end

local function fmt(s)
    if s.kind == "none" then return "no UI shown" end
    return string.format("kind=%s liftID=%s panel=%dx%d barBg.w=%d visible=%s",
        s.kind, tostring(s.liftID), s.w, s.h, s.barBgW, tostring(s.visible))
end

-- ── Drive the reported sequence ─────────────────────────────────────────────

section("UI transition state-leak check")

-- Step 1: Aldor Rise (near → full mode). Routes to fallUI.
goTo("Shattrath City", "Aldor Rise", 0.4169, 0.3860)
local initial = snapshot()
print("  1. Aldor near:        " .. fmt(initial))
assert_eq(initial.kind,   "fall",  "Aldor routes to fall UI")
assert_eq(initial.liftID, "aldor", "initial lift is aldor")

-- Step 2: Terrace of Light (Aldor approach → light/compact mode). Still fallUI.
goTo("Shattrath City", "Terrace of Light", 0.5, 0.5)
local approach = snapshot()
print("  2. Aldor approach:    " .. fmt(approach))
assert_eq(approach.kind, "fall", "Aldor approach still on fall UI")

-- Step 3: Thunder Bluff (dual lift near → full). Routes to arrivalUI.
-- fallUI must hide; arrivalUI takes over.
goTo("Thunder Bluff", "Thunder Bluff", 0.318, 0.626)
local atTB = snapshot()
print("  3. TB near:           " .. fmt(atTB))
assert_eq(atTB.kind,   "arrival", "TB routes to arrival UI (dual lift)")
assert_eq(atTB.liftID, "tblift",  "tracked lift switched to tblift")
assert_true(not (_G.AldorTaxFallUI and _G.AldorTaxFallUI:IsShown()),
    "fall UI is hidden while arrival UI is active")

-- Step 4: Back to Aldor near. fallUI must reappear with stable layout.
goTo("Shattrath City", "Aldor Rise", 0.4169, 0.3860)
local final = snapshot()
print("  4. Aldor near (back): " .. fmt(final))
assert_eq(final.kind,   "fall",  "Aldor routes back to fall UI")
assert_eq(final.liftID, "aldor", "tracked lift returned to aldor")
assert_true(not (_G.AldorTaxArrivalUI and _G.AldorTaxArrivalUI:IsShown()),
    "arrival UI is hidden while fall UI is active")

-- ── The actual characterization assertion ───────────────────────────────────
--
-- After the round-trip, fallUI dimensions must match initial-Aldor. Pre-Phase-3
-- this failed because Aldor and TB shared one frame and TB's compact barBg
-- leaked back into Aldor's full layout.

assert_eq(final.w,      initial.w,      "Aldor frame width is stable across round-trip")
assert_eq(final.h,      initial.h,      "Aldor frame height is stable across round-trip")
assert_eq(final.barBgW, initial.barBgW, "Aldor barBg width is stable across round-trip")

H.results()
