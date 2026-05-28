-- TramUI.lua — Dual-track UI for the Deeprun Tram.
-- Init seam: TramUI.Init({ getState, getActiveID, onCalibrate, onDismiss })
-- Two stacked rows (NORTH / SOUTH cars). Each row: [IF btn][travel bar][SW btn].
-- Station-button click calibrates both tracks via a single lastSync write.
-- NORTH car uses primary phase; SOUTH car is inferred at phase + cycleTime/2.

local _, NS = ...
local TransportCycle = NS.TransportCycle
local LIFTS          = NS.LIFTS

local TramUI = {}
NS.TramUI = TramUI

-- ─── Constants ─────────────────────────────────────────────────────────────────

local PAD             = 12
local TRAM_BTN_W      = 40
local TRAM_BTN_H_FULL    = 22
local TRAM_BTN_H_COMPACT = 18

-- Travel bar inner width (frame inner width minus 2 buttons minus 2*gap)
local TRAM_BAR_H      = { full = 22, compact = 18 }
local BAR_W_FULL      = 460
local BAR_W_COMPACT   = 280
local GAP             = 4   -- px gap between button and travel bar edge
local TRAVEL_W        = {
    full    = BAR_W_FULL    - 2 * TRAM_BTN_W - 2 * GAP,  -- 376
    compact = BAR_W_COMPACT - 2 * TRAM_BTN_W - 2 * GAP,  -- 192
}
local FRAME_H         = { full = 168, compact = 90 }

-- ─── Init seam ─────────────────────────────────────────────────────────────────

local _getState, _getActiveID, _onCalibrate, _onDismiss

function TramUI.Init(deps)
    _getState    = deps.getState
    _getActiveID = deps.getActiveID
    _onCalibrate = deps.onCalibrate
    _onDismiss   = deps.onDismiss
end

-- ─── Frame state ───────────────────────────────────────────────────────────────

local tFrame             = nil
local currentMode        = "full"
local currentTransportID = nil

-- ─── Helpers ───────────────────────────────────────────────────────────────────

-- Returns position [0,1] of the tram car (0=IF end, 1=SW end) and the segment index.
-- Exposed on the module table so tests can reach it; the bar code below uses
-- the table form too (TramUI.TramCarPos) to keep one source of truth.
function TramUI.TramCarPos(def, phase)
    local segIdx    = TransportCycle.SegmentIndexAt(def, phase)
    local starts    = TransportCycle.SegmentStarts(def)
    local durations = TransportCycle.SegmentDurations(def)
    local rel       = (phase - starts[segIdx]) / durations[segIdx]
    -- Segments: 1=TO SW, 2=AT SW, 3=TO IF, 4=AT IF
    if     segIdx == 1 then return rel,       segIdx  -- heading SW: 0→1
    elseif segIdx == 2 then return 1.0,       segIdx  -- at SW: stay at 1
    elseif segIdx == 3 then return 1.0 - rel, segIdx  -- heading IF: 1→0
    else                    return 0.0,       segIdx  -- at IF: stay at 0
    end
end

-- Returns direction text and time-to-next-boundary for a given phase.
function TramUI.TramCarDir(def, phase)
    local segIdx = TransportCycle.SegmentIndexAt(def, phase)
    local ttb    = TransportCycle.SecondsToNextBoundary(def, phase)
    local dir
    if     segIdx == 1 then dir = "\xe2\x86\x92 SW"  -- → SW (UTF-8 arrow)
    elseif segIdx == 2 then dir = "depart SW"
    elseif segIdx == 3 then dir = "\xe2\x86\x92 IF"  -- → IF
    else                    dir = "depart IF"
    end
    return dir, ttb
end

local TramCarPos = TramUI.TramCarPos
local TramCarDir = TramUI.TramCarDir

-- ─── Frame construction (lazy) ─────────────────────────────────────────────────

local function BuildTrackRow(parent, rowLabel, rowY, carColor)
    local row = {}

    -- Row label (NORTH / SOUTH)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", PAD, rowY)
    lbl:SetText(rowLabel)
    lbl:SetTextColor(0.75, 0.75, 0.65)
    row.rowLabel = lbl

    -- Direction + countdown label (same line, after row label)
    local dirLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dirLbl:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    dirLbl:SetTextColor(1, 0.85, 0.4)
    row.dirLabel = dirLbl

    local barY = rowY - 14  -- bar sits below row label

    -- IF station button (left end)
    local ifBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ifBtn:SetSize(TRAM_BTN_W, TRAM_BTN_H_FULL)
    ifBtn:SetPoint("TOPLEFT", PAD, barY)
    ifBtn:SetText("IF")
    ifBtn:SetNormalFontObject("GameFontNormalSmall")
    row.ifBtn = ifBtn

    -- SW station button (right end)
    local swBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    swBtn:SetSize(TRAM_BTN_W, TRAM_BTN_H_FULL)
    swBtn:SetPoint("TOPRIGHT", -PAD, barY)
    swBtn:SetText("SW")
    swBtn:SetNormalFontObject("GameFontNormalSmall")
    row.swBtn = swBtn

    -- Travel bar background (stretches between the two buttons)
    local barBg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    barBg:SetPoint("TOPLEFT",     ifBtn, "TOPRIGHT",    GAP, 0)
    barBg:SetPoint("BOTTOMRIGHT", swBtn, "BOTTOMLEFT", -GAP, 0)
    barBg:SetBackdrop({ bgFile = "Interface/ChatFrame/ChatFrameBackground", tile = true, tileSize = 4 })
    barBg:SetBackdropColor(0.05, 0.05, 0.10, 0.90)
    row.barBg = barBg

    -- Car cursor on the travel bar
    local car = barBg:CreateTexture(nil, "OVERLAY")
    car:SetColorTexture(carColor.r, carColor.g, carColor.b, 0.90)
    car:SetSize(6, TRAM_BTN_H_FULL - 4)
    car:SetPoint("CENTER", barBg, "LEFT", 0, 0)
    row.car = car

    local carGlow = barBg:CreateTexture(nil, "OVERLAY")
    carGlow:SetColorTexture(carColor.r, carColor.g, carColor.b, 0.20)
    carGlow:SetSize(14, TRAM_BTN_H_FULL)
    carGlow:SetBlendMode("ADD")
    carGlow:SetPoint("CENTER", car, "CENTER")
    row.carGlow = carGlow

    row.barY = barY
    return row
end

local function BuildFrame()
    if tFrame then return end

    tFrame = CreateFrame("Frame", "AldorTaxTramUI", UIParent, "BackdropTemplate")
    tFrame:SetFrameStrata("MEDIUM")
    tFrame:SetMovable(true)
    tFrame:SetClampedToScreen(true)
    tFrame:EnableMouse(true)
    tFrame:RegisterForDrag("LeftButton")
    tFrame:SetScript("OnDragStart", tFrame.StartMoving)
    tFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AldorTaxDB then
            local point, _, relPoint, x, y = self:GetPoint(1)
            AldorTaxDB.barPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    tFrame:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    tFrame:SetBackdropBorderColor(0.40, 0.36, 0.22, 0.70)

    if AldorTaxDB and AldorTaxDB.barPos then
        local p = AldorTaxDB.barPos
        tFrame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        tFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    -- Title + close button
    local title = tFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -7)
    title:SetTextColor(1, 0.82, 0)
    tFrame.title = title

    local closeBtn = CreateFrame("Button", nil, tFrame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    closeBtn:SetFrameLevel(tFrame:GetFrameLevel() + 20)
    closeBtn:SetScript("OnClick", function() _onDismiss() end)

    -- Source label
    local sourceLabel = tFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceLabel:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, -3)
    sourceLabel:SetTextColor(0.6, 0.6, 0.6)
    tFrame.sourceLabel = sourceLabel

    -- Two track rows: NORTH (car A, orange) and SOUTH (car B, cyan)
    local northRow = BuildTrackRow(tFrame, "NORTH", -28,
        { r = 0.95, g = 0.65, b = 0.20 })
    local southRow = BuildTrackRow(tFrame, "SOUTH", -76,
        { r = 0.30, g = 0.75, b = 0.90 })
    tFrame.northRow = northRow
    tFrame.southRow = southRow

    -- Wire station buttons for both rows (calibrate via shared lastSync)
    local function wireButtons(row)
        row.ifBtn:SetScript("OnClick", function()
            local id = _getActiveID()
            if not id then return end
            local def = LIFTS[id]
            if not def then return end
            -- AT IF is segment 4; calibrate NORTH to that boundary
            local starts = TransportCycle.SegmentStarts(def)
            _onCalibrate(id, starts[4], "AT IF")
        end)
        row.swBtn:SetScript("OnClick", function()
            local id = _getActiveID()
            if not id then return end
            local def = LIFTS[id]
            if not def then return end
            -- AT SW is segment 2
            local starts = TransportCycle.SegmentStarts(def)
            _onCalibrate(id, starts[2], "AT SW")
        end)
        row.ifBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row.ifBtn, "ANCHOR_TOP")
            GameTooltip:SetText("Click when a car arrives at Ironforge", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        row.swBtn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row.swBtn, "ANCHOR_TOP")
            GameTooltip:SetText("Click when a car arrives at Stormwind", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        row.ifBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.swBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    wireButtons(northRow)
    wireButtons(southRow)

    -- Say Position button
    local sayBtn = CreateFrame("Button", nil, tFrame, "UIPanelButtonTemplate")
    sayBtn:SetSize(140, 22)
    sayBtn:SetPoint("BOTTOM", tFrame, "BOTTOM", 0, 8)
    sayBtn:SetText("Say Position")
    sayBtn:SetNormalFontObject("GameFontNormalSmall")
    sayBtn:SetScript("OnClick", function()
        local id = _getActiveID()
        if not id then return end
        local def = LIFTS[id]
        if not def then return end
        local states = _getState()
        local st     = states and states[id]
        if not st or st.lastSync <= 0 then return end

        local northPhase = (GetTime() - st.lastSync) % def.cycleTime
        local southPhase = (northPhase + def.cycleTime / 2) % def.cycleTime
        local nDir, nTtb = TramCarDir(def, northPhase)
        local sDir, sTtb = TramCarDir(def, southPhase)
        local msg = string.format("AldorTax: Tram | N: %s %ds | S: %s %ds",
            nDir, math.floor(nTtb + 0.5), sDir, math.floor(sTtb + 0.5))
        SendChatMessage(msg, "SAY")
        -- Update lastSayTime so the auto-thank handler can fire
        st.lastSayTime = GetTime()
    end)
    tFrame.sayBtn = sayBtn

    tFrame:SetSize(BAR_W_FULL + PAD * 2, FRAME_H.full)
    tFrame:Hide()
end

-- ─── Public API ────────────────────────────────────────────────────────────────

function TramUI.Show(transportID)
    BuildFrame()
    currentTransportID = transportID
    tFrame:Show()
end

function TramUI.Hide()
    if tFrame then tFrame:Hide() end
    currentTransportID = nil
end

function TramUI.IsShown()
    return tFrame ~= nil and tFrame:IsShown()
end

function TramUI.frame()
    return tFrame
end

function TramUI.SetMode(mode)
    if mode ~= "full" and mode ~= "compact" then mode = "full" end
    currentMode = mode
    BuildFrame()

    local bW  = (mode == "compact") and BAR_W_COMPACT or BAR_W_FULL
    local bH  = TRAM_BAR_H[mode]
    local fH  = FRAME_H[mode]

    tFrame:SetSize(bW + PAD * 2, fH)

    -- In compact: hide labels and say button; in full: show them
    local isCompact = mode == "compact"
    local function setRowCompact(row)
        row.rowLabel:SetShown(not isCompact)
        row.dirLabel:SetShown(not isCompact)
        row.ifBtn:SetSize(TRAM_BTN_W, bH)
        row.swBtn:SetSize(TRAM_BTN_W, bH)
        row.car:SetSize(6, bH - 4)
        row.carGlow:SetSize(14, bH)
    end
    if tFrame.northRow then setRowCompact(tFrame.northRow) end
    if tFrame.southRow then setRowCompact(tFrame.southRow) end
    if tFrame.sayBtn then tFrame.sayBtn:SetShown(not isCompact) end

    -- Reposition rows for compact (tighter spacing)
    if tFrame.northRow and tFrame.southRow then
        local rowYNorth = isCompact and -28 or -28  -- same Y, just height changes
        local rowYSouth = isCompact and -58 or -76
        -- reanchor north row bar
        tFrame.northRow.ifBtn:ClearAllPoints()
        tFrame.northRow.ifBtn:SetPoint("TOPLEFT", PAD, rowYNorth - 14)
        tFrame.northRow.swBtn:ClearAllPoints()
        tFrame.northRow.swBtn:SetPoint("TOPRIGHT", -PAD, rowYNorth - 14)
        -- reanchor south row bar
        tFrame.southRow.ifBtn:ClearAllPoints()
        tFrame.southRow.ifBtn:SetPoint("TOPLEFT", PAD, rowYSouth - 14)
        tFrame.southRow.swBtn:ClearAllPoints()
        tFrame.southRow.swBtn:SetPoint("TOPRIGHT", -PAD, rowYSouth - 14)
    end
end

function TramUI.ReconfigureTransport(transportID)
    BuildFrame()
    local def = LIFTS[transportID]
    if not def then return end
    currentTransportID = transportID
    tFrame.title:SetText(def.displayName .. "  |cff888888click station to sync|r")
end

function TramUI.UpdateCursor()
    if not tFrame or not tFrame:IsShown() or not currentTransportID then return end

    local states = _getState()
    local id     = _getActiveID()
    if not id or not states or id ~= currentTransportID then return end

    local st  = states[id]
    local def = LIFTS[id]
    if not st or not def then return end

    local travelW = TRAVEL_W[currentMode] or TRAVEL_W.full

    if st.lastSync > 0 then
        local northPhase = (GetTime() - st.lastSync) % def.cycleTime
        local southPhase = (northPhase + def.cycleTime / 2) % def.cycleTime

        local function updateRow(row, phase)
            local pos, _segIdx = TramCarPos(def, phase)
            local dir, ttb     = TramCarDir(def, phase)
            local carX         = pos * travelW

            row.car:ClearAllPoints()
            row.car:SetPoint("CENTER", row.barBg, "LEFT", carX, 0)
            row.carGlow:ClearAllPoints()
            row.carGlow:SetPoint("CENTER", row.car, "CENTER")
            row.dirLabel:SetText(string.format("%s  %ds", dir, math.floor(ttb + 0.5)))
        end

        if tFrame.northRow then updateRow(tFrame.northRow, northPhase) end
        if tFrame.southRow then updateRow(tFrame.southRow, southPhase) end
    else
        if tFrame.northRow then tFrame.northRow.dirLabel:SetText("no sync") end
        if tFrame.southRow then tFrame.southRow.dirLabel:SetText("no sync") end
    end

    -- Source label
    local sl = tFrame.sourceLabel
    if sl then
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
end
