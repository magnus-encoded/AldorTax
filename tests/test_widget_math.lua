-- Widget-math tests for the pure functions Step 5 will lean on:
--   TransportCycle.SegmentLayout
--   TransportCycle.SecondsToNextBoundary
--   WidgetRouter.DispatchWidget
--
-- These are *salvaged* algorithms from the LiftBar / LightCountdown
-- working-tree drafts, rewritten against the current LIFTS data model
-- (flat fallTime/waitAtBottom/riseTime/waitAtTop) via TransportCycle.
-- The drafts themselves remain untracked; UI integration is Step 5b.
--
-- Run from addon root: lua tests/test_widget_math.lua

package.path  = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H       = require("test_harness")

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
AldorTaxDB = nil

local NS = H.LoadAddon()
MockAPI.InitAddon()

local TC             = NS.TransportCycle
local DispatchWidget = NS.DispatchWidget
local TransportForm  = NS.TransportForm
local LIFTS          = NS.LIFTS

-- ─── SegmentLayout ────────────────────────────────────────────────────────────

H.section("SegmentLayout — aldor (460px bar)")
do
    local def   = LIFTS.aldor
    local rects = TC.SegmentLayout(460, def)

    H.assert_eq(#rects, 4,         "returns 4 rects")
    H.assert_eq(rects[1].x, 0,     "first rect x=0")

    for i = 2, 4 do
        H.assert_eq(rects[i].x, rects[i-1].x + rects[i-1].w,
            "rect " .. i .. " is adjacent to rect " .. (i-1))
    end

    H.assert_eq(rects[4].x + rects[4].w, 460, "total width = 460 (exact)")

    -- Widths proportional to durations (within 1px rounding).
    local durations = TC.SegmentDurations(def)
    for i = 1, 4 do
        local expected = durations[i] / def.cycleTime * 460
        H.assert_near(rects[i].w, expected, 1.0,
            "width[" .. i .. "] proportional to duration")
    end
end

H.section("SegmentLayout — 1px degenerate bar")
do
    local rects = TC.SegmentLayout(1, LIFTS.aldor)
    H.assert_eq(#rects, 4, "still returns 4 rects")
    H.assert_eq(rects[1].x, 0, "first x=0")
    H.assert_eq(rects[4].x + rects[4].w, 1, "last rect ends at 1")

    local total = 0
    for _, r in ipairs(rects) do total = total + r.w end
    H.assert_eq(total, 1, "total width = 1 (some rects may have w=0)")
end

H.section("SegmentLayout — Deeprun Tram (460px bar, symmetric)")
do
    local rects = TC.SegmentLayout(460, LIFTS.deepruntram)
    H.assert_eq(rects[1].x, 0,                     "first rect x=0")
    H.assert_eq(rects[4].x + rects[4].w, 460,      "total = 460")
    -- fallTime == riseTime (58.633s each) on tram → widths match.
    H.assert_eq(rects[1].w, rects[3].w,            "TO-SW and TO-IF widths equal")
end

-- ─── SecondsToNextBoundary ────────────────────────────────────────────────────

H.section("SecondsToNextBoundary — aldor")
do
    local def = LIFTS.aldor
    -- starts: { 0, 6.933, 11.233, 19.300 }, cycle 25
    H.assert_near(TC.SecondsToNextBoundary(def, 0.0),    6.933, 0.001,
        "phase=0 → next is BOTTOM start (6.933)")
    H.assert_near(TC.SecondsToNextBoundary(def, 3.0),    3.933, 0.001,
        "mid-FALL → 3.933s to BOTTOM")
    H.assert_near(TC.SecondsToNextBoundary(def, 6.933),  4.300, 0.001,
        "on BOTTOM boundary → next boundary is RISE in 4.300s")
    H.assert_near(TC.SecondsToNextBoundary(def, 24.5),   0.500, 0.001,
        "near cycle end → 0.5s wraps to FALL start")
end

H.section("SecondsToNextBoundary — Deeprun Tram")
do
    local def = LIFTS.deepruntram
    -- starts: { 0, 58.633, 71.667, 130.300 }, cycle 143.333
    H.assert_near(TC.SecondsToNextBoundary(def, 0.0),    58.633, 0.001,
        "tram phase=0 → 58.633s to AT-SW")
    H.assert_near(TC.SecondsToNextBoundary(def, 130.3),  13.033, 0.001,
        "tram on AT-IF start → 13.033s to TO-SW (wrap)")
end

-- ─── DispatchWidget ───────────────────────────────────────────────────────────

H.section("DispatchWidget — 9-cell decision table")
do
    H.assert_eq(DispatchWidget("single",     "on_platform"),  "LiftBar",        "single+on_platform")
    H.assert_eq(DispatchWidget("single",     "approaching"),  "LiftBar",        "single+approaching")
    H.assert_eq(DispatchWidget("single",     "other"),        "LightCountdown", "single+other")
    H.assert_eq(DispatchWidget("dual",       "on_platform"),  "DualLiftBar",    "dual+on_platform")
    H.assert_eq(DispatchWidget("dual",       "approaching"),  "DualLiftBar",    "dual+approaching")
    H.assert_eq(DispatchWidget("dual",       "other"),        "LightCountdown", "dual+other")
    H.assert_eq(DispatchWidget("horizontal", "on_platform"),  "TramUI",         "horizontal+on_platform")
    H.assert_eq(DispatchWidget("horizontal", "approaching"),  "TramUI",         "horizontal+approaching")
    H.assert_eq(DispatchWidget("horizontal", "other"),        "LightCountdown", "horizontal+other")
end

H.section("DispatchWidget — fallbacks")
do
    H.assert_eq(DispatchWidget("single", nil),       "LightCountdown", "nil proximity → LightCountdown")
    H.assert_eq(DispatchWidget("single", "unknown"), "LightCountdown", "unknown proximity → LightCountdown")
    H.assert_eq(DispatchWidget(nil, "on_platform"),  "LiftBar",        "nil form defaults to single")
    H.assert_eq(DispatchWidget(nil, "other"),        "LightCountdown", "nil form + other")
    H.assert_eq(DispatchWidget("zeppelin", "other"), "LightCountdown",
        "unknown form defaults to single, then 'other' → LightCountdown")
end

-- ─── TransportForm (def → form) ───────────────────────────────────────────────

H.section("TransportForm — single platform")
do
    H.assert_eq(TransportForm(LIFTS.aldor), "single", "aldor (no flags) → single")
end

H.section("TransportForm — dual platform")
do
    H.assert_eq(TransportForm(LIFTS.greatlift), "dual", "greatlift (dualLift) → dual")
end

H.section("TransportForm — horizontal wins over dualLift")
do
    -- Deeprun Tram carries BOTH horizontal and dualLift; horizontal must win.
    H.assert_eq(TransportForm(LIFTS.deepruntram), "horizontal", "deepruntram (horizontal+dualLift) → horizontal")
end

H.section("TransportForm — nil def degrades safely")
do
    -- OnUpdate may call this with no active def; must not throw.
    H.assert_eq(TransportForm(nil), "single", "nil def → single (composes with DispatchWidget nil default)")
end

H.results()
