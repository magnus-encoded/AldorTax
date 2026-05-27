-- WidgetRouter — decides which widget to show given (transport kind,
-- proximity). Pure 12-cell decision table; no state, no API calls.
--
-- Kinds:
--   "lift" — vertical platform (Aldor, Stormspire, Great Lift, TB Lift, SSC)
--   "tram" — horizontal transport (Deeprun Tram)
--
-- Proximities (computed by the caller from subzone + map distance):
--   "on_platform"  — player is standing on / at the platform
--   "approaching"  — player is in the approach subzone
--   "other"        — player is in the zone but neither on nor approaching
--
-- The fallback row covers unknown / nil proximity, treated as "far away":
-- show the read-only LightCountdown so the player still has timing info
-- without the calibration-click affordances that the bar widgets carry.

local _, NS = ...

local WIDGET = {
    lift = {
        on_platform = "LiftBar",
        approaching = "LiftBar",
        other       = "LightCountdown",
    },
    tram = {
        on_platform = "TramUI",
        approaching = "TramUI",
        other       = "LightCountdown",
    },
}

-- Kind defaults to "lift" (the common case); unknown proximity collapses
-- to "other" so an unrecognized state still produces a sensible widget
-- rather than a nil that the caller has to guard.
local function DispatchWidget(kind, proximity)
    local row = WIDGET[kind] or WIDGET.lift
    return row[proximity] or row.other
end

NS.DispatchWidget = DispatchWidget
