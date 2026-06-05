-- WidgetRouter — decides which widget to show given (transport form,
-- proximity). Pure 12-cell decision table; no state, no API calls.
--
-- A transport's "form" is its rendering geometry — how the addon draws it,
-- independent of the specific transport. Three forms:
--   "single"     — one vertical platform (Aldor, Stormspire, SSC elevator)
--   "dual"       — two complementary vertical platforms with a half-cycle
--                  or explicit-dualOffset relationship (Great Lift, TB Lift).
--                  Structurally distinct from "single" — two cursors, two
--                  stacked bars — so it gets its own widget (DualLiftBar)
--                  rather than being a mode of LiftBar.
--   "horizontal" — side-to-side transport (Deeprun Tram)
--
-- (Form is the addon's word for layout/geometry; it is deliberately NOT
-- named after any transport. "lift"/"tram" stay in displayNames only —
-- see CONTEXT.md. The cycle-segment math lives in TransportCycle.)
--
-- TransportForm() maps a def to its form:
--   def.horizontal              → "horizontal"
--   def.dualLift                → "dual"
--   otherwise                   → "single"
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
    single = {
        on_platform = "LiftBar",
        approaching = "LiftBar",
        other       = "LightCountdown",
    },
    dual = {
        on_platform = "DualLiftBar",
        approaching = "DualLiftBar",
        other       = "LightCountdown",
    },
    horizontal = {
        on_platform = "TramUI",
        approaching = "TramUI",
        other       = "LightCountdown",
    },
}

-- Form defaults to "single" (the common case); unknown proximity collapses
-- to "other" so an unrecognized state still produces a sensible widget
-- rather than a nil that the caller has to guard.
local function DispatchWidget(form, proximity)
    local row = WIDGET[form] or WIDGET.single
    return row[proximity] or row.other
end

NS.DispatchWidget = DispatchWidget

-- Maps a transport def to its form. Kept separate from DispatchWidget so the
-- caller composes (def → form) then (form, proximity → widget).
local function TransportForm(def)
    if not def then return "single" end
    -- Order matters: the Deeprun Tram is both horizontal and dualLift; the
    -- horizontal form takes precedence over the vertical dual bars.
    if def.horizontal then return "horizontal" end
    if def.dualLift   then return "dual" end
    return "single"
end

NS.TransportForm = TransportForm
