-- Widget data-access tests for Step 5b-1: the three widget modules
-- (LiftBar / LightCountdown / TramUI) need to read from the live
-- NS.LIFTS model — flat-field defs + segColors — not the imagined
-- def.segments shape from the original drafts. These tests pin the
-- pure surface against real LIFTS defs.
--
-- Run from addon root: lua tests/test_widget_data_access.lua

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H       = require("test_harness")

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
AldorTaxDB = nil

local NS = H.LoadAddon()
MockAPI.InitAddon()

local TC    = NS.TransportCycle
local LIFTS = NS.LIFTS

-- ─── Module presence ──────────────────────────────────────────────────────────

H.section("Widget modules loaded into NS")
do
    H.assert_true(NS.LiftBar         ~= nil, "NS.LiftBar exists")
    H.assert_true(NS.LightCountdown  ~= nil, "NS.LightCountdown exists")
    H.assert_true(NS.TramUI          ~= nil, "NS.TramUI exists")
    H.assert_true(NS.DualLiftBar     ~= nil, "NS.DualLiftBar exists")
end

-- ─── DualLiftBar.SecondaryPhase (exposed for test) ────────────────────────────

H.section("DualLiftBar.SecondaryPhase — greatlift (half-cycle default)")
do
    local def = LIFTS.greatlift  -- cycleTime 30, no dualOffset → offset = 15
    H.assert_near(NS.DualLiftBar.SecondaryPhase(def, 0.0),  15.0, 0.001, "phase 0 → 15")
    H.assert_near(NS.DualLiftBar.SecondaryPhase(def, 20.0),  5.0, 0.001, "phase 20 → 35 wraps to 5")
    H.assert_near(NS.DualLiftBar.SecondaryPhase(def, 15.0),  0.0, 0.001, "phase 15 → 30 wraps to 0")
end

H.section("DualLiftBar.SecondaryPhase — tblift (dualOffset = -3.7)")
do
    local def = LIFTS.tblift  -- cycleTime 30, dualOffset -3.7
    H.assert_near(NS.DualLiftBar.SecondaryPhase(def, 10.0), 6.3, 0.001, "phase 10 - 3.7 → 6.3")
    H.assert_near(NS.DualLiftBar.SecondaryPhase(def, 0.0),  26.3, 0.001, "phase 0 - 3.7 wraps to 26.3")
end

-- ─── DualLiftBar.ResolveClick — quartile zones + secondary translation ────────

H.section("DualLiftBar.ResolveClick — greatlift primary quartiles")
do
    local def = LIFTS.greatlift  -- starts {0, 10, 15, 25}
    local l1, p1 = NS.DualLiftBar.ResolveClick(def, true, 0.90)
    H.assert_eq(l1, "TOP",          "top quarter → TOP")
    H.assert_near(p1, 25.0, 0.001,  "TOP → starts[4]=25")
    local l2, p2 = NS.DualLiftBar.ResolveClick(def, true, 0.60)
    H.assert_eq(l2, "FALL",         "upper-mid → FALL")
    H.assert_near(p2, 0.0, 0.001,   "FALL → starts[1]=0")
    local l3, p3 = NS.DualLiftBar.ResolveClick(def, true, 0.30)
    H.assert_eq(l3, "RISE",         "lower-mid → RISE")
    H.assert_near(p3, 15.0, 0.001,  "RISE → starts[3]=15")
    local l4, p4 = NS.DualLiftBar.ResolveClick(def, true, 0.10)
    H.assert_eq(l4, "BOTTOM",       "bottom quarter → BOTTOM")
    H.assert_near(p4, 10.0, 0.001,  "BOTTOM → starts[2]=10")
end

H.section("DualLiftBar.ResolveClick — secondary translates to primary clock")
do
    -- greatlift: offset = cycleTime/2 = 15
    local gl = LIFTS.greatlift
    local lg, pg = NS.DualLiftBar.ResolveClick(gl, false, 0.90)  -- TOP seg=25
    H.assert_eq(lg, "TOP (2nd)",    "secondary label tagged")
    H.assert_near(pg, 10.0, 0.001,  "(25-15)%30 = 10")
    local _, pg2 = NS.DualLiftBar.ResolveClick(gl, false, 0.10)  -- BOTTOM seg=10
    H.assert_near(pg2, 25.0, 0.001, "(10-15)%30 = 25")

    -- tblift: offset = dualOffset = -3.7; starts {0, 9.5, 15, 24.5}
    local tb = LIFTS.tblift
    local _, pt = NS.DualLiftBar.ResolveClick(tb, false, 0.90)   -- TOP seg=24.5
    H.assert_near(pt, 28.2, 0.001,  "(24.5-(-3.7))%30 = 28.2")
    local _, pt2 = NS.DualLiftBar.ResolveClick(tb, false, 0.10)  -- BOTTOM seg=9.5
    H.assert_near(pt2, 13.2, 0.001, "(9.5+3.7)%30 = 13.2")
end

-- ─── LightCountdown.FormatCountdown ───────────────────────────────────────────

H.section("LightCountdown.FormatCountdown — aldor")
do
    local def = LIFTS.aldor
    local n, t = NS.LightCountdown.FormatCountdown(def, 0.0)
    H.assert_eq(n, "Aldor Lift", "name at phase=0")
    H.assert_eq(t, "7s",         "countdown to BOTTOM (round of 6.933)")

    local _, t2 = NS.LightCountdown.FormatCountdown(def, 24.5)
    H.assert_eq(t2, "1s",        "near cycle end → wraps (round of 0.5)")
end

H.section("LightCountdown.FormatCountdown — tram")
do
    local def = LIFTS.deepruntram
    local _, t = NS.LightCountdown.FormatCountdown(def, 0.0)
    H.assert_eq(t, "59s", "tram phase=0 → 58.633 rounds to 59s")
end

-- ─── TramUI car-position helpers (exposed for test) ───────────────────────────

H.section("TramUI.TramCarPos — Deeprun Tram")
do
    local def = LIFTS.deepruntram
    -- Segments (tram): 1=TO SW (0..58.633), 2=AT SW (58.633..71.667),
    --                  3=TO IF (71.667..130.300), 4=AT IF (130.300..143.333)
    local pos1 = NS.TramUI.TramCarPos(def, 0.0)
    H.assert_near(pos1, 0.0, 0.01, "phase=0 → car at IF end (pos 0)")

    local pos2 = NS.TramUI.TramCarPos(def, 58.633 / 2)
    H.assert_near(pos2, 0.5, 0.01, "mid TO-SW → halfway across")

    local pos3 = NS.TramUI.TramCarPos(def, 65.0)
    H.assert_near(pos3, 1.0, 0.01, "AT SW → pinned at 1")

    local pos4 = NS.TramUI.TramCarPos(def, 71.667 + 58.633 / 2)
    H.assert_near(pos4, 0.5, 0.01, "mid TO-IF → halfway back")

    local pos5 = NS.TramUI.TramCarPos(def, 135.0)
    H.assert_near(pos5, 0.0, 0.01, "AT IF → pinned at 0")
end

H.section("TramUI.TramCarDir — Deeprun Tram")
do
    local def = LIFTS.deepruntram
    local d1, ttb1 = NS.TramUI.TramCarDir(def, 0.0)
    H.assert_true(d1:find("SW") ~= nil, "phase=0 direction mentions SW")
    H.assert_near(ttb1, 58.633, 0.01,   "phase=0 ttb = full TO-SW")

    local d2, _ = NS.TramUI.TramCarDir(def, 60.0)
    H.assert_eq(d2, "depart SW", "AT SW direction = depart SW")
end

-- ─── LiftBar layout against real LIFTS def ────────────────────────────────────

H.section("LiftBar uses TransportCycle.SegmentLayout on real LIFTS")
do
    -- LiftBar's frame-construction call path uses TC.SegmentLayout; we can
    -- verify the same call here without building frames.
    local rects = TC.SegmentLayout(460, LIFTS.aldor)
    H.assert_eq(rects[1].x, 0,                "first rect x=0")
    H.assert_eq(rects[4].x + rects[4].w, 460, "fills bar exactly")
end

H.results()
