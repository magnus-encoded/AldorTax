-- TransportCycle pure-function tests.
-- Run from addon root: lua tests/test_transport_cycle.lua

package.path  = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H       = require("test_harness")

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
AldorTaxDB = nil

local NS = H.LoadAddon()
MockAPI.InitAddon()

local TC    = NS.TransportCycle
local LIFTS = NS.LIFTS

H.section("NS exposure")
do
    H.assert_true(TC ~= nil,                 "NS.TransportCycle exposed")
    H.assert_true(LIFTS ~= nil,              "NS.LIFTS exposed")
    H.assert_true(LIFTS.aldor ~= nil,        "aldor def reachable via NS.LIFTS")
    H.assert_true(LIFTS.deepruntram ~= nil,  "deepruntram def reachable via NS.LIFTS")
end

H.section("SegmentDurations — aldor (25s cycle)")
do
    local def = LIFTS.aldor
    local d   = TC.SegmentDurations(def)
    H.assert_eq(#d, 4,                 "four durations")
    H.assert_near(d[1], def.fallTime,     0.001, "[1] = fallTime")
    H.assert_near(d[2], def.waitAtBottom, 0.001, "[2] = waitAtBottom")
    H.assert_near(d[3], def.riseTime,     0.001, "[3] = riseTime")
    H.assert_near(d[4], def.waitAtTop,    0.001, "[4] = waitAtTop")
    local sum = d[1] + d[2] + d[3] + d[4]
    H.assert_near(sum, def.cycleTime, 0.001, "durations sum to cycleTime")
end

H.section("SegmentStarts — aldor")
do
    local def = LIFTS.aldor
    local s   = TC.SegmentStarts(def)
    H.assert_eq(s[1], 0,                                                  "starts[1] = 0")
    H.assert_near(s[2], def.fallTime,                            0.001, "starts[2] = fallTime")
    H.assert_near(s[3], def.fallTime + def.waitAtBottom,         0.001, "starts[3]")
    H.assert_near(s[4], def.fallTime + def.waitAtBottom + def.riseTime, 0.001, "starts[4]")
end

H.section("SegmentIndexAt — aldor (boundary tie-breaking)")
do
    local def = LIFTS.aldor
    -- def.fallTime = 6.933, +waitAtBottom = 11.233, +riseTime = 19.300
    H.assert_eq(TC.SegmentIndexAt(def, 0.0),     1, "phase=0 → seg 1 (FALL)")
    H.assert_eq(TC.SegmentIndexAt(def, 6.9),     1, "phase=6.9 still in FALL")
    H.assert_eq(TC.SegmentIndexAt(def, 6.933),   2, "phase=fallTime → seg 2 (BOTTOM)")
    H.assert_eq(TC.SegmentIndexAt(def, 11.233),  3, "phase=fall+bottom → seg 3 (RISE)")
    H.assert_eq(TC.SegmentIndexAt(def, 19.300),  4, "phase=fall+bottom+rise → seg 4 (TOP)")
    H.assert_eq(TC.SegmentIndexAt(def, 24.999),  4, "phase near cycle end → seg 4")
end

H.section("SegmentLabels — default vs tram override")
do
    local labels = TC.SegmentLabels(LIFTS.aldor)
    H.assert_eq(labels[1], "FALL",   "aldor seg 1 label")
    H.assert_eq(labels[4], "TOP",    "aldor seg 4 label")

    local tramLabels = TC.SegmentLabels(LIFTS.deepruntram)
    H.assert_eq(tramLabels[1], "TO SW", "tram seg 1 label from phaseNames")
    H.assert_eq(tramLabels[4], "AT IF", "tram seg 4 label from phaseNames")
end

H.section("Phase — wrap and identity")
do
    local def = LIFTS.aldor
    -- now == syncTime → phase 0
    H.assert_near(TC.Phase(def, 1000, 1000),                       0.0,  0.001, "now==syncTime → 0")
    -- 5s after sync → phase 5
    H.assert_near(TC.Phase(def, 1000, 1005),                       5.0,  0.001, "5s elapsed")
    -- 26s after a 25s cycle → wraps to 1s
    H.assert_near(TC.Phase(def, 1000, 1026),                       1.0,  0.001, "wraps at cycleTime")
    -- 2 full cycles + 3s
    H.assert_near(TC.Phase(def, 1000, 1000 + 2*def.cycleTime + 3), 3.0,  0.001, "two cycles + 3s")
end

H.section("Tram (143.333s cycle) sanity")
do
    local def = LIFTS.deepruntram
    -- cycleTime = 143.333; fallTime=58.633; waitAtBottom=13.034;
    -- riseTime=58.633; waitAtTop=13.033
    local d = TC.SegmentDurations(def)
    H.assert_near(d[1], 58.633, 0.001, "tram seg 1 duration")
    H.assert_near(d[3], 58.633, 0.001, "tram seg 3 duration (symmetric)")

    local s = TC.SegmentStarts(def)
    H.assert_near(s[2],  58.633,  0.001, "tram starts[2]")
    H.assert_near(s[3],  71.667,  0.001, "tram starts[3]")
    H.assert_near(s[4], 130.300,  0.001, "tram starts[4]")

    H.assert_eq(TC.SegmentIndexAt(def, 0.0),    1, "tram phase=0 → seg 1 (TO SW)")
    H.assert_eq(TC.SegmentIndexAt(def, 130.3),  4, "tram phase=130.3 → seg 4 (AT IF)")
end

H.section("LiftHeight — greatlift (30s, fall=rise=10, waits=5)")
do
    local def = LIFTS.greatlift
    -- segments: FALL 0..10, BOTTOM 10..15, RISE 15..25, TOP 25..30
    H.assert_near(TC.LiftHeight(def, 0.0),  1.0, 0.001, "phase=0 → top (1.0)")
    H.assert_near(TC.LiftHeight(def, 5.0),  0.5, 0.001, "mid-FALL → halfway down")
    H.assert_near(TC.LiftHeight(def, 10.0), 0.0, 0.001, "end FALL → bottom (0.0)")
    H.assert_near(TC.LiftHeight(def, 12.5), 0.0, 0.001, "BOTTOM hold → 0")
    H.assert_near(TC.LiftHeight(def, 20.0), 0.5, 0.001, "mid-RISE → halfway up")
    H.assert_near(TC.LiftHeight(def, 25.0), 1.0, 0.001, "end RISE → top")
    H.assert_near(TC.LiftHeight(def, 28.0), 1.0, 0.001, "TOP hold → 1")
end

H.section("SecondaryDef — shared-cycle vs distinct-cycle")
do
    -- greatlift has no cycleTime2 → platforms share one cycle, def returned as-is
    local gl = LIFTS.greatlift
    H.assert_true(TC.SecondaryDef(gl) == gl, "no cycleTime2 → returns same def")

    -- synthetic distinct-cycle def: overrides applied, *2 fields preferred
    local synth = {
        fallTime = 10, waitAtBottom = 5, riseTime = 10, waitAtTop = 5,
        cycleTime = 30, cycleTime2 = 40, fallTime2 = 12,
        segColors = gl.segColors,
    }
    local sd = TC.SecondaryDef(synth)
    H.assert_false(sd == synth,                    "distinct cycle → new table")
    H.assert_near(sd.cycleTime, 40,        0.001,  "cycleTime from cycleTime2")
    H.assert_near(sd.fallTime,  12,        0.001,  "fallTime from fallTime2 override")
    H.assert_near(sd.waitAtBottom, 5,      0.001,  "waitAtBottom falls back to primary")
    H.assert_true(sd.segColors == gl.segColors,    "segColors carried through")
end

H.results()
