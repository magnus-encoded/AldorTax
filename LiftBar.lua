-- LiftBar.lua — Segmented bar UI for vertical transports.
-- Init seam: LiftBar.Init({ getState, getActiveID, onCalibrate, onDismiss })
-- Handles single-platform (one cursor) and dual-platform lifts (two cursors).
-- Modes: "full" (on platform), "compact" (approaching).

local _, NS = ...
local TransportCycle = NS.TransportCycle
local LIFTS          = NS.LIFTS

local LiftBar = {}
NS.LiftBar = LiftBar

-- ─── Constants ─────────────────────────────────────────────────────────────────

local BAR_W_FULL    = 460
local BAR_W_COMPACT = 280
local BAR_H_FULL    = 28
local BAR_H_COMPACT = 22
local PAD           = 12
local FRAME_H       = { full = 94, compact = 50 }

-- Pure layout is delegated to TransportCycle.SegmentLayout (same algorithm,
-- reads the flat-field LIFTS model). The old per-widget SegmentLayout was
-- a duplicate that assumed a def.segments array; removed.

-- ─── Init seam ─────────────────────────────────────────────────────────────────

local _getState, _getActiveID, _onCalibrate, _onDismiss

function LiftBar.Init(deps)
    _getState    = deps.getState
    _getActiveID = deps.getActiveID
    _onCalibrate = deps.onCalibrate
    _onDismiss   = deps.onDismiss
end

-- ─── Frame state ───────────────────────────────────────────────────────────────

local barFrame           = nil
local currentMode        = "full"
local currentTransportID = nil
local barWidth           = BAR_W_FULL

-- ─── Frame construction (lazy) ─────────────────────────────────────────────────

local function BuildFrame()
    if barFrame then return end

    barFrame = CreateFrame("Frame", "AldorTaxLiftBar", UIParent, "BackdropTemplate")
    barFrame:SetFrameStrata("MEDIUM")
    barFrame:SetMovable(true)
    barFrame:SetClampedToScreen(true)
    barFrame:EnableMouse(true)
    barFrame:RegisterForDrag("LeftButton")
    barFrame:SetScript("OnDragStart", barFrame.StartMoving)
    barFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AldorTaxDB then
            local point, _, relPoint, x, y = self:GetPoint(1)
            AldorTaxDB.barPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    barFrame:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    barFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    barFrame:SetBackdropBorderColor(0.40, 0.36, 0.22, 0.70)

    if AldorTaxDB and AldorTaxDB.barPos then
        local p = AldorTaxDB.barPos
        barFrame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        barFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    -- Title
    local title = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -7)
    title:SetTextColor(1, 0.82, 0)
    barFrame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, barFrame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetFrameLevel(barFrame:GetFrameLevel() + 20)
    closeBtn:SetScript("OnClick", function() _onDismiss() end)
    barFrame.closeBtn = closeBtn

    -- Source label (sync attribution)
    local sourceLabel = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceLabel:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, -3)
    sourceLabel:SetTextColor(0.6, 0.6, 0.6)
    barFrame.sourceLabel = sourceLabel

    -- Segment bar background
    local barBg = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    barBg:SetPoint("TOPLEFT", PAD - 2, -24)
    barBg:SetSize(BAR_W_FULL + 4, BAR_H_FULL + 4)
    barBg:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    barBg:SetBackdropColor(0.02, 0.02, 0.04, 0.90)
    barBg:SetBackdropBorderColor(0.12, 0.12, 0.16, 0.70)
    barFrame.barBg = barBg

    -- Segment bar container (up to 4 segments supported)
    local bar = CreateFrame("Frame", nil, barFrame)
    bar:SetSize(BAR_W_FULL, BAR_H_FULL)
    bar:SetPoint("TOPLEFT", PAD, -26)
    barFrame.bar = bar

    local segBtns = {}
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        btn:SetSize(1, BAR_H_FULL)
        btn:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        btn.tex = tex

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER")
        lbl:SetTextColor(1, 1, 1, 0.9)
        btn.lbl = lbl

        local segIndex = i
        btn:SetScript("OnClick", function()
            local id = _getActiveID()
            if not id then return end
            local def = LIFTS[id]
            if not def or segIndex > 4 then return end
            local starts = TransportCycle.SegmentStarts(def)
            local labels = TransportCycle.SegmentLabels(def)
            _onCalibrate(id, starts[segIndex], labels[segIndex])
        end)
        btn:SetScript("OnEnter", function()
            local def  = currentTransportID and LIFTS[currentTransportID]
            local labels = def and TransportCycle.SegmentLabels(def)
            local name = (labels and labels[segIndex]) or ("SEG" .. segIndex)
            GameTooltip:SetOwner(btn, "ANCHOR_TOP")
            GameTooltip:SetText("Click to sync at " .. name, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        segBtns[i] = btn
    end
    barFrame.segBtns = segBtns

    -- Overlay for cursors (sits above buttons, non-interactive)
    local overlay = CreateFrame("Frame", nil, barFrame)
    overlay:SetSize(BAR_W_FULL, BAR_H_FULL)
    overlay:SetPoint("TOPLEFT", PAD, -26)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)
    overlay:EnableMouse(false)
    barFrame.overlay = overlay

    -- Primary cursor
    local cursorGlow = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    cursorGlow:SetColorTexture(1, 1, 1, 0.25)
    cursorGlow:SetSize(10, BAR_H_FULL + 8)
    cursorGlow:SetBlendMode("ADD")
    barFrame.cursorGlow = cursorGlow

    local cursor = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    cursor:SetColorTexture(1, 1, 1, 1)
    cursor:SetSize(4, BAR_H_FULL + 6)
    barFrame.cursor = cursor

    local timeLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetShadowOffset(1, -1)
    timeLabel:SetShadowColor(0, 0, 0, 1)
    barFrame.timeLabel = timeLabel

    -- Secondary cursor (dual-platform lifts, 50% alpha, thinner)
    local cursor2Glow = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    cursor2Glow:SetColorTexture(1, 1, 1, 0.12)
    cursor2Glow:SetSize(7, BAR_H_FULL + 6)
    cursor2Glow:SetBlendMode("ADD")
    barFrame.cursor2Glow = cursor2Glow

    local cursor2 = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    cursor2:SetColorTexture(1, 1, 1, 0.5)
    cursor2:SetSize(3, BAR_H_FULL + 4)
    barFrame.cursor2 = cursor2

    local timeLabel2 = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel2:SetAlpha(0.5)
    timeLabel2:SetShadowOffset(1, -1)
    timeLabel2:SetShadowColor(0, 0, 0, 1)
    barFrame.timeLabel2 = timeLabel2

    -- Say Warning button (full mode only; compact uses no say affordance to save space)
    local sayBtn = CreateFrame("Button", nil, barFrame, "UIPanelButtonTemplate")
    sayBtn:SetSize(130, 24)
    sayBtn:SetText("|cffffcc00Say Warning|r")
    sayBtn:SetNormalFontObject("GameFontNormalSmall")
    sayBtn:SetHighlightFontObject("GameFontHighlightSmall")
    sayBtn:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 8)
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
    barFrame.sayBtn = sayBtn

    barFrame:SetSize(BAR_W_FULL + PAD * 2, FRAME_H.full)
    barFrame:Hide()
end

-- ─── Public API ────────────────────────────────────────────────────────────────

function LiftBar.Show(transportID)
    BuildFrame()
    currentTransportID = transportID
    barFrame:Show()
end

function LiftBar.Hide()
    if barFrame then barFrame:Hide() end
    currentTransportID = nil
end

function LiftBar.IsShown()
    return barFrame ~= nil and barFrame:IsShown()
end

function LiftBar.frame()
    return barFrame
end

function LiftBar.SetMode(mode)
    if mode ~= "full" and mode ~= "compact" then mode = "full" end
    currentMode = mode
    BuildFrame()

    local bW = (mode == "compact") and BAR_W_COMPACT or BAR_W_FULL
    local bH = (mode == "compact") and BAR_H_COMPACT or BAR_H_FULL
    barWidth  = bW

    barFrame:SetSize(bW + PAD * 2, FRAME_H[mode])

    if mode == "compact" then
        -- Compact: strip chrome, move bar up (match legacy BuildSyncUI compact layout)
        barFrame.title:Hide()
        barFrame.sourceLabel:Hide()
        barFrame.sayBtn:Hide()
        barFrame.bar:ClearAllPoints()
        barFrame.bar:SetPoint("TOPLEFT", PAD, -12)
        barFrame.barBg:ClearAllPoints()
        barFrame.barBg:SetPoint("TOPLEFT", PAD - 2, -10)
        barFrame.overlay:ClearAllPoints()
        barFrame.overlay:SetPoint("TOPLEFT", PAD, -12)
    else
        barFrame.title:Show()
        barFrame.sourceLabel:Show()
        barFrame.sayBtn:Show()
        barFrame.bar:ClearAllPoints()
        barFrame.bar:SetPoint("TOPLEFT", PAD, -26)
        barFrame.barBg:ClearAllPoints()
        barFrame.barBg:SetPoint("TOPLEFT", PAD - 2, -24)
        barFrame.overlay:ClearAllPoints()
        barFrame.overlay:SetPoint("TOPLEFT", PAD, -26)
    end

    barFrame.barBg:SetSize(bW + 4, bH + 4)
    barFrame.bar:SetSize(bW, bH)
    barFrame.overlay:SetSize(bW, bH)
    barFrame.cursor:SetSize(4, bH + 6)
    barFrame.cursorGlow:SetSize(10, bH + 8)
    barFrame.cursor2:SetSize(3, bH + 4)
    barFrame.cursor2Glow:SetSize(7, bH + 6)
end

function LiftBar.ReconfigureTransport(transportID)
    BuildFrame()
    local def = LIFTS[transportID]
    if not def then return end
    currentTransportID = transportID

    local bH     = (currentMode == "compact") and BAR_H_COMPACT or BAR_H_FULL
    local rects  = TransportCycle.SegmentLayout(barWidth, def)
    local labels = TransportCycle.SegmentLabels(def)
    local colors = def.segColors

    barFrame.title:SetText(def.displayName .. "  |cff888888click phase to sync|r")

    for i = 1, 4 do
        local btn = barFrame.segBtns[i]
        local c   = colors[i]
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", barFrame.bar, "TOPLEFT", rects[i].x, 0)
        btn:SetSize(rects[i].w, bH)
        btn.tex:SetColorTexture(c.r, c.g, c.b, 0.85)
        if currentMode == "compact" then
            btn.lbl:Hide()
        else
            btn.lbl:SetText(labels[i])
            btn.lbl:Show()
        end
        btn:Show()
    end
end

function LiftBar.UpdateCursor()
    if not barFrame or not barFrame:IsShown() or not currentTransportID then return end

    local states = _getState()
    local id     = _getActiveID()
    if not id or not states or id ~= currentTransportID then return end

    local st  = states[id]
    local def = LIFTS[id]
    if not st or not def then return end

    -- Primary cursor
    if st.lastSync > 0 then
        local phase   = (GetTime() - st.lastSync) % def.cycleTime
        local x       = (phase / def.cycleTime) * barWidth
        local segIdx  = TransportCycle.SegmentIndexAt(def, phase)
        local c       = def.segColors[segIdx]
        local ttb     = TransportCycle.SecondsToNextBoundary(def, phase)

        barFrame.cursor:SetColorTexture(c.r, c.g, c.b, 1)
        barFrame.cursor:ClearAllPoints()
        barFrame.cursor:SetPoint("CENTER", barFrame.overlay, "LEFT", x, 0)
        barFrame.cursorGlow:SetColorTexture(c.r, c.g, c.b, 0.25)
        barFrame.cursorGlow:ClearAllPoints()
        barFrame.cursorGlow:SetPoint("CENTER", barFrame.overlay, "LEFT", x, 0)
        barFrame.timeLabel:SetText(string.format("%.1fs", ttb))
        barFrame.timeLabel:ClearAllPoints()
        barFrame.timeLabel:SetPoint("BOTTOM", barFrame.cursor, "TOP", 0, 2)
    else
        barFrame.cursor:Hide()
        barFrame.cursorGlow:Hide()
        barFrame.timeLabel:SetText("")
    end

    -- Secondary cursor: dual-platform lifts (not tram, which goes to TramUI).
    -- NOTE: Step 5b will split duallift defs out to the DualLiftBar widget;
    -- this branch is dead for now but kept until the router wires up that
    -- widget so single-lift behaviour stays bit-identical in the meantime.
    if def.dualLift and not def.horizontal and st.lastSync > 0 then
        local phase1   = (GetTime() - st.lastSync) % def.cycleTime
        local off      = def.dualOffset or (def.cycleTime / 2)
        local phase2   = (phase1 + off) % def.cycleTime
        local x2       = (phase2 / def.cycleTime) * barWidth
        local segIdx2  = TransportCycle.SegmentIndexAt(def, phase2)
        local c2       = def.segColors[segIdx2]
        local ttb2     = TransportCycle.SecondsToNextBoundary(def, phase2)

        barFrame.cursor2:SetColorTexture(c2.r, c2.g, c2.b, 0.5)
        barFrame.cursor2:ClearAllPoints()
        barFrame.cursor2:SetPoint("CENTER", barFrame.overlay, "LEFT", x2, 0)
        barFrame.cursor2Glow:SetColorTexture(c2.r, c2.g, c2.b, 0.12)
        barFrame.cursor2Glow:ClearAllPoints()
        barFrame.cursor2Glow:SetPoint("CENTER", barFrame.overlay, "LEFT", x2, 0)
        barFrame.timeLabel2:SetText(string.format("%.1fs", ttb2))
        barFrame.timeLabel2:ClearAllPoints()
        barFrame.timeLabel2:SetPoint("BOTTOM", barFrame.cursor2, "TOP", 0, 2)
        barFrame.cursor2:Show()
        barFrame.cursor2Glow:Show()
    else
        barFrame.cursor2:Hide()
        barFrame.cursor2Glow:Hide()
        barFrame.timeLabel2:SetText("")
    end

    -- Source label
    local sl = barFrame.sourceLabel
    if st.lastSyncSource and st.lastSyncSource.name then
        sl:SetText("synced from " .. st.lastSyncSource.name)
        sl:SetTextColor(0.4, 0.8, 0.4)
    elseif st.lastSync > 0 then
        sl:SetText("local sync")
        sl:SetTextColor(0.6, 0.8, 1)
    else
        sl:SetText("no sync")
        sl:SetTextColor(0.5, 0.5, 0.5)
    end
end
