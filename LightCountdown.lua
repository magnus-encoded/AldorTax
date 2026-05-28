-- LightCountdown.lua — Read-only countdown for far-approach proximity.
-- Shows transport name + seconds to next segment boundary.
-- Init seam: LightCountdown.Init({ getState, getActiveID, onDismiss })
-- FormatCountdown is a pure function suitable for unit testing.

local _, NS = ...
local TransportCycle = NS.TransportCycle
local LIFTS          = NS.LIFTS

local LightCountdown = {}
NS.LightCountdown = LightCountdown

-- ─── Pure: FormatCountdown ─────────────────────────────────────────────────────
-- Returns (displayName, countdownText) for a transport at the given phase.
-- phase: seconds elapsed since cycle start, in [0, cycleTime).

function LightCountdown.FormatCountdown(def, phase)
    if not def or not def.cycleTime then
        return (def and def.displayName or "?"), "?"
    end
    local ttb     = TransportCycle.SecondsToNextBoundary(def, phase)
    local seconds = math.floor(ttb + 0.5)
    return def.displayName, string.format("%ds", seconds)
end

-- ─── Init seam ─────────────────────────────────────────────────────────────────

local _getState, _getActiveID, _onDismiss

function LightCountdown.Init(deps)
    _getState    = deps.getState
    _getActiveID = deps.getActiveID
    _onDismiss   = deps.onDismiss
end

-- ─── Frame state ───────────────────────────────────────────────────────────────

local lcFrame            = nil
local FRAME_W            = 184
local FRAME_H            = 36
local PAD                = 8
local currentTransportID = nil

local function BuildFrame()
    if lcFrame then return end

    lcFrame = CreateFrame("Frame", "AldorTaxLightCountdown", UIParent, "BackdropTemplate")
    lcFrame:SetFrameStrata("MEDIUM")
    lcFrame:SetSize(FRAME_W, FRAME_H)
    lcFrame:SetMovable(true)
    lcFrame:SetClampedToScreen(true)
    lcFrame:EnableMouse(true)
    lcFrame:RegisterForDrag("LeftButton")
    lcFrame:SetScript("OnDragStart", lcFrame.StartMoving)
    lcFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AldorTaxDB then
            local point, _, relPoint, x, y = self:GetPoint(1)
            AldorTaxDB.barPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    lcFrame:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    lcFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.80)
    lcFrame:SetBackdropBorderColor(0.35, 0.30, 0.18, 0.60)

    if AldorTaxDB and AldorTaxDB.barPos then
        local p = AldorTaxDB.barPos
        lcFrame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        lcFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    -- Close button
    local closeBtn = CreateFrame("Button", nil, lcFrame, "UIPanelCloseButton")
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", 1, 1)
    closeBtn:SetScript("OnClick", function() _onDismiss() end)

    -- Transport name label (left)
    local nameLabel = lcFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT", PAD, 0)
    nameLabel:SetTextColor(1, 0.82, 0)
    lcFrame.nameLabel = nameLabel

    -- Countdown text (right of name, left of close button)
    local cntLabel = lcFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cntLabel:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    cntLabel:SetTextColor(0.9, 0.9, 0.9)
    lcFrame.cntLabel = cntLabel

    lcFrame:Hide()
end

-- ─── Public API ────────────────────────────────────────────────────────────────

function LightCountdown.Show(transportID)
    BuildFrame()
    currentTransportID = transportID
    lcFrame:Show()
end

function LightCountdown.Hide()
    if lcFrame then lcFrame:Hide() end
    currentTransportID = nil
end

function LightCountdown.IsShown()
    return lcFrame ~= nil and lcFrame:IsShown()
end

function LightCountdown.frame()
    return lcFrame
end

function LightCountdown.SetMode(_mode) end  -- read-only widget; no mode variants

function LightCountdown.ReconfigureTransport(transportID)
    BuildFrame()
    currentTransportID = transportID
    local def = LIFTS[transportID]
    if def and lcFrame.nameLabel then
        lcFrame.nameLabel:SetText(def.displayName)
    end
end

function LightCountdown.UpdateCursor()
    if not lcFrame or not lcFrame:IsShown() or not currentTransportID then return end

    local states = _getState()
    local id     = _getActiveID()
    if not id or not states or id ~= currentTransportID then return end

    local st  = states[id]
    local def = LIFTS[id]
    if not st or not def then return end

    if st.lastSync > 0 then
        local phase    = (GetTime() - st.lastSync) % def.cycleTime
        local name, txt = LightCountdown.FormatCountdown(def, phase)
        lcFrame.nameLabel:SetText(name)
        lcFrame.cntLabel:SetText(txt)
    else
        lcFrame.cntLabel:SetText("?")
    end
end
