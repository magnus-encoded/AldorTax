-- DualLiftBar.lua — Two stacked vertical bars for dual-platform lifts
-- (Great Lift, TB Lift). Structurally distinct from LiftBar: two cursors
-- riding two vertical height indicators, side by side, with complementary
-- phases (half-cycle by default, or def.dualOffset).
--
-- Standalone widget — owns its own chrome (backdrop, drag, close, name,
-- say button); does NOT reuse LiftBar. Visual reference is the monolith's
-- MakeVBar / dual-container layout (VBAR_W/H/GAP, gradient fill, ^arr./v arr.
-- marks, top/bottom-half click-to-sync zones).
--
-- Init seam: DualLiftBar.Init({ getState, getActiveID, onCalibrate, onDismiss })
-- Modes: "full" (on platform), "compact" (approaching) — compact strips chrome.

local _, NS = ...
local TransportCycle = NS.TransportCycle
local LIFTS          = NS.LIFTS

local DualLiftBar = {}
NS.DualLiftBar = DualLiftBar

-- ─── Constants ─────────────────────────────────────────────────────────────────

local VBAR_W   = 26   -- vertical bar width
local VBAR_H   = 130  -- vertical bar height
local VBAR_GAP = 70   -- gap between the two bars
local PAD      = 12

-- ─── Pure helpers (exposed for tests) ──────────────────────────────────────────

-- Secondary-platform phase given the primary phase. The two platforms run
-- complementary: offset defaults to half a cycle, or def.dualOffset when the
-- def pins a measured lead/lag (e.g. TB Lift North leads South by 3.7s). The
-- modulus uses the secondary cycle so distinct-cycle defs stay in range.
function DualLiftBar.SecondaryPhase(def, phase1)
    local sd     = TransportCycle.SecondaryDef(def)
    local offset = def.dualOffset or (def.cycleTime / 2)
    return (phase1 + offset) % sd.cycleTime
end

local SecondaryPhase = DualLiftBar.SecondaryPhase

-- Resolve a vertical click fraction (0 = bottom .. 1 = top) on one bar to the
-- segment boundary it means and the primary-clock phase to calibrate to.
-- Four quartile zones (matches the monolith): top quarter → TOP, upper-mid →
-- FALL, lower-mid → RISE, bottom quarter → BOTTOM. Arrivals at top/bottom are
-- the common case; the FALL/RISE zones let a player sync off a mid-transit
-- sighting. Single-clock model: a secondary-bar click still calibrates the one
-- shared clock, so the observed secondary phase is translated back through the
-- dual offset. Pure; exposed for tests.
function DualLiftBar.ResolveClick(def, isPrimary, frac)
    local sd     = isPrimary and def or TransportCycle.SecondaryDef(def)
    local starts = TransportCycle.SegmentStarts(sd)
    local label, segPhase
    if     frac >= 0.75 then label, segPhase = "TOP",    starts[4]
    elseif frac >= 0.50 then label, segPhase = "FALL",   starts[1]
    elseif frac >= 0.25 then label, segPhase = "RISE",   starts[3]
    else                     label, segPhase = "BOTTOM", starts[2]
    end
    if isPrimary then
        return label, segPhase
    end
    local offset = def.dualOffset or (def.cycleTime / 2)
    return label .. " (2nd)", (segPhase - offset) % def.cycleTime
end

-- ─── Init seam ─────────────────────────────────────────────────────────────────

local _getState, _getActiveID, _onCalibrate, _onDismiss

function DualLiftBar.Init(deps)
    _getState    = deps.getState
    _getActiveID = deps.getActiveID
    _onCalibrate = deps.onCalibrate
    _onDismiss   = deps.onDismiss
end

-- ─── Frame state ───────────────────────────────────────────────────────────────

local dFrame             = nil
local currentMode        = "full"
local currentTransportID = nil

-- ─── Vertical-bar builder ──────────────────────────────────────────────────────

-- Click on the top half = "lift arrived at top" (calibrate to TOP segment
-- start); bottom half = "arrived at bottom" (BOTTOM segment start). isPrimary
-- selects which platform the click syncs. The frac (0=bottom .. 1=top) is
-- derived by the caller from the cursor's vertical position.
local function MakeVBar(parent, label, isPrimary, onBarClick)
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(VBAR_W + 6, VBAR_H + 6)
    bg:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bg:SetBackdropColor(0.03, 0.03, 0.06, 0.92)
    if isPrimary then
        bg:SetBackdropBorderColor(0.50, 0.45, 0.25, 0.90)
    else
        bg:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.70)
    end

    -- Height-indicator bar (clean, no phase segments — height IS the readout)
    local vbar = CreateFrame("Frame", nil, bg)
    vbar:SetSize(VBAR_W, VBAR_H)
    vbar:SetPoint("CENTER")

    local gradTop = vbar:CreateTexture(nil, "ARTWORK")
    gradTop:SetColorTexture(0.12, 0.12, 0.15, 0.50)
    gradTop:SetPoint("TOPLEFT"); gradTop:SetPoint("RIGHT")
    gradTop:SetHeight(VBAR_H / 2)
    local gradBot = vbar:CreateTexture(nil, "ARTWORK")
    gradBot:SetColorTexture(0.05, 0.05, 0.08, 0.50)
    gradBot:SetPoint("BOTTOMLEFT"); gradBot:SetPoint("RIGHT")
    gradBot:SetHeight(VBAR_H / 2)

    -- Arrival marks at the two ends
    local topMark = vbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topMark:SetPoint("TOP", vbar, "TOP", 0, -3)
    topMark:SetText("^ arr.")
    topMark:SetTextColor(0.50, 0.70, 0.50, 0.55)
    topMark:SetScale(0.75)
    local btmMark = vbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btmMark:SetPoint("BOTTOM", vbar, "BOTTOM", 0, 3)
    btmMark:SetText("v arr.")
    btmMark:SetTextColor(0.50, 0.50, 0.70, 0.55)
    btmMark:SetScale(0.75)

    -- Phase label that rides alongside the cursor
    local phaseLbl = vbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    phaseLbl:SetScale(0.80)
    phaseLbl:SetShadowOffset(1, -1)
    phaseLbl:SetShadowColor(0, 0, 0, 1)

    -- Click overlay: top half / bottom half sync zones
    local clickBtn = CreateFrame("Button", nil, bg)
    clickBtn:SetSize(VBAR_W, VBAR_H)
    clickBtn:SetPoint("CENTER")
    clickBtn:SetFrameLevel(vbar:GetFrameLevel() + 3)
    local hlTex = clickBtn:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetColorTexture(1, 1, 1, isPrimary and 0.08 or 0.05)
    hlTex:SetAllPoints()
    hlTex:SetBlendMode("ADD")
    clickBtn:SetScript("OnClick", function(self)
        local _, cursorY = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        local bot, top = self:GetBottom(), self:GetTop()
        if not bot or not top or top == bot then return end
        local frac = ((cursorY / scale) - bot) / (top - bot)
        frac = math.max(0, math.min(1, frac))
        onBarClick(isPrimary, frac)
    end)
    clickBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to sync (" .. label .. ")", 1, 0.82, 0, 1)
        GameTooltip:AddLine("Top half: click when lift arrives at top", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Bottom half: click when lift arrives at bottom", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    clickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Midline divider between the two click zones
    local midline = vbar:CreateTexture(nil, "ARTWORK", nil, 2)
    midline:SetColorTexture(0.55, 0.50, 0.40, 0.55)
    midline:SetSize(VBAR_W, 1)
    midline:SetPoint("CENTER", vbar, "CENTER", 0, 0)

    -- Cursor overlay (above click button)
    local voverlay = CreateFrame("Frame", nil, bg)
    voverlay:SetSize(VBAR_W, VBAR_H)
    voverlay:SetPoint("CENTER")
    voverlay:SetFrameLevel(clickBtn:GetFrameLevel() + 2)

    local glow = voverlay:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetColorTexture(1, 1, 1, 0.15)
    glow:SetSize(VBAR_W + 6, 8)
    glow:SetBlendMode("ADD")

    local cur = voverlay:CreateTexture(nil, "OVERLAY", nil, 2)
    cur:SetSize(VBAR_W + 4, 3)
    cur:SetPoint("CENTER", voverlay, "BOTTOM", 0, 0)

    -- Label above the bar
    local lbl = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("BOTTOM", bg, "TOP", 0, 2)
    lbl:SetText(label)
    if isPrimary then
        lbl:SetTextColor(0.95, 0.88, 0.55)
    else
        lbl:SetTextColor(0.60, 0.58, 0.50)
    end

    -- Time label below the bar
    local tlbl = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlbl:SetPoint("TOP", bg, "BOTTOM", 0, -3)
    tlbl:SetShadowOffset(1, -1)
    tlbl:SetShadowColor(0, 0, 0, 1)

    return {
        bg = bg, bar = vbar, overlay = voverlay,
        cursor = cur, glow = glow,
        label = lbl, timeLabel = tlbl, phaseLbl = phaseLbl,
        isPrimary = isPrimary,
    }
end

-- ─── Calibration click ─────────────────────────────────────────────────────────

-- Wires a bar's click through the pure ResolveClick resolver to the single
-- shared sync clock. Both bars calibrate the one clock (single-clock model).
local function OnBarClick(isPrimary, frac)
    local id = _getActiveID()
    if not id then return end
    local def = LIFTS[id]
    if not def then return end
    local label, phase = DualLiftBar.ResolveClick(def, isPrimary, frac)
    _onCalibrate(id, phase, label)
end

-- ─── Frame construction (lazy) ─────────────────────────────────────────────────

local function BuildFrame()
    if dFrame then return end

    dFrame = CreateFrame("Frame", "AldorTaxDualLiftBar", UIParent, "BackdropTemplate")
    dFrame:SetFrameStrata("MEDIUM")
    dFrame:SetMovable(true)
    dFrame:SetClampedToScreen(true)
    dFrame:EnableMouse(true)
    dFrame:RegisterForDrag("LeftButton")
    dFrame:SetScript("OnDragStart", dFrame.StartMoving)
    dFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AldorTaxDB then
            local point, _, relPoint, x, y = self:GetPoint(1)
            AldorTaxDB.barPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    dFrame:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    dFrame:SetBackdropBorderColor(0.40, 0.36, 0.22, 0.70)

    if AldorTaxDB and AldorTaxDB.barPos then
        local p = AldorTaxDB.barPos
        dFrame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        dFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    -- Title
    local title = dFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -7)
    title:SetTextColor(1, 0.82, 0)
    dFrame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, dFrame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetFrameLevel(dFrame:GetFrameLevel() + 20)
    closeBtn:SetScript("OnClick", function() _onDismiss() end)
    dFrame.closeBtn = closeBtn

    -- Source label
    local sourceLabel = dFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceLabel:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, -3)
    sourceLabel:SetTextColor(0.6, 0.6, 0.6)
    dFrame.sourceLabel = sourceLabel

    -- Container for the two vertical bars (fills the frame)
    local container = CreateFrame("Frame", nil, dFrame)
    container:SetPoint("TOPLEFT", dFrame, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", dFrame, "BOTTOMRIGHT", 0, 0)
    dFrame.container = container

    -- Primary (left) and secondary (right) bars
    local vbar1 = MakeVBar(container, "—", true,  OnBarClick)
    local vbar2 = MakeVBar(container, "—", false, OnBarClick)
    vbar1.bg:SetPoint("TOP", container, "TOP", -(VBAR_GAP / 2 + VBAR_W / 2), -36)
    vbar2.bg:SetPoint("TOP", container, "TOP",  (VBAR_GAP / 2 + VBAR_W / 2), -36)
    dFrame.vbar1 = vbar1
    dFrame.vbar2 = vbar2

    -- Say Warning button (full mode only)
    local sayBtn = CreateFrame("Button", nil, dFrame, "UIPanelButtonTemplate")
    sayBtn:SetSize(130, 24)
    sayBtn:SetText("|cffffcc00Say Warning|r")
    sayBtn:SetNormalFontObject("GameFontNormalSmall")
    sayBtn:SetHighlightFontObject("GameFontHighlightSmall")
    sayBtn:SetPoint("BOTTOM", dFrame, "BOTTOM", 0, 8)
    sayBtn:SetScript("OnClick", function()
        if SlashCmdList and SlashCmdList["ALDORTAX"] then
            SlashCmdList["ALDORTAX"]("say")
        end
    end)
    sayBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Broadcast lift timing in /say", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    sayBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dFrame.sayBtn = sayBtn

    -- Sizes set in SetMode; default to full.
    dFrame:Hide()
end

-- ─── Layout (depends on mode) ──────────────────────────────────────────────────

local function ApplyLayout()
    local isCompact = currentMode == "compact"
    local c = dFrame.container

    dFrame.vbar1.bg:ClearAllPoints()
    dFrame.vbar2.bg:ClearAllPoints()

    if isCompact then
        -- Tight, chromeless: bars vertically centered, side by side. Geometry
        -- mirrors the monolith LayoutDualCompact.
        local frameW = VBAR_W * 2 + VBAR_GAP + PAD * 2 + 10
        local frameH = VBAR_H + PAD * 2
        dFrame:SetSize(frameW, frameH)
        dFrame.vbar1.bg:SetPoint("LEFT", c, "LEFT", PAD, 0)
        dFrame.vbar2.bg:SetPoint("LEFT", dFrame.vbar1.bg, "RIGHT", VBAR_GAP - 6, 0)
    else
        -- Full chrome: title + label-above + bars + time-below + say button.
        -- Geometry mirrors the monolith LayoutDualFull (verified-shipping sizes).
        local totalW = VBAR_W * 2 + VBAR_GAP + 6 * 2
        local frameW = totalW + PAD * 2 + 40
        if frameW < 200 then frameW = 200 end
        local frameH = 20 + 14 + VBAR_H + 6 + 14 + 24 + PAD + 8
        dFrame:SetSize(frameW, frameH)
        dFrame.vbar1.bg:SetPoint("TOP", c, "TOP", -(VBAR_GAP / 2 + VBAR_W / 2), -36)
        dFrame.vbar2.bg:SetPoint("TOP", c, "TOP",  (VBAR_GAP / 2 + VBAR_W / 2), -36)
    end

    dFrame.title:SetShown(not isCompact)
    dFrame.sourceLabel:SetShown(not isCompact)
    dFrame.sayBtn:SetShown(not isCompact)
    dFrame.vbar1.label:SetShown(not isCompact)
    dFrame.vbar2.label:SetShown(not isCompact)
    dFrame.vbar1.timeLabel:SetShown(not isCompact)
    dFrame.vbar2.timeLabel:SetShown(not isCompact)
end

-- ─── Public API ────────────────────────────────────────────────────────────────

function DualLiftBar.Show(transportID)
    BuildFrame()
    currentTransportID = transportID
    ApplyLayout()
    dFrame:Show()
end

function DualLiftBar.Hide()
    if dFrame then dFrame:Hide() end
    currentTransportID = nil
end

function DualLiftBar.IsShown()
    return dFrame ~= nil and dFrame:IsShown()
end

function DualLiftBar.frame()
    return dFrame
end

function DualLiftBar.SetMode(mode)
    if mode ~= "full" and mode ~= "compact" then mode = "full" end
    currentMode = mode
    BuildFrame()
    ApplyLayout()
end

function DualLiftBar.ReconfigureTransport(transportID)
    BuildFrame()
    local def = LIFTS[transportID]
    if not def then return end
    currentTransportID = transportID

    dFrame.title:SetText(def.displayName .. "  |cff888888click bar to sync|r")
    dFrame.vbar1.label:SetText(def.barLabel1 or "A")
    dFrame.vbar2.label:SetText(def.barLabel2 or "B")
end

function DualLiftBar.UpdateCursor()
    if not dFrame or not dFrame:IsShown() or not currentTransportID then return end

    local states = _getState()
    local id     = _getActiveID()
    if not id or not states or id ~= currentTransportID then return end

    local st  = states[id]
    local def = LIFTS[id]
    if not st or not def then return end

    local vbar1, vbar2 = dFrame.vbar1, dFrame.vbar2

    if st.lastSync <= 0 then
        for _, vb in ipairs({ vbar1, vbar2 }) do
            vb.cursor:ClearAllPoints()
            vb.cursor:SetPoint("CENTER", vb.overlay, "BOTTOM", 0, -5)
            vb.cursor:SetColorTexture(0.30, 0.30, 0.28, 0.40)
            vb.glow:ClearAllPoints()
            vb.glow:SetPoint("CENTER", vb.cursor, "CENTER")
            vb.glow:SetColorTexture(1, 1, 1, 0.05)
            vb.timeLabel:SetText("")
            vb.phaseLbl:SetText("")
        end
        dFrame.sourceLabel:SetText("no sync")
        dFrame.sourceLabel:SetTextColor(1, 0.4, 0)  -- warning tint: action needed
        return
    end

    local sd     = TransportCycle.SecondaryDef(def)
    local phase1 = (GetTime() - st.lastSync) % def.cycleTime
    local phase2 = SecondaryPhase(def, phase1)

    -- Primary bar
    local h1   = TransportCycle.LiftHeight(def, phase1)
    local seg1 = TransportCycle.SegmentIndexAt(def, phase1)
    local c1   = def.segColors[seg1]
    local lbl1 = TransportCycle.SegmentLabels(def)[seg1]
    vbar1.cursor:SetColorTexture(c1.r, c1.g, c1.b, 0.90)
    vbar1.cursor:ClearAllPoints()
    vbar1.cursor:SetPoint("CENTER", vbar1.overlay, "BOTTOM", 0, h1 * VBAR_H)
    vbar1.glow:SetColorTexture(c1.r, c1.g, c1.b, 0.25)
    vbar1.glow:ClearAllPoints()
    vbar1.glow:SetPoint("CENTER", vbar1.cursor, "CENTER")
    vbar1.phaseLbl:SetText(lbl1)
    vbar1.phaseLbl:SetTextColor(c1.r, c1.g, c1.b, 0.85)
    vbar1.phaseLbl:ClearAllPoints()
    vbar1.phaseLbl:SetPoint("LEFT", vbar1.cursor, "RIGHT", 4, 0)
    vbar1.timeLabel:SetText(string.format("%.1fs", def.cycleTime - phase1))

    -- Secondary bar (dimmer)
    local h2   = TransportCycle.LiftHeight(sd, phase2)
    local seg2 = TransportCycle.SegmentIndexAt(sd, phase2)
    local c2   = sd.segColors[seg2]
    local lbl2 = TransportCycle.SegmentLabels(sd)[seg2]
    vbar2.cursor:SetColorTexture(c2.r, c2.g, c2.b, 0.60)
    vbar2.cursor:ClearAllPoints()
    vbar2.cursor:SetPoint("CENTER", vbar2.overlay, "BOTTOM", 0, h2 * VBAR_H)
    vbar2.glow:SetColorTexture(c2.r, c2.g, c2.b, 0.12)
    vbar2.glow:ClearAllPoints()
    vbar2.glow:SetPoint("CENTER", vbar2.cursor, "CENTER")
    vbar2.phaseLbl:SetText(lbl2)
    vbar2.phaseLbl:SetTextColor(c2.r, c2.g, c2.b, 0.55)
    vbar2.phaseLbl:ClearAllPoints()
    vbar2.phaseLbl:SetPoint("RIGHT", vbar2.cursor, "LEFT", -4, 0)
    vbar2.timeLabel:SetText(string.format("%.1fs", sd.cycleTime - phase2))

    -- Source label
    local sl = dFrame.sourceLabel
    if st.lastSyncSource and st.lastSyncSource.name then
        sl:SetText("synced from " .. st.lastSyncSource.name)
        sl:SetTextColor(0.4, 0.8, 0.4)
    else
        sl:SetText("local sync")
        sl:SetTextColor(0.6, 0.8, 1)
    end
end
