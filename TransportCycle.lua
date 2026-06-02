-- TransportCycle — pure cycle/phase math for AldorTax's lift definitions.
--
-- The lift defs in AldorTax.lua use four flat-field segment durations
-- (fallTime, waitAtBottom, riseTime, waitAtTop). The widget layer wants
-- to think in terms of a generic "segments" array — durations, starts,
-- index-at-phase. TransportCycle is the bridge: read from the legacy
-- flat-field model, expose a uniform segment view. No WoW API, no side
-- effects, no module state.
--
-- Segment order is fixed: FALL → BOTTOM → RISE → TOP, indices 1..4.
-- Horizontal transports (Deeprun Tram) override the labels via
-- def.phaseNames; the index order is unchanged so segColors[i] still
-- aligns with the i-th segment.

local _, NS = ...

local TransportCycle = {}

local DEFAULT_LABELS = { "FALL", "BOTTOM", "RISE", "TOP" }

-- Durations of the four segments in cycle order. Allocates a new table
-- per call — callers are short-lived widget layout passes; caching would
-- only matter if this showed up in a profile, which it won't.
function TransportCycle.SegmentDurations(def)
    return { def.fallTime, def.waitAtBottom, def.riseTime, def.waitAtTop }
end

-- Labels for the four segments. Horizontal defs (tram) carry phaseNames;
-- vertical defs use the default FALL/BOTTOM/RISE/TOP.
function TransportCycle.SegmentLabels(def)
    return def.phaseNames or DEFAULT_LABELS
end

-- Cycle-relative start phase of each segment, in seconds. starts[1] is
-- always 0; starts[i+1] = starts[i] + duration[i]. The cycle wraps after
-- starts[4] + waitAtTop = cycleTime.
function TransportCycle.SegmentStarts(def)
    local s = {}
    s[1] = 0
    s[2] = def.fallTime
    s[3] = s[2] + def.waitAtBottom
    s[4] = s[3] + def.riseTime
    return s
end

-- Which segment (1..4) does this phase fall into? Mirrors GetLiftHeight /
-- GetPhaseColor in the monolith — same boundaries, same tie-breaking
-- (a phase exactly on a boundary belongs to the later segment).
function TransportCycle.SegmentIndexAt(def, phase)
    if phase < def.fallTime then return 1 end
    if phase < def.fallTime + def.waitAtBottom then return 2 end
    if phase < def.fallTime + def.waitAtBottom + def.riseTime then return 3 end
    return 4
end

-- Cycle phase implied by a stored sync time. Wraps to [0, cycleTime).
-- syncTime and now must share a clock (both GetTime() or both real-time).
function TransportCycle.Phase(def, syncTime, now)
    return (now - syncTime) % def.cycleTime
end

-- Seconds to the *next* segment boundary, wrapping through the cycle.
-- At phase=0 the next boundary is segment 2's start (end of FALL).
-- At phase exactly on a boundary the *following* boundary is returned —
-- mirrors SegmentIndexAt's tie-breaking (boundary belongs to later seg,
-- so the boundary "next from here" is the one after that).
function TransportCycle.SecondsToNextBoundary(def, phase)
    local starts  = TransportCycle.SegmentStarts(def)
    local segIdx  = TransportCycle.SegmentIndexAt(def, phase)
    local nextSeg = (segIdx % 4) + 1
    return (starts[nextSeg] - phase + def.cycleTime) % def.cycleTime
end

-- Proportional pixel rects for the four segments, packed into a bar of
-- `barWidth` pixels. Guarantees: rects[1].x = 0, rects[i+1].x = rects[i].x
-- + rects[i].w (no gaps, no overlaps), rects[4].x + rects[4].w = barWidth
-- exactly (any rounding goes into the last segment). Width-proportional
-- to each segment's duration. Salvaged from the LiftBar.lua draft's
-- SegmentLayout — same algorithm, reads via TransportCycle instead of
-- a def.segments array.
function TransportCycle.SegmentLayout(barWidth, def)
    local durations = TransportCycle.SegmentDurations(def)
    local cycle     = def.cycleTime
    local pixelAt   = { 0 }
    local cumDur    = 0
    for i = 1, 4 do
        cumDur       = cumDur + durations[i]
        pixelAt[i+1] = (i == 4) and barWidth
            or math.floor(cumDur * barWidth / cycle + 0.5)
    end
    local rects = {}
    for i = 1, 4 do
        rects[i] = { x = pixelAt[i], w = pixelAt[i+1] - pixelAt[i] }
    end
    return rects
end

-- Vertical height fraction [0,1] of a lift platform at the given phase:
-- 0 = at the bottom, 1 = at the top. Mirrors the monolith's GetLiftHeight.
-- FALL ramps 1→0, BOTTOM holds 0, RISE ramps 0→1, TOP holds 1. Used by the
-- DualLiftBar widget to place each vertical cursor.
function TransportCycle.LiftHeight(def, phase)
    if phase < def.fallTime then
        return 1.0 - (phase / def.fallTime)
    elseif phase < def.fallTime + def.waitAtBottom then
        return 0.0
    elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
        return (phase - def.fallTime - def.waitAtBottom) / def.riseTime
    else
        return 1.0
    end
end

-- The secondary platform's segment def for a dual lift. Mirrors the
-- monolith's SecDef: when a def carries a distinct second-platform cycle
-- (cycleTime2 + optional *2 segment overrides) this returns a flat def for
-- that platform; otherwise the platforms share one cycle and the original
-- def is returned unchanged. The returned table is suitable input to the
-- other TransportCycle functions (carries segColors; falls back to the
-- primary segment times for any *2 field left unset).
function TransportCycle.SecondaryDef(def)
    if not def.cycleTime2 then return def end
    return {
        fallTime     = def.fallTime2     or def.fallTime,
        waitAtBottom = def.waitAtBottom2 or def.waitAtBottom,
        riseTime     = def.riseTime2     or def.riseTime,
        waitAtTop    = def.waitAtTop2    or def.waitAtTop,
        cycleTime    = def.cycleTime2,
        segColors    = def.segColors,
    }
end

NS.TransportCycle = TransportCycle
