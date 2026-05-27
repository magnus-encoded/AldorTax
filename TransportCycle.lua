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

NS.TransportCycle = TransportCycle
