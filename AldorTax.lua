-- ─── Top-of-screen blink warning ─────────────────────────────────────────────

local warnFrame = CreateFrame("Frame", "AldorTaxWarnFrame", UIParent)
warnFrame:SetSize(400, 100)
warnFrame:SetPoint("TOP", 0, -150)
warnFrame:Hide()
local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warnText:SetPoint("CENTER")
warnText:SetScale(2)

-- ─── Dev-mode timer overlay ──────────────────────────────────────────────────

local devTimerStart = nil -- GetTime() when dev mode was last enabled

local devTimerFrame = CreateFrame("Frame", "AldorTaxDevTimer", UIParent, "BackdropTemplate")
devTimerFrame:SetSize(160, 36)
devTimerFrame:SetPoint("TOP", 0, -10)
devTimerFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true, tileSize = 8 })
devTimerFrame:SetBackdropColor(0, 0, 0, 0.65)
devTimerFrame:SetMovable(true)
devTimerFrame:EnableMouse(true)
devTimerFrame:RegisterForDrag("LeftButton")
devTimerFrame:SetScript("OnDragStart", devTimerFrame.StartMoving)
devTimerFrame:SetScript("OnDragStop", devTimerFrame.StopMovingOrSizing)
devTimerFrame:Hide()

local devTimerText = devTimerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
devTimerText:SetPoint("CENTER")
devTimerText:SetTextColor(1, 1, 0)

devTimerFrame:SetScript("OnUpdate", function()
    if devTimerStart then
        local e = GetTime() - devTimerStart
        local m = math.floor(e / 60)
        local s = e % 60
        devTimerText:SetText(string.format("%d:%05.2f", m, s))
    end
end)

-- ─── Lift definitions ────────────────────────────────────────────────────────

local LIFTS = {
    aldor = {
        -- in Shattrath City, coords 32.6, 62.6
        id               = "aldor",
        displayName      = "Aldor Lift",
        settingsKey      = "enableAldor",
        fallTime         = 6.933, -- TransportAnimation 183169: 18.067s → 25.000s
        waitAtBottom     = 4.300, -- TransportAnimation 183169: 0s → 4.300s
        riseTime         = 8.067, -- TransportAnimation 183169: 4.300s → 12.367s
        waitAtTop        = 5.700, -- TransportAnimation 183169: 12.367s → 18.067s
        cycleTime        = 25.0,
        epochOffset      = 13.95, -- circular mean of 59 calibration clicks, sd 1.27s, span 5 days
        mapX             = 0.4169,
        mapY             = 0.3860,
        mapScale         = 1200, -- approximate zone width in yards
        nearYards        = 50,
        zones            = { ["Shattrath City"] = true },
        nearSubzones     = { ["Aldor Rise"] = true },
        approachSubzones = { ["Terrace of Light"] = true },
        deathZones       = { ["Shattrath City"] = true },
        segColors        = {
            { r = 0.85, g = 0.12, b = 0.10 },
            { r = 0.22, g = 0.42, b = 0.88 },
            { r = 0.95, g = 0.72, b = 0.08 },
            { r = 0.10, g = 0.78, b = 0.25 },
        },
    },
    stormspire = {
        id               = "stormspire",
        displayName      = "Stormspire Lift",
        settingsKey      = "enableStormspire",
        fallTime         = 7.0,    -- TransportAnimation 184330: 18.000s → 25.000s
        riseTime         = 8.0,    -- TransportAnimation 184330: 4.333s → 12.333s
        waitAtTop        = 5.667,  -- TransportAnimation 184330: 12.333s → 18.000s
        waitAtBottom     = 4.333,  -- TransportAnimation 184330: 0s → 4.333s
        cycleTime        = 25.0,
        epochOffset      = 11.5,   -- FALL events at serverTime%25≈11.5 (n=3, syncLog 04-10)
        mapX             = 0.426,
        mapY             = 0.336,
        mapScale         = 1200,
        nearYards        = 50,
        zones            = { ["Netherstorm"] = true },
        nearSubzones     = { ["The Stormspire"] = true },
        approachSubzones = { ["The Stormspire"] = true },
        deathZones       = { ["The Stormspire"] = true },
        segColors        = {
            { r = 0.70, g = 0.15, b = 0.65 }, -- falling: purple
            { r = 0.40, g = 0.20, b = 0.70 }, -- bottom: deep violet
            { r = 0.80, g = 0.45, b = 0.90 }, -- rising: lavender
            { r = 0.50, g = 0.30, b = 0.80 }, -- top: indigo
        },
    },
    deepruntram = {
        id           = "deepruntram",
        displayName  = "Deeprun Tram",
        settingsKey  = "enableTram",
        fallTime     = 58.5, -- travel IF -> SW
        waitAtBottom = 13.0, -- dwell at SW
        riseTime     = 58.5, -- travel SW -> IF
        waitAtTop    = 13.0, -- dwell at IF
        cycleTime    = 143.0,
        mapX         = 0,
        mapY         = 0,
        mapScale     = 1,
        nearYards    = 999, -- subzone detection only
        zones        = { ["Deeprun Tram"] = true },
        nearSubzones = { ["Deeprun Tram"] = true },
        deathZones   = nil,
        dualLift     = true,
        horizontal   = true,
        endpointA    = "IF",
        endpointB    = "SW",
        phaseNames   = { "TO SW", "AT SW", "TO IF", "AT IF" },
        segColors    = {
            { r = 0.75, g = 0.45, b = 0.20 }, -- traveling to SW (orange = destination)
            { r = 0.65, g = 0.55, b = 0.55 }, -- waiting at SW (warm gray)
            { r = 0.20, g = 0.45, b = 0.75 }, -- traveling to IF (blue = destination)
            { r = 0.55, g = 0.55, b = 0.65 }, -- waiting at IF (cool gray)
        },
    },
    greatlift = {
        id = "greatlift",
        displayName = "Great Lift",
        settingsKey = "enableGreatLift",
        fallTime = 10.0,    -- TransportAnimation 11898: 5.0s → 15.0s
        riseTime = 10.0,    -- TransportAnimation 11899: 5.0s → 15.0s
        waitAtTop = 5.0,    -- TransportAnimation: 0s → 5.0s
        waitAtBottom = 5.0, -- TransportAnimation: 15.0s → 20.0s
        cycleTime = 30.0,
        mapX = 0.3222,      -- midpoint of east/west for general proximity
        mapY = 0.2407,
        mapScale = 1000,
        nearYards = 60,
        coordZone = "Thousand Needles",
        zones = { ["Thousand Needles"] = true, ["The Barrens"] = true },
        nearSubzones = { ["The Great Lift"] = true, ["Freewind Post"] = true },
        deathZones = { ["Thousand Needles"] = true },
        dualLift = true, -- two complementary platforms, offset by half a cycle
        eastX = 0.3222,
        eastY = 0.2407,  -- east platform coords
        westX = 0.3169,
        westY = 0.2381,  -- west platform coords
        segColors = {
            { r = 0.55, g = 0.20, b = 0.18 },
            { r = 0.22, g = 0.35, b = 0.55 },
            { r = 0.60, g = 0.50, b = 0.18 },
            { r = 0.20, g = 0.48, b = 0.28 },
        },
    },
    ssc = {
        id           = "ssc",
        displayName  = "SSC Elevator",
        settingsKey  = "enableSSC",
        fallTime     = 16.5,    -- TransportAnimation 183407: 8.500s → 25.000s
        waitAtBottom = 5.0,     -- TransportAnimation 183407: 25.000s → 30.000s
        riseTime     = 13.333,  -- TransportAnimation 183407: 30.000s → 43.333s
        waitAtTop    = 8.5,     -- TransportAnimation 183407: 0s → 8.500s (includes door)
        cycleTime    = 43.333,
        mapX         = 0,
        mapY         = 0,
        mapScale     = 1,
        nearYards    = 999,  -- subzone detection only
        zones        = {
            ["Coilfang: Serpentshrine Cavern"] = true,
            ["Serpentshrine Cavern"] = true
        },
        nearSubzones = { ["Serpentshrine Cavern"] = true },
        deathZones   = {
            ["Coilfang: Serpentshrine Cavern"] = true,
            ["Serpentshrine Cavern"] = true
        },
        segColors    = {
            { r = 0.20, g = 0.50, b = 0.70 }, -- falling: deep water blue
            { r = 0.15, g = 0.35, b = 0.55 }, -- bottom: dark abyss
            { r = 0.30, g = 0.65, b = 0.80 }, -- rising: bright water
            { r = 0.25, g = 0.55, b = 0.65 }, -- top: surface blue
        },
    },
    tblift = {
        id            = "tblift",
        displayName   = "TB Lift",
        settingsKey   = "enableTBLift",
        fallTime      = 9.50,
        riseTime      = 9.50,
        waitAtTop     = 5.50,
        waitAtBottom  = 5.50,
        cycleTime     = 30.00,
        epochOffset   = 25.5, -- measured from timing samples
        mapX          = 0.318,
        mapY          = 0.626,
        mapScale      = 1000,
        nearYards     = 80,
        coordZone     = "Thunder Bluff",
        zones         = { ["Thunder Bluff"] = true, ["Mulgore"] = true },
        nearSubzones  = { ["Thunder Bluff"] = true },
        deathZones    = { ["Thunder Bluff"] = true, ["Mulgore"] = true },
        dualLift      = true,
        dualOffset    = -3.7, -- North leads South by 3.7s
        barLabel1     = "South",
        barLabel2     = "North",
        dualBgTexture = "Interface\\AddOns\\AldorTax\\tblift_south",
        segColors     = {
            { r = 0.65, g = 0.35, b = 0.15 },
            { r = 0.30, g = 0.35, b = 0.60 },
            { r = 0.70, g = 0.55, b = 0.12 },
            { r = 0.15, g = 0.55, b = 0.35 },
        },
    },
}

-- Remove lifts that don't exist in this client version
do
    local _, _, _, tocVersion = GetBuildInfo()
    -- Great Lift was destroyed in Cataclysm (4.0+); interface >= 40000
    if tocVersion and tocVersion >= 40000 then
        LIFTS.greatlift = nil
    end
end

-- ─── Fall-save spells ───────────────────────────────────────────────────────
-- Per-class abilities that can prevent fall death.  Ordered by priority:
--   free instant casts > cheap reagent casts > gold-cost consumables.
-- reagent = item ID required before Cata (nil if none).
-- item    = consumable item to use (checked via GetItemCount).

local NOGGENFOGGER = { item = 8529, spell = "Noggenfogger Elixir" } -- last resort (costs gold, random effect)

do
    local _, _, _, tocVersion = GetBuildInfo()
    local preCata = not tocVersion or tocVersion < 40000 -- Light Feather required before 4.0

    -- minToc: minimum interface version for the spell to be a valid fall save.
    -- Spells below this version are filtered out after the table is built.
    local allSaves = {
        MAGE        = {
            { spell = "Slow Fall", reagent = preCata and 17056 or nil },
            { spell = "Blink" },
            NOGGENFOGGER,
        },
        PRIEST      = {
            { spell = "Levitate", reagent = preCata and 17056 or nil },
            NOGGENFOGGER,
        },
        PALADIN     = {
            { spell = "Divine Shield" },
            { spell = "Blessing of Protection" },
            NOGGENFOGGER,
        },
        HUNTER      = {
            { spell = "Disengage", minToc = 30000 }, -- resets fall in WotLK+; melee-only in TBC
            NOGGENFOGGER,
        },
        WARRIOR     = {
            { spell = "Heroic Leap", minToc = 40000 }, -- Cata+
            NOGGENFOGGER,
        },
        DEMONHUNTER = {
            { spell = "Glide" },
            { spell = "Fel Rush" },
        },
        MONK        = {
            { spell = "Zen Flight" },
            { spell = "Roll" },
            NOGGENFOGGER,
        },
        EVOKER      = {
            { spell = "Hover" },
        },
        DRUID       = {
            { spell = "Cat Form" }, -- passive fall damage reduction
            NOGGENFOGGER,
        },
        -- Classes with no mitigation get Noggenfogger as sole option
        ROGUE       = { NOGGENFOGGER },
        WARLOCK     = { NOGGENFOGGER },
        SHAMAN      = { NOGGENFOGGER },
        DEATHKNIGHT = { NOGGENFOGGER },
    }

    -- Strip saves that don't exist in this client version
    FALL_SAVES = {}
    for class, list in pairs(allSaves) do
        local filtered = {}
        for _, entry in ipairs(list) do
            if not entry.minToc or (tocVersion and tocVersion >= entry.minToc) then
                filtered[#filtered + 1] = entry
            end
        end
        FALL_SAVES[class] = filtered
    end
end

-- ── Fall-save alert frame ───────────────────────────────────────────────────
-- A SecureActionButton so the player can click to cast.  Attributes are set
-- outside combat (falling off a lift ≠ combat) before the frame is shown.

local fallSaveFrame = CreateFrame("Button", "AldorTaxFallSave", UIParent, "SecureActionButtonTemplate")
fallSaveFrame:SetSize(260, 52)
fallSaveFrame:SetPoint("CENTER", 0, 100)
fallSaveFrame:SetFrameStrata("DIALOG")
fallSaveFrame:Hide()
fallSaveFrame:RegisterForClicks("LeftButtonUp")

do -- backdrop
    local bg = fallSaveFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)
end

local fallSaveIcon = fallSaveFrame:CreateTexture(nil, "ARTWORK")
fallSaveIcon:SetSize(36, 36)
fallSaveIcon:SetPoint("LEFT", 8, 0)

local fallSaveText = fallSaveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fallSaveText:SetPoint("LEFT", fallSaveIcon, "RIGHT", 10, 0)
fallSaveText:SetTextColor(1, 0.3, 0.1)

local fallSaveNoSpell = fallSaveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fallSaveNoSpell:SetPoint("CENTER")
fallSaveNoSpell:SetTextColor(1, 0, 0)

local fallSaveShown  = false -- true while the alert is visible
local fallSaveHideAt = 0     -- GetTime() when we auto-dismiss
local wasFalling     = false -- edge detection for IsFalling()

-- Find the best usable fall-save for the player's class.
-- Returns name, texture, actionType ("spell" or "item")  or  nil, nil, nil
local function FindBestFallSave()
    local _, classToken = UnitClass("player")
    local saves = FALL_SAVES[classToken]
    if not saves then return nil, nil, nil end

    for _, entry in ipairs(saves) do
        if entry.item then
            -- Consumable item (e.g. Noggenfogger Elixir)
            if GetItemCount(entry.item) > 0 then
                local name, _, _, _, _, _, _, _, _, tex = GetItemInfo(entry.item)
                if name then
                    return name, tex, "item"
                end
            end
        else
            -- Learned spell
            local usable = IsUsableSpell(entry.spell)
            if usable then
                if entry.reagent and GetItemCount(entry.reagent) == 0 then
                    -- skip: no reagents
                else
                    local start, dur = GetSpellCooldown(entry.spell)
                    local remaining = (start and dur and start > 0) and (start + dur - GetTime()) or 0
                    if remaining <= 0 then
                        local tex = GetSpellTexture(entry.spell)
                        return entry.spell, tex, "spell"
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

local function ShowFallSaveAlert()
    local name, tex, actionType = FindBestFallSave()
    if name then
        fallSaveIcon:SetTexture(tex)
        fallSaveIcon:Show()
        fallSaveText:SetText(name)
        fallSaveText:Show()
        fallSaveNoSpell:Hide()
        if not InCombatLockdown() then
            fallSaveFrame:SetAttribute("type", actionType)
            fallSaveFrame:SetAttribute(actionType, name)
        end
    else
        -- No save available — show a plain warning
        fallSaveIcon:Hide()
        fallSaveText:Hide()
        fallSaveNoSpell:SetText("FALLING!")
        fallSaveNoSpell:Show()
        if not InCombatLockdown() then
            fallSaveFrame:SetAttribute("type", nil)
        end
    end
    fallSaveFrame:SetAlpha(1)
    fallSaveFrame:Show()
    fallSaveShown = true
    fallSaveHideAt = GetTime() + 4
end

local function HideFallSaveAlert()
    if fallSaveShown then
        fallSaveFrame:Hide()
        fallSaveShown = false
    end
end

-- ─── Shared config ───────────────────────────────────────────────────────────

local APPROACH_WARNING_TIME = 10.0
local CLICK_REACTION_TIME   = 0.2

local ADDON_PREFIX          = "ALDORTAX"
local MSG_VERSION           = 5
local SOFT_BLOCK_THRESHOLD  = 3
local HARD_BLOCK_THRESHOLD  = 6

-- ─── Per-lift state ──────────────────────────────────────────────────────────

local liftState             = {}

local function InitLiftState(id)
    liftState[id] = {
        lastSync          = 0,
        lastSync2         = 0,   -- independent sync for secondary platform (dual lifts)
        lastSyncSource    = nil,
        syncOrigin        = nil, -- "C" = calibrated first-hand, "R" = relayed
        lastAutoBroadcast = 0,
        lastSayTime       = 0,
        isNearLift        = nil,
    }
end

for id in pairs(LIFTS) do InitLiftState(id) end

local activeLiftID             = nil -- which lift the player is currently near

-- ─── Shared state ────────────────────────────────────────────────────────────

local realTimeOffset           = nil
local serverTimeOffset         = nil -- GetServerTime() - GetTime(), calibrated once at login
local AUTO_BROADCAST_INTERVAL  = 45
local ZONE_SEND_COOLDOWN       = 5   -- seconds after zoning before we send addon messages
local zonedInAt                = 0   -- GetTime() when we last zoned into a lift area
local lastProximityCheck       = 0
local PROXIMITY_CHECK_INTERVAL = 1.0

-- User settings (persisted in AldorTaxDB.settings)
local settings                 = {
    autoThank        = true,
    devTools         = false,
    debugChannel     = false,
    verbose          = false,
    segmentInput     = false,
    alwaysShowUI     = false,
    alwaysCompact    = false,
    enableAldor      = true,
    enableGreatLift  = true,
    enableTram       = false,
    enableTBLift     = false,
    enableStormspire = false,
    enableSSC        = false,
    fallSaveAlert    = false,
}

local BuildOptionsPanel -- forward declaration

-- ─── Copyable log ─────────────────────────────────────────────────────────────

local LOG_MAX                  = 500
local logLines                 = {}
local logEB                    = nil

local function Log(msg)
    if settings.verbose then print(msg) end
    -- Strip WoW color codes for the copyable log editbox
    local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local stamp = string.format("[%.1f] ", GetTime())
    table.insert(logLines, stamp .. clean)
    if #logLines > LOG_MAX then table.remove(logLines, 1) end
    if logEB then
        logEB:SetText(table.concat(logLines, "\n"))
        logEB:SetCursorPosition(0)
    end
end

-- ─── Real-time calibration ──────────────────────────────────────────────────
-- Calibrate by waiting for GetServerTime() to tick.  At the tick boundary the
-- true server time is very close to the new integer value, so the offset is
-- accurate to within one frame (~16 ms) rather than the ~1 s error you get
-- from sampling GetServerTime() at an arbitrary moment.

do
    local prevSrv = GetServerTime()
    local f       = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local srv = GetServerTime()
        -- Wait for GetServerTime() tick — gives sub-frame server-time precision
        if srv > prevSrv then
            serverTimeOffset = srv - GetTime()
            -- ±1 s is fine for display-only local time
            realTimeOffset = time() - GetTime()
            self:SetScript("OnUpdate", nil)
            -- Restore saved syncs for all lifts
            if AldorTaxDB and AldorTaxDB.lifts then
                for id, dbLift in pairs(AldorTaxDB.lifts) do
                    if dbLift.lastSyncRealTime and liftState[id] then
                        local elapsed = (GetTime() + realTimeOffset) - dbLift.lastSyncRealTime
                        liftState[id].lastSync = GetTime() - elapsed
                        liftState[id].lastSyncSource = nil
                    end
                end
            end
        end
        prevSrv = srv
    end)
end

local function GetRealTime()
    return realTimeOffset and (GetTime() + realTimeOffset) or time()
end

-- Smooth absolute time: GetTime() precision + GetServerTime() epoch
local function GetAbsoluteTime()
    return serverTimeOffset and (GetTime() + serverTimeOffset) or GetServerTime()
end

-- ─── Lift detection ─────────────────────────────────────────────────────────

local function GetPlayerMapPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil, nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, nil end
    local px, py = pos:GetXY()
    if not px or not py or (px == 0 and py == 0) then return nil, nil end
    return px, py
end

local function CheckNearLiftCoords(def)
    -- Skip coordinate check if we're in the wrong zone (map coords won't match)
    if def.coordZone and def.coordZone ~= GetZoneText() then return false end
    local px, py = GetPlayerMapPos()
    if not px then return nil end
    local nearFrac = def.nearYards / def.mapScale
    if def.dualLift and def.eastX then
        local dxE = px - def.eastX
        local dyE = py - def.eastY
        local dxW = px - def.westX
        local dyW = py - def.westY
        return math.min((dxE * dxE + dyE * dyE) ^ 0.5, (dxW * dxW + dyW * dyW) ^ 0.5) <= nearFrac
    end
    local dx = px - def.mapX
    local dy = py - def.mapY
    return (dx * dx + dy * dy) ^ 0.5 <= nearFrac
end

local function CheckNearLift(def)
    -- Instance zones (e.g. Deeprun Tram): always near if we detected the zone
    if def.zones[GetZoneText()] and (not def.mapX or def.mapX == 0) then return true end
    local subzone = GetSubZoneText()
    if def.nearSubzones[subzone] then return true end
    return CheckNearLiftCoords(def) == true
end

local function CheckApproachLift(def)
    if not def.approachSubzones then return false end
    return def.approachSubzones[GetSubZoneText()] == true
end


local function DetectActiveLift()
    local zone = GetZoneText()
    for id, def in pairs(LIFTS) do
        if def.zones[zone] then
            if def.settingsKey and not settings[def.settingsKey] then
                -- Skip lifts disabled in settings
            elseif CheckNearLift(def) or CheckApproachLift(def) then
                return id
            end
        end
    end
    return nil
end

-- ─── Sync persistence ───────────────────────────────────────────────────────

local function SaveSync(liftID, sourceName, sourceRealm, realTime)
    if not AldorTaxDB then return end
    if not AldorTaxDB.lifts then AldorTaxDB.lifts = {} end
    if not AldorTaxDB.lifts[liftID] then AldorTaxDB.lifts[liftID] = {} end
    local dbLift = AldorTaxDB.lifts[liftID]
    local st = liftState[liftID]
    local realNow = realTime or GetRealTime()
    dbLift.lastSyncRealTime = realNow
    st.lastSyncSource = sourceName and { name = sourceName, realm = sourceRealm or "" } or nil
    dbLift.lastSyncSource = st.lastSyncSource
    -- Local calibrations (no source) are first-hand; keep existing origin for remote syncs
    if not sourceName then st.syncOrigin = "C" end
end

local SYNC_LOG_MAX = 200

local function AppendSyncLog(entry)
    if not AldorTaxDB then return end
    if not AldorTaxDB.syncLog then AldorTaxDB.syncLog = {} end
    table.insert(AldorTaxDB.syncLog, entry)
    if #AldorTaxDB.syncLog > SYNC_LOG_MAX then table.remove(AldorTaxDB.syncLog, 1) end
end

-- ─── Timing diagnostics ────────────────────────────────────────────────────
-- Compact per-lift timing samples for validating cycle time and segment lengths.
-- Each sample: { serverTime, epochOffset, correction, label }
-- Stored in AldorTaxDB.timing[liftID] and survives sync log rotation.

local TIMING_SAMPLE_MAX = 500

local function RecordTimingSample(liftID, serverTime, epochOffset, correction, label)
    if not AldorTaxDB then return end
    if not AldorTaxDB.timing then AldorTaxDB.timing = {} end
    if not AldorTaxDB.timing[liftID] then AldorTaxDB.timing[liftID] = {} end
    local t = AldorTaxDB.timing[liftID]
    t[#t + 1] = { serverTime, epochOffset, correction, label }
    if #t > TIMING_SAMPLE_MAX then table.remove(t, 1) end
end

-- Analyze timing samples for a lift. Returns a table with diagnostics:
--   n, timeSpan, meanEpoch, stdEpoch, driftPerHour, impliedCycleError,
--   segments = { [label] = { n, meanCorr, stdCorr } }
local function AnalyzeTiming(liftID)
    if not AldorTaxDB or not AldorTaxDB.timing then return nil end
    local samples = AldorTaxDB.timing[liftID]
    if not samples or #samples < 2 then return nil end
    local def = LIFTS[liftID]
    if not def then return nil end

    local n = #samples
    local cycle = def.cycleTime
    local twoPi = 2 * math.pi

    -- Circular mean of epoch offset (handles wrap at cycleTime)
    local sumSin, sumCos = 0, 0
    for i = 1, n do
        local angle = samples[i][2] * twoPi / cycle
        sumSin = sumSin + math.sin(angle)
        sumCos = sumCos + math.cos(angle)
    end
    local meanAngle = math.atan2(sumSin / n, sumCos / n)
    if meanAngle < 0 then meanAngle = meanAngle + twoPi end
    local meanEpoch = meanAngle * cycle / twoPi

    -- Circular standard deviation
    local R = math.sqrt((sumSin / n) ^ 2 + (sumCos / n) ^ 2)
    local stdEpoch = (R < 1) and math.sqrt(-2 * math.log(R)) * cycle / twoPi or 0

    -- Drift detection: unwrap epoch offsets relative to meanEpoch, then
    -- linear regression of unwrapped offset vs serverTime.
    -- Unwrap: offset_i = ((raw - meanEpoch + half) % cycle) - half + meanEpoch
    local half = cycle / 2
    local sumT, sumY, sumTY, sumT2 = 0, 0, 0, 0
    local t0 = samples[1][1] -- reference time for numerical stability
    for i = 1, n do
        local t         = samples[i][1] - t0
        local raw       = samples[i][2]
        local unwrapped = ((raw - meanEpoch + half) % cycle) - half + meanEpoch
        sumT            = sumT + t
        sumY            = sumY + unwrapped
        sumTY           = sumTY + t * unwrapped
        sumT2           = sumT2 + t * t
    end
    local denom = n * sumT2 - sumT * sumT
    local driftPerSec = (denom ~= 0) and (n * sumTY - sumT * sumY) / denom or 0
    local driftPerHour = driftPerSec * 3600
    -- Drift per cycle = driftPerSec * cycleTime → implied true cycle = cycle + drift_per_cycle
    local impliedCycleError = driftPerSec * cycle

    -- Per-segment correction statistics
    local segData = {}
    for i = 1, n do
        local corr = samples[i][3]
        local label = samples[i][4]
        if corr ~= 0 or label then -- skip samples without a correction (first click)
            local key = label or "?"
            if not segData[key] then segData[key] = { n = 0, sum = 0, sumSq = 0 } end
            local s = segData[key]
            s.n = s.n + 1
            s.sum = s.sum + corr
            s.sumSq = s.sumSq + corr * corr
        end
    end
    local segments = {}
    for label, s in pairs(segData) do
        local mean = s.sum / s.n
        local variance = (s.n > 1) and (s.sumSq / s.n - mean * mean) or 0
        segments[label] = { n = s.n, meanCorr = mean, stdCorr = math.sqrt(math.max(0, variance)) }
    end

    local timeSpan = samples[n][1] - samples[1][1]

    return {
        n = n,
        timeSpan = timeSpan,
        meanEpoch = meanEpoch,
        stdEpoch = stdEpoch,
        driftPerHour = driftPerHour,
        impliedCycleError = impliedCycleError,
        segments = segments,
    }
end

-- Log how much a local calibration click shifts the predicted phase.
-- Called just before st.lastSync is overwritten.
-- label: segment name from the click (e.g. "FALL", "BOTTOM")
local function LogSyncCorrection(liftID, newSyncTime, label)
    local st  = liftState[liftID]
    local def = LIFTS[liftID]
    if not st or not def or st.lastSync <= 0 then return end
    local oldPhase = (GetTime() - st.lastSync) % def.cycleTime
    local newPhase = (GetTime() - newSyncTime) % def.cycleTime
    local correction = newPhase - oldPhase
    -- Wrap to [-halfCycle, +halfCycle]
    local half = def.cycleTime / 2
    if correction > half then correction = correction - def.cycleTime end
    if correction < -half then correction = correction + def.cycleTime end
    -- Log epoch offset in absolute (server) time so it's comparable across reboots
    local absSync = newSyncTime + (serverTimeOffset or 0)
    local epochOffset = absSync % def.cycleTime
    AppendSyncLog(string.format(
        "%s|%s|CORRECTION|%.3f|%.3f|%.3f",
        date("%Y-%m-%d %H:%M:%S"), liftID, GetServerTime(), correction, epochOffset))
    RecordTimingSample(liftID, GetServerTime(), epochOffset, correction, label)
    Log(string.format("AldorTax: sync correction: %+.3fs (server epoch offset: %.3f)", correction, epochOffset))
end

local function ApplyEpochAnchor(id)
    local def = LIFTS[id]
    if not def or not def.epochOffset then return end
    local st = liftState[id]
    if not st then return end
    local absNow = GetAbsoluteTime()
    st.lastSync = GetTime() - ((absNow - def.epochOffset) % def.cycleTime)
    st.lastSyncSource = nil
    Log(string.format("AldorTax: %s auto-synced via epoch anchor (abs=%.1f)", def.displayName, absNow))
end

local function RestoreSync()
    -- Epoch-anchored lifts: always apply (no persistence needed)
    for id, def in pairs(LIFTS) do
        if def.epochOffset then
            ApplyEpochAnchor(id)
        end
    end
    -- Persisted syncs for non-anchored lifts
    if not AldorTaxDB or not AldorTaxDB.lifts or not realTimeOffset then return end
    for id, dbLift in pairs(AldorTaxDB.lifts) do
        local def = LIFTS[id]
        if dbLift.lastSyncRealTime and liftState[id] and not (def and def.epochOffset) then
            local elapsed = GetRealTime() - dbLift.lastSyncRealTime
            liftState[id].lastSync = GetTime() - elapsed
            liftState[id].lastSyncSource = nil
        end
    end
end

-- ─── Trust / blocklist ──────────────────────────────────────────────────────

local function BlockKey(name, realm) return name .. "-" .. realm end

local function GetDeathCount(name, realm)
    if not AldorTaxDB or not AldorTaxDB.blocklist then return 0 end
    return AldorTaxDB.blocklist[BlockKey(name, realm)] or 0
end

local function IsSoftBlocked(name, realm) return GetDeathCount(name, realm) >= SOFT_BLOCK_THRESHOLD end
local function IsHardBlocked(name, realm) return GetDeathCount(name, realm) >= HARD_BLOCK_THRESHOLD end

local function RecordDeathReport(name, realm)
    if not AldorTaxDB then return end
    if not AldorTaxDB.blocklist then AldorTaxDB.blocklist = {} end
    local key                 = BlockKey(name, realm)
    local count               = (AldorTaxDB.blocklist[key] or 0) + 1
    AldorTaxDB.blocklist[key] = count
    if count == SOFT_BLOCK_THRESHOLD then
        print(string.format("|cffff6600AldorTax: %s has %d death reports — syncs ignored.|r", key, count))
    elseif count == HARD_BLOCK_THRESHOLD then
        print(string.format("|cffff0000AldorTax: %s hard-blocked (%d deaths).|r", key, count))
    end
    return count
end

-- ─── Addon messaging ────────────────────────────────────────────────────────

local prefixRegistered = false

local function RegisterPrefix()
    local ok
    if C_ChatInfo then
        ok = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    elseif RegisterAddonMessagePrefix then
        ok = RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
    prefixRegistered = ok and ok ~= false and ok ~= 0
    if prefixRegistered then
        Log("|cff00ff00AldorTax: prefix registered OK (ok=" .. tostring(ok) .. ").|r")
    else
        Log("|cffffff00AldorTax: prefix registration returned " ..
            tostring(ok) .. " — will attempt messaging regardless.|r")
        prefixRegistered = true
    end
end

-- Returns the channel number for General (localized), or nil if unavailable.
-- On Classic TBC+ General is zone-scoped, so addon messages sent here
-- only reach players in the same zone — ideal for lift sync.
local function GetGeneralChannelNum()
    if EnumerateServerChannels then
        local general = EnumerateServerChannels() -- first return is General
        if general then
            local num = GetChannelName(general)
            if num and num > 0 then return num end
        end
    end
    return nil
end

local function RawSend(msg, chatType, target)
    local ok, err
    if ChatThrottleLib then
        -- Use CTL: time-sensitive sync data goes as ALERT priority
        ok, err = pcall(ChatThrottleLib.SendAddonMessage, ChatThrottleLib,
            "ALERT", ADDON_PREFIX, msg, chatType, target)
    elseif C_ChatInfo then
        ok, err = pcall(C_ChatInfo.SendAddonMessage, ADDON_PREFIX, msg, chatType, target)
    else
        ok, err = pcall(SendAddonMessage, ADDON_PREFIX, msg, chatType, target)
    end
    if not ok then
        Log(string.format("|cffff0000AldorTax: send failed (%s, %s): %s|r", chatType, tostring(target), tostring(err)))
    end
    return ok
end

local lastNoChannelWarn = 0

local function SendMsg(msg)
    local sent = false
    -- General channel (zone-scoped on Classic TBC+)
    local generalNum = GetGeneralChannelNum()
    if generalNum then
        if RawSend(msg, "CHANNEL", generalNum) then sent = true end
    end
    -- Guild
    if IsInGuild() then
        if RawSend(msg, "GUILD") then sent = true end
    end
    -- Party / Raid
    if UnitInRaid("player") then
        if RawSend(msg, "RAID") then sent = true end
    elseif GetNumGroupMembers and GetNumGroupMembers() > 0 then
        if RawSend(msg, "PARTY") then sent = true end
    end
    if settings.debugChannel then
        Log("|cff88aaff[SYNC OUT] " .. msg:gsub("|", "||") .. "|r")
    end
    if not sent then
        local now = GetTime()
        if now - lastNoChannelWarn > 60 then
            lastNoChannelWarn = now
            Log("|cffffff00AldorTax: no channel to send on (solo)|r")
        end
    end
end

local function BroadcastSync(liftID, realTime)
    if GetTime() - zonedInAt < ZONE_SEND_COOLDOWN then return end
    local def = LIFTS[liftID]
    if not def then return end
    local st       = liftState[liftID]
    local name     = UnitName("player") or "Unknown"
    local realm    = GetRealmName() or ""
    local rt       = realTime
        or (AldorTaxDB and AldorTaxDB.lifts and AldorTaxDB.lifts[liftID]
            and AldorTaxDB.lifts[liftID].lastSyncRealTime)
        or GetRealTime()
    local phase    = rt % def.cycleTime
    -- origin: "C" if we calibrated this ourselves, "R" if relaying someone else's sync
    local origin   = (realTime or not st.lastSyncSource) and "C" or "R"
    -- Server-time phase: shared ground truth across all clients regardless of local clock
    local absRT    = realTime and (realTime - realTimeOffset + (serverTimeOffset or 0))
        or GetAbsoluteTime()
    local srvPhase = absRT % def.cycleTime
    -- v5: S|ver|liftID|phase|name|realm|fall|bottom|rise|top|origin|srvPhase
    -- phase (field 3) kept for v3/v4 compat; v5 receivers prefer srvPhase (field 11)
    SendMsg(string.format("S|%d|%s|%.3f|%s|%s|%.3f|%.3f|%.3f|%.3f|%s|%.3f",
        MSG_VERSION, liftID, phase, name, realm,
        def.fallTime, def.waitAtBottom, def.riseTime, def.waitAtTop, origin, srvPhase))
end

local function BroadcastDied(liftID)
    if not AldorTaxDB or not AldorTaxDB.lifts then return end
    local dbLift = AldorTaxDB.lifts[liftID]
    if not dbLift or not dbLift.lastSyncRealTime then return end
    local st = liftState[liftID]
    if not st.lastSyncSource then return end
    local def = LIFTS[liftID]
    local phase = dbLift.lastSyncRealTime % def.cycleTime
    -- v5: D|ver|liftID|phase|name|realm|origin
    local origin = st.syncOrigin or "C"
    SendMsg(string.format("D|%d|%s|%.3f|%s|%s|%s",
        MSG_VERSION, liftID, phase, st.lastSyncSource.name, st.lastSyncSource.realm, origin))
end

local function ApplyRemoteSync(liftID, phase, name, realm, fall, bottom, rise, top, srvPhase)
    if not realTimeOffset then return end
    local def = LIFTS[liftID]
    if not def then return end
    local st = liftState[liftID]
    local cycle_s = (fall and bottom and rise and top)
        and (fall + bottom + rise + top)
        or def.cycleTime
    -- Compensate for network latency: the message was current when it left
    -- the sender's client, but took ~latency ms to reach us via the server
    -- GetNetStats: TBC+ returns (bwIn, bwOut, latencyHome, latencyWorld);
    -- Vanilla Era returns (bwIn, bwOut, latency). Prefer world latency if present.
    local _, _, latencyHome, latencyWorld = GetNetStats()
    local netDelay = ((latencyWorld or latencyHome) or 0) / 1000 -- ms → seconds
    -- Prefer server-time phase if available (v5); fall back to local-time phase (v3/v4)
    local elapsedInCycle
    if srvPhase and serverTimeOffset then
        local nowAbs = GetAbsoluteTime() - netDelay
        elapsedInCycle = (nowAbs % cycle_s - srvPhase + cycle_s) % cycle_s
    else
        local nowReal = GetRealTime() - netDelay
        elapsedInCycle = (nowReal % cycle_s - phase + cycle_s) % cycle_s
    end
    st.lastSync       = GetTime() - elapsedInCycle
    st.lastSyncSource = { name = name, realm = realm }
    if AldorTaxDB then
        if not AldorTaxDB.lifts then AldorTaxDB.lifts = {} end
        if not AldorTaxDB.lifts[liftID] then AldorTaxDB.lifts[liftID] = {} end
        AldorTaxDB.lifts[liftID].lastSyncRealTime = GetRealTime() - elapsedInCycle
        AldorTaxDB.lifts[liftID].lastSyncSource   = st.lastSyncSource
    end
end

local function HandleAddonMessage(prefix, message, chatType, sender)
    if prefix ~= ADDON_PREFIX then return end
    local msgType = message:sub(1, 1)

    local myName = UnitName("player")
    local isSelf = sender and (sender == myName or sender:match("^" .. myName .. "%-"))

    if msgType == "T" then
        Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender),
            tostring(message):gsub("|", "||")))
        Log("|cff00ff00AldorTax: TEST MESSAGE RECEIVED OK — addon messaging is working.|r")
        return
    end

    if isSelf then return end -- always ignore own echoes (guild/General reflect back)

    Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender),
        tostring(message):gsub("|", "||")))
    local parts = {}
    for p in message:sub(3):gmatch("[^|]+") do parts[#parts + 1] = p end

    local ver = tonumber(parts[1])
    if not ver or ver > MSG_VERSION then
        Log("|cffffff00AldorTax: ignoring message with unknown version " .. tostring(parts[1]) .. "|r")
        return
    end

    -- v5: S|ver|liftID|phase|name|realm|fall|bottom|rise|top|origin|srvPhase
    -- v4: S|ver|liftID|phase|name|realm|fall|bottom|rise|top
    -- v3: S|ver|phase|name|realm|fall|bottom|rise|top  (assumed aldor)
    if msgType == "S" then
        local liftID, phase, name, realm, fall, bottom, rise, top, origin, srvPhase
        if ver >= 4 and #parts >= 5 then
            liftID   = parts[2]
            phase    = tonumber(parts[3])
            name     = parts[4]
            realm    = parts[5]
            fall     = tonumber(parts[6])
            bottom   = tonumber(parts[7])
            rise     = tonumber(parts[8])
            top      = tonumber(parts[9])
            origin   = parts[10] or "C"    -- v4 has no origin field; assume calibrated
            srvPhase = tonumber(parts[11]) -- v5 only; nil for v4
        elseif ver >= 3 and #parts >= 4 then
            liftID = "aldor"
            phase  = tonumber(parts[2])
            name   = parts[3]
            realm  = parts[4]
            fall   = tonumber(parts[5])
            bottom = tonumber(parts[6])
            rise   = tonumber(parts[7])
            top    = tonumber(parts[8])
            origin = "C"
        else
            return
        end
        if not phase or not LIFTS[liftID] then return end
        if IsHardBlocked(name, realm) then return end
        if IsSoftBlocked(name, realm) then
            Log(string.format("|cffff6600AldorTax: Ignored sync from soft-blocked %s-%s|r", name, realm))
            return
        end
        ApplyRemoteSync(liftID, phase, name, realm, fall, bottom, rise, top, srvPhase)
        local st = liftState[liftID]
        if st then st.syncOrigin = origin end
        local originLabel = origin == "R" and " (relayed)" or ""
        if fall then
            Log(string.format("|cff00ff00AldorTax: %s sync from %s%s (%.2f+%.2f+%.2f+%.2f=%.2fs)|r",
                LIFTS[liftID].displayName, name, originLabel, fall, bottom, rise, top, fall + bottom + rise + top))
        else
            Log(string.format("|cff00ff00AldorTax: %s sync from %s-%s%s|r", LIFTS[liftID].displayName, name, realm,
                originLabel))
        end
    elseif msgType == "D" then
        local liftID, syncTime, name, realm
        if ver >= 4 and #parts >= 5 then
            liftID   = parts[2]
            syncTime = tonumber(parts[3])
            name     = parts[4]
            realm    = parts[5]
        elseif ver >= 3 and #parts >= 4 then
            liftID   = "aldor"
            syncTime = tonumber(parts[2])
            name     = parts[3]
            realm    = parts[4]
        else
            return
        end
        if not syncTime or not name or not LIFTS[liftID] then return end
        local count = RecordDeathReport(name, realm)
        local st = liftState[liftID]
        if st.lastSyncSource and st.lastSyncSource.name == name and st.lastSyncSource.realm == realm then
            if count and count >= SOFT_BLOCK_THRESHOLD then
                st.lastSync       = 0
                st.lastSync2      = 0
                st.lastSyncSource = nil
                warnFrame:Hide()
                print("|cffff0000AldorTax: Active sync invalidated — too many deaths reported.|r")
            end
        end
    end
end

-- ─── Forward declarations (used by event handlers below, defined later) ─────
local syncUI = nil
local BuildSyncUI

-- ─── Events ─────────────────────────────────────────────────────────────────

local logicFrame = CreateFrame("Frame")
logicFrame:RegisterEvent("ADDON_LOADED")
logicFrame:RegisterEvent("CHAT_MSG_ADDON")
logicFrame:RegisterEvent("ZONE_CHANGED")
logicFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
logicFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logicFrame:RegisterEvent("PLAYER_DEAD")
logicFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
logicFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
logicFrame:RegisterEvent("CHAT_MSG_SAY")

logicFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "AldorTax" then
        if not AldorTaxDB then AldorTaxDB = {} end
        if not AldorTaxDB.blocklist then AldorTaxDB.blocklist = {} end
        if not AldorTaxDB.ty then AldorTaxDB.ty = 0 end
        -- Migrate old flat sync state into per-lift structure
        if AldorTaxDB.lastSyncRealTime and not AldorTaxDB.lifts then
            AldorTaxDB.lifts            = {
                aldor = {
                    lastSyncRealTime = AldorTaxDB.lastSyncRealTime,
                    lastSyncSource   = AldorTaxDB.lastSyncSource,
                },
            }
            AldorTaxDB.lastSyncRealTime = nil
            AldorTaxDB.lastSyncSource   = nil
        end
        if not AldorTaxDB.lifts then AldorTaxDB.lifts = {} end
        -- Load saved settings
        if AldorTaxDB.settings then
            for k, v in pairs(AldorTaxDB.settings) do
                if settings[k] ~= nil then settings[k] = v end
            end
        end
        RegisterPrefix()
        RestoreSync()
        BuildOptionsPanel()
    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(arg1, arg2, arg3, arg4)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent = CombatLogGetCurrentEventInfo()
        if subEvent == "ENVIRONMENTAL_DAMAGE" then
            local _, _, _, _, _, _, _, _, _, _, _, envType = CombatLogGetCurrentEventInfo()
            if envType == "Falling" then
                logicFrame.lastFallDamage = GetTime()
            end
        end
    elseif event == "PLAYER_DEAD" then
        if activeLiftID then
            local isFallDeath = logicFrame.lastFallDamage and (GetTime() - logicFrame.lastFallDamage) < 3
            if isFallDeath then
                BroadcastDied(activeLiftID)
                liftState[activeLiftID].lastSync       = 0
                liftState[activeLiftID].lastSync2      = 0
                liftState[activeLiftID].lastSyncSource = nil
                warnFrame:Hide()
                Log("|cffff0000AldorTax: Fall death detected — sync cleared and reported.|r")
            else
                Log("|cffffcc00AldorTax: Non-fall death near lift — sync preserved.|r")
            end
        end
    elseif event == "CHAT_MSG_TEXT_EMOTE" then
        -- Secret thank counter: only if we /say'd recently, not self, they targeted us
        local st = activeLiftID and liftState[activeLiftID]
        if st and st.lastSayTime > 0 and (GetTime() - st.lastSayTime) <= 30 then
            local sender = arg2 or ""
            if sender ~= UnitName("player") then
                local msg = arg1 or ""
                if msg:lower():find("thanks you") then
                    if AldorTaxDB then
                        AldorTaxDB.ty = (AldorTaxDB.ty or 0) + 1
                        if syncUI and syncUI.tyLabel then
                            syncUI.tyLabel:SetText(tostring(AldorTaxDB.ty))
                            syncUI.tyLabel:Show()
                        end
                    end
                end
            end
        end
    elseif event == "CHAT_MSG_SAY" then
        local msg    = arg1 or ""
        local sender = arg2 or ""
        local me     = UnitName("player")
        if settings.autoThank and sender ~= me and not sender:find("^" .. me .. "%-") and msg:find("^AldorTax:.*lift going down in:") then
            DoEmote("THANK", sender)
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local newLiftID = DetectActiveLift()
        if newLiftID then
            if newLiftID ~= activeLiftID then
                if not activeLiftID then
                    zonedInAt = GetTime() -- entering a lift zone; delay sends for server rate-limiter
                end
                activeLiftID = newLiftID
                if not syncUI then syncUI = BuildSyncUI() end
                syncUI.ReconfigureLift(activeLiftID)
            end
            local def        = LIFTS[activeLiftID]
            local st         = liftState[activeLiftID]
            st.isNearLift    = CheckNearLift(def)
            st.isApproaching = CheckApproachLift(def)
            if settings.alwaysCompact then
                syncUI:Show()
                if syncUI.SetCompact then syncUI.SetCompact(true) end
            elseif settings.alwaysShowUI then
                syncUI:Show()
                if syncUI.SetCompact then syncUI.SetCompact(false) end
            elseif st.isNearLift then
                syncUI:Show()
                if syncUI.SetCompact then syncUI.SetCompact(false) end
            elseif st.isApproaching then
                syncUI:Show()
                if syncUI.SetCompact then syncUI.SetCompact(true) end
            else
                syncUI:Hide()
            end
        else
            if syncUI then syncUI:Hide() end
            -- Final broadcast as we leave
            if activeLiftID and liftState[activeLiftID].lastSync > 0 then
                BroadcastSync(activeLiftID)
            end
            activeLiftID = nil
        end
    end
end)

-- ─── Warning display (OnUpdate) ─────────────────────────────────────────────

logicFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    local doProximity = now - lastProximityCheck >= PROXIMITY_CHECK_INTERVAL
    if doProximity then
        lastProximityCheck = now
        -- Fallback: zone events can fire before GetZoneText() is ready after /reload
        if not activeLiftID then
            local id = DetectActiveLift()
            if id then
                activeLiftID = id
                if not syncUI then syncUI = BuildSyncUI() end
                syncUI.ReconfigureLift(activeLiftID)
            end
        end
    end
    if not activeLiftID then return end
    local def = LIFTS[activeLiftID]
    local st  = liftState[activeLiftID]
    if doProximity then
        st.isNearLift    = CheckNearLift(def)
        st.isApproaching = CheckApproachLift(def)
        if settings.alwaysCompact then
            if not syncUI then
                syncUI = BuildSyncUI(); syncUI.ReconfigureLift(activeLiftID)
            end
            syncUI.SetCompact(true)
            if not syncUI:IsShown() then syncUI:Show() end
        elseif settings.alwaysShowUI then
            if not syncUI then
                syncUI = BuildSyncUI(); syncUI.ReconfigureLift(activeLiftID)
            end
            syncUI.SetCompact(false)
            if not syncUI:IsShown() then syncUI:Show() end
        elseif syncUI then
            if st.isNearLift then
                syncUI.SetCompact(false)
                if not syncUI:IsShown() then syncUI:Show() end
            elseif st.isApproaching then
                syncUI.SetCompact(true)
                if not syncUI:IsShown() then syncUI:Show() end
            else
                if syncUI:IsShown() then syncUI:Hide() end
            end
        end
    end

    local status
    if st.isNearLift then
        status = "on_platform"
    elseif st.isApproaching then
        status = "approaching"
    else
        status = "other"
    end

    if st.lastSync > 0 then
        local progress          = (GetTime() - st.lastSync) % def.cycleTime
        local timeUntilNextDrop = def.cycleTime - progress

        local uiVisible         = (syncUI and syncUI:IsShown()) or settings.alwaysShowUI
        if uiVisible then
            warnFrame:Hide()
        elseif status == "on_platform" and timeUntilNextDrop <= def.waitAtTop then
            warnFrame:Show()
            warnText:SetText(string.format("!!! LEAVING IN: %.1fs !!!", timeUntilNextDrop))
            warnText:SetTextColor(1, 0, 0)
            warnFrame:SetAlpha(math.abs(math.sin(GetTime() * 10)))
        elseif status == "approaching" and timeUntilNextDrop <= APPROACH_WARNING_TIME then
            warnFrame:Show()
            warnText:SetText(string.format("LIFT LEAVING IN: %.1fs!", timeUntilNextDrop))
            warnText:SetTextColor(1, 0.5, 0)
            warnFrame:SetAlpha(0.5 + 0.5 * math.abs(math.sin(GetTime() * 5)))
        else
            warnFrame:Hide()
        end
    end

    -- Fall-save alert: detect freefall near a lift with a death zone
    if settings.fallSaveAlert and def.deathZones then
        local falling = IsFalling()
        if falling and not wasFalling then
            -- Rising edge: just started falling — only alert if near the lift
            if st.isNearLift or st.isApproaching then
                ShowFallSaveAlert()
            end
        elseif not falling and wasFalling then
            HideFallSaveAlert()
        end
        wasFalling = falling
        -- Auto-dismiss after timeout
        if fallSaveShown and GetTime() >= fallSaveHideAt then
            HideFallSaveAlert()
        end
    elseif fallSaveShown then
        HideFallSaveAlert()
        wasFalling = false
    end

    -- Auto-broadcast
    local hasRecipient = GetGeneralChannelNum()
        or IsInGuild()
        or UnitInRaid("player")
        or (GetNumGroupMembers and GetNumGroupMembers() > 0)
    if st.lastSync > 0 and hasRecipient then
        local now = GetTime()
        if now - st.lastAutoBroadcast >= AUTO_BROADCAST_INTERVAL then
            st.lastAutoBroadcast = now
            BroadcastSync(activeLiftID)
        end
    end

    -- Tick the sync UI cursor
    if syncUI and syncUI:IsShown() and syncUI.UpdateCursor then
        syncUI.UpdateCursor()
    end
end)

-- ─── Calibration click helper ───────────────────────────────────────────────
-- Shared logic for all click-to-sync interactions: segment bar, dual-lift
-- top/bottom, tram station buttons, and tram travel-bar departure.
-- phaseStart: cycle offset of the clicked phase transition (0 = FALL start)
-- label:      human-readable description for the sync log entry

local function PerformCalibrationClick(liftID, phaseStart, label)
    local def = LIFTS[liftID]
    local st  = liftState[liftID]
    if not def or not st then return end
    local now = GetTime() - CLICK_REACTION_TIME
    LogSyncCorrection(liftID, now - phaseStart, label)
    -- Record timing sample even on first click (LogSyncCorrection skips when lastSync=0)
    if st.lastSync <= 0 then
        local absSync = (now - phaseStart) + (serverTimeOffset or 0)
        RecordTimingSample(liftID, GetServerTime(), absSync % def.cycleTime, 0, label)
    end
    st.lastSync          = now - phaseStart
    st.lastAutoBroadcast = GetTime()
    local rt             = GetRealTime() - CLICK_REACTION_TIME - phaseStart
    SaveSync(liftID, nil, nil, rt)
    BroadcastSync(liftID, rt)
    AppendSyncLog(string.format(
        "%s|%s|%s|%.3f|%.3f",
        date("%Y-%m-%d %H:%M:%S"), liftID, label, GetServerTime(), phaseStart))
    Log(string.format("|cff00ff00AldorTax: %s synced at %s|r", def.displayName, label))
end

-- ─── Sync UI ────────────────────────────────────────────────────────────────

-- Returns 0.0 (bottom) to 1.0 (top) representing physical lift height at a
-- given cycle phase.
local function GetLiftHeight(phase, def)
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

-- Returns 0.0 (endpoint A) to 1.0 (endpoint B) for horizontal tram position.
local function GetTramPosition(phase, def)
    if phase < def.fallTime then
        return phase / def.fallTime
    elseif phase < def.fallTime + def.waitAtBottom then
        return 1.0
    elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
        return 1.0 - (phase - def.fallTime - def.waitAtBottom) / def.riseTime
    else
        return 0.0
    end
end

-- Returns the phase colour (r, g, b) for a given cycle position.
local function GetPhaseColor(phase, def)
    if phase < def.fallTime then
        return 0.85, 0.12, 0.10 -- falling: red
    elseif phase < def.fallTime + def.waitAtBottom then
        return 0.22, 0.42, 0.88 -- bottom: blue
    elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
        return 0.95, 0.72, 0.08 -- rising: yellow
    else
        return 0.10, 0.78, 0.25 -- top: green
    end
end

-- Returns a def-like table with the secondary platform's segment times.
-- Falls back to primary values for any field not set on the secondary.
local function SecDef(def)
    if not def.cycleTime2 then return def end
    return {
        fallTime     = def.fallTime2 or def.fallTime,
        waitAtBottom = def.waitAtBottom2 or def.waitAtBottom,
        riseTime     = def.riseTime2 or def.riseTime,
        waitAtTop    = def.waitAtTop2 or def.waitAtTop,
        cycleTime    = def.cycleTime2,
        segColors    = def.segColors,
    }
end

BuildSyncUI = function()
    if AldorTaxSyncUI then return AldorTaxSyncUI end

    local BAR_W_FULL    = 460
    local BAR_W_COMPACT = 280
    local BAR_H         = 28
    local PAD           = 12
    local VBAR_W        = 26  -- vertical bar width
    local VBAR_H        = 130 -- vertical bar height
    local VBAR_GAP      = 70  -- gap between the two vertical bars

    local barW          = BAR_W_FULL
    local isCompact     = false
    local isDual        = false
    local curLiftID     = nil

    -- ── Main frame ──────────────────────────────────────────────────────────
    local p             = CreateFrame("Frame", "AldorTaxSyncUI", UIParent, "BackdropTemplate")
    p:SetSize(BAR_W_FULL + PAD * 2, 94)
    if AldorTaxDB and AldorTaxDB.windowPos then
        local wp = AldorTaxDB.windowPos
        p:SetPoint(wp.point, UIParent, wp.relPoint, wp.x, wp.y)
    else
        p:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    p:SetFrameStrata("MEDIUM")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if AldorTaxDB then
            local point, _, relPoint, x, y = self:GetPoint(1)
            AldorTaxDB.windowPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    p:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    p:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    p:SetBackdropBorderColor(0.40, 0.36, 0.22, 0.70)

    -- ── Title ───────────────────────────────────────────────────────────────
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -7)
    title:SetText("Lift  |cff888888click phase to sync|r")
    title:SetTextColor(1, 0.82, 0)
    p.title = title

    -- ── Source label ────────────────────────────────────────────────────────
    local sourceLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceLabel:SetPoint("TOPRIGHT", -PAD, -7)
    sourceLabel:SetText("no sync")
    sourceLabel:SetTextColor(0.6, 0.6, 0.6)
    p.sourceLabel = sourceLabel

    -- ═════════════════════════════════════════════════════════════════════════
    -- HORIZONTAL BAR ELEMENTS (single-lift mode: Aldor)
    -- ═════════════════════════════════════════════════════════════════════════

    local barBg = CreateFrame("Frame", nil, p, "BackdropTemplate")
    barBg:SetPoint("TOPLEFT", PAD - 2, -24)
    barBg:SetSize(BAR_W_FULL + 4, BAR_H + 4)
    barBg:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    barBg:SetBackdropColor(0.02, 0.02, 0.04, 0.90)
    barBg:SetBackdropBorderColor(0.12, 0.12, 0.16, 0.70)
    p.barBg = barBg

    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(BAR_W_FULL, BAR_H)
    bar:SetPoint("TOPLEFT", PAD, -26)

    local segBtns = {}
    local segTextures = {}
    local SEG_NAMES = { "FALL", "BOTTOM", "RISE", "TOP" }

    for i = 1, 4 do
        local segBtn = CreateFrame("Button", nil, bar)
        segBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        segBtn:SetSize(1, BAR_H)
        segBtns[i] = segBtn

        local tex = segBtn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        segTextures[i] = tex
        segBtn:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

        local borderL = segBtn:CreateTexture(nil, "BORDER")
        borderL:SetColorTexture(0, 0, 0, 0.70)
        borderL:SetPoint("TOPLEFT"); borderL:SetPoint("BOTTOMLEFT"); borderL:SetWidth(1)
        local borderR = segBtn:CreateTexture(nil, "BORDER")
        borderR:SetColorTexture(0, 0, 0, 0.70)
        borderR:SetPoint("TOPRIGHT"); borderR:SetPoint("BOTTOMRIGHT"); borderR:SetWidth(1)
        local borderT = segBtn:CreateTexture(nil, "BORDER")
        borderT:SetColorTexture(0, 0, 0, 0.70)
        borderT:SetPoint("TOPLEFT"); borderT:SetPoint("TOPRIGHT"); borderT:SetHeight(1)
        local borderB = segBtn:CreateTexture(nil, "BORDER")
        borderB:SetColorTexture(0, 0, 0, 0.70)
        borderB:SetPoint("BOTTOMLEFT"); borderB:SetPoint("BOTTOMRIGHT"); borderB:SetHeight(1)

        local phaseIdx = i - 1
        segBtn:SetScript("OnClick", function()
            if not activeLiftID then return end
            local def = LIFTS[activeLiftID]
            local starts = {
                [0] = 0,
                def.fallTime,
                def.fallTime + def.waitAtBottom,
                def.fallTime + def.waitAtBottom + def.riseTime
            }
            PerformCalibrationClick(activeLiftID, starts[phaseIdx], SEG_NAMES[i])
        end)
    end

    local overlay = CreateFrame("Frame", nil, p)
    overlay:SetSize(BAR_W_FULL, BAR_H)
    overlay:SetPoint("TOPLEFT", PAD, -26)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)

    local phaseLabels = {}
    for i = 1, 4 do
        local lbl = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText(SEG_NAMES[i])
        lbl:SetTextColor(1, 1, 1, 0.9)
        phaseLabels[i] = lbl
    end

    local cursorGlow = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    cursorGlow:SetColorTexture(1, 1, 1, 0.25)
    cursorGlow:SetSize(10, BAR_H + 8)
    cursorGlow:SetBlendMode("ADD")
    p.cursorGlow = cursorGlow

    local cursor = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    cursor:SetColorTexture(1, 1, 1, 1)
    cursor:SetSize(4, BAR_H + 6)
    cursor:SetPoint("CENTER", overlay, "LEFT", 0, 0)
    p.cursor  = cursor
    p.bar     = bar
    p.overlay = overlay
    p:Hide()

    local timeLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("BOTTOM", cursor, "TOP", 0, 2)
    timeLabel:SetShadowOffset(1, -1)
    timeLabel:SetShadowColor(0, 0, 0, 1)
    p.timeLabel = timeLabel

    -- ═════════════════════════════════════════════════════════════════════════
    -- DUAL VERTICAL BAR ELEMENTS (dual-lift mode: Great Lift)
    -- ═════════════════════════════════════════════════════════════════════════

    -- Container for vertical layout (hidden in single-lift mode)
    local dualContainer = CreateFrame("Frame", nil, p)
    dualContainer:Hide()

    -- Optional background texture (e.g. screenshot showing lift positions)
    local dualBgTex = dualContainer:CreateTexture(nil, "BACKGROUND")
    dualBgTex:SetAlpha(0.22)
    dualBgTex:Hide()

    -- Phase segment labels for click feedback
    local VBAR_PHASE_NAMES = { "FALL", "BOTTOM", "RISE", "TOP" }

    local OnBarClick -- forward declaration; assigned after MakeVBar

    local function MakeVBar(parent, label, isPrimary)
        local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        bg:SetSize(VBAR_W + 6, VBAR_H + 6)
        bg:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        bg:SetBackdropColor(0.03, 0.03, 0.06, 0.92)
        if isPrimary then
            bg:SetBackdropBorderColor(0.50, 0.45, 0.25, 0.90)
        else
            bg:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.70)
        end

        -- The bar frame — clean height indicator, no phase-colored segments
        local vbar = CreateFrame("Frame", nil, bg)
        vbar:SetSize(VBAR_W, VBAR_H)
        vbar:SetPoint("CENTER")

        -- Subtle gradient: slightly lighter at top, darker at bottom
        local gradTop = vbar:CreateTexture(nil, "ARTWORK")
        gradTop:SetColorTexture(0.12, 0.12, 0.15, 0.50)
        gradTop:SetPoint("TOPLEFT")
        gradTop:SetPoint("RIGHT")
        gradTop:SetHeight(VBAR_H / 2)
        local gradBot = vbar:CreateTexture(nil, "ARTWORK")
        gradBot:SetColorTexture(0.05, 0.05, 0.08, 0.50)
        gradBot:SetPoint("BOTTOMLEFT")
        gradBot:SetPoint("RIGHT")
        gradBot:SetHeight(VBAR_H / 2)

        -- Transition labels at top and bottom of bar
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

        -- Phase label that follows the cursor
        local phaseLbl = vbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        phaseLbl:SetScale(0.80)
        phaseLbl:SetShadowOffset(1, -1)
        phaseLbl:SetShadowColor(0, 0, 0, 1)

        -- Clickable overlay: top half = top event, bottom half = bottom event
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
            local bot = self:GetBottom()
            local top = self:GetTop()
            if not bot or not top or top == bot then return end
            local frac = ((cursorY / scale) - bot) / (top - bot)
            frac = math.max(0, math.min(1, frac))
            OnBarClick(isPrimary, frac)
        end)
        clickBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to sync (" .. lbl:GetText() .. ")", 1, 0.82, 0, 1)
            GameTooltip:AddLine("Top half: click when lift arrives at top", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Bottom half: click when lift arrives at bottom", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        clickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Midline divider between top/bottom click zones
        local midline = vbar:CreateTexture(nil, "ARTWORK", nil, 2)
        midline:SetColorTexture(0.40, 0.40, 0.35, 0.30)
        midline:SetSize(VBAR_W, 1)
        midline:SetPoint("CENTER", vbar, "CENTER", 0, 0)

        -- Cursor overlay (above click button so cursor draws on top)
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
            bg = bg,
            bar = vbar,
            overlay = voverlay,
            cursor = cur,
            glow = glow,
            label = lbl,
            timeLabel = tlbl,
            phaseLbl = phaseLbl,
            isPrimary = isPrimary,
        }
    end

    -- ── Dual-lift click-on-bar sync ────────────────────────────────────────
    -- Top half = "lift is at the top now", bottom half = "lift is at the bottom now".
    -- Single click is enough if the cycle timing is correct.
    OnBarClick          = function(isPrimary, clickFrac)
        if not activeLiftID then return end
        local def = LIFTS[activeLiftID]
        local sd = isPrimary and def or SecDef(def)
        local barLabel = isPrimary and (def.barLabel1 or "Primary") or (def.barLabel2 or "Secondary")
        local phaseName, phaseStart
        if clickFrac >= 0.75 then
            phaseName  = "TOP (" .. barLabel .. ")"
            phaseStart = sd.fallTime + sd.waitAtBottom + sd.riseTime
        elseif clickFrac >= 0.50 then
            phaseName  = "FALL (" .. barLabel .. ")"
            phaseStart = 0
        elseif clickFrac >= 0.25 then
            phaseName  = "RISE (" .. barLabel .. ")"
            phaseStart = sd.fallTime + sd.waitAtBottom
        else
            phaseName  = "BOTTOM (" .. barLabel .. ")"
            phaseStart = sd.fallTime
        end
        if isPrimary then
            PerformCalibrationClick(activeLiftID, phaseStart, phaseName)
        else
            -- Secondary platform: independent sync (separate cycle)
            local st = liftState[activeLiftID]
            if not st then return end
            local now = GetTime() - CLICK_REACTION_TIME
            st.lastSync2 = now - phaseStart
            AppendSyncLog(string.format(
                "%s|%s|%s|%.3f|%.3f",
                date("%Y-%m-%d %H:%M:%S"), activeLiftID, phaseName, GetServerTime(), phaseStart))
            Log(string.format("|cff00ff00AldorTax: %s synced at %s|r", def.displayName, phaseName))
        end
    end

    local vbar1         = MakeVBar(dualContainer, "Primary", true)
    local vbar2         = MakeVBar(dualContainer, "Secondary", false)

    -- ═════════════════════════════════════════════════════════════════════════
    -- DUAL HORIZONTAL BAR ELEMENTS (tram mode: Deeprun Tram)
    -- ═════════════════════════════════════════════════════════════════════════

    local HBAR_W        = 400
    local HBAR_H        = 20
    local HBAR_GAP      = 8

    local tramContainer = CreateFrame("Frame", nil, p)
    tramContainer:Hide()

    local isTram = false

    local STATION_BTN_W = 40

    local function MakeHBar(parent, label, isPrimary)
        local BTN_BD = {
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        }
        local BAR_BD = {
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }

        -- Container row
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(STATION_BTN_W * 2 + HBAR_W + 16, HBAR_H + 10)

        -- ── Station button A (left endpoint) ──
        local btnA = CreateFrame("Button", nil, row, "BackdropTemplate")
        btnA:SetSize(STATION_BTN_W, HBAR_H + 10)
        btnA:SetBackdrop(BTN_BD)
        btnA:SetPoint("LEFT", row, "LEFT", 0, 0)
        btnA:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
        btnA.label = btnA:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnA.label:SetPoint("CENTER")
        btnA.label:SetTextColor(1, 1, 1)
        btnA:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- ── Station button B (right endpoint) ──
        local btnB = CreateFrame("Button", nil, row, "BackdropTemplate")
        btnB:SetSize(STATION_BTN_W, HBAR_H + 10)
        btnB:SetBackdrop(BTN_BD)
        btnB:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        btnB:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
        btnB.label = btnB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnB.label:SetPoint("CENTER")
        btnB.label:SetTextColor(1, 1, 1)
        btnB:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- ── Travel bar (center, between buttons) ──
        local bg = CreateFrame("Frame", nil, row, "BackdropTemplate")
        bg:SetPoint("LEFT", btnA, "RIGHT", 5, 0)
        bg:SetPoint("RIGHT", btnB, "LEFT", -5, 0)
        bg:SetHeight(HBAR_H + 6)
        bg:SetBackdrop(BAR_BD)
        bg:SetBackdropColor(0.04, 0.04, 0.06, 0.90)
        if isPrimary then
            bg:SetBackdropBorderColor(0.30, 0.30, 0.35, 0.70)
        else
            bg:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.50)
        end

        local hbar = CreateFrame("Frame", nil, bg)
        hbar:SetPoint("TOPLEFT", bg, "TOPLEFT", 3, -3)
        hbar:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -3, 3)

        -- Travel bar fill (neutral)
        local fillL = hbar:CreateTexture(nil, "ARTWORK")
        fillL:SetColorTexture(0.25, 0.25, 0.30, isPrimary and 0.40 or 0.25)
        fillL:SetPoint("TOPLEFT"); fillL:SetPoint("BOTTOMLEFT")
        fillL:SetWidth(HBAR_W / 2)
        local fillR = hbar:CreateTexture(nil, "ARTWORK")
        fillR:SetColorTexture(0.25, 0.25, 0.30, isPrimary and 0.40 or 0.25)
        fillR:SetPoint("TOPRIGHT"); fillR:SetPoint("BOTTOMRIGHT")
        fillR:SetWidth(HBAR_W / 2)

        -- Cursor overlay
        local hover = CreateFrame("Frame", nil, bg)
        hover:SetPoint("TOPLEFT", hbar); hover:SetPoint("BOTTOMRIGHT", hbar)
        hover:SetFrameLevel(hbar:GetFrameLevel() + 2)

        local glow = hover:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetColorTexture(1, 1, 1, 0.20)
        glow:SetSize(10, HBAR_H + 6)
        glow:SetBlendMode("ADD")

        local cur = hover:CreateTexture(nil, "OVERLAY", nil, 2)
        cur:SetColorTexture(1, 1, 1, 1)
        cur:SetSize(3, HBAR_H + 4)
        cur:SetPoint("CENTER", hover, "LEFT", 0, 0)

        -- Time label below cursor
        local timeLbl = hover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeLbl:SetShadowOffset(1, -1)
        timeLbl:SetShadowColor(0, 0, 0, 1)

        -- Phase label above cursor
        local phaseLbl = hover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        phaseLbl:SetScale(0.80)
        phaseLbl:SetShadowOffset(1, -1)
        phaseLbl:SetShadowColor(0, 0, 0, 1)

        -- Compact endpoint labels (shown only in compact mode)
        local compactLblA = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        compactLblA:SetPoint("LEFT", bg, "LEFT", 4, 0)
        compactLblA:SetScale(0.80)
        compactLblA:Hide()
        local compactLblB = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        compactLblB:SetPoint("RIGHT", bg, "RIGHT", -4, 0)
        compactLblB:SetScale(0.80)
        compactLblB:Hide()

        -- ── Click handler for travel bar (departs) ──
        local clickBtn = CreateFrame("Button", nil, bg)
        clickBtn:SetAllPoints(hover)
        clickBtn:SetFrameLevel(hover:GetFrameLevel() + 1)
        clickBtn:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

        -- Derive departure station from timer phase (dwell phases only)
        local function getDepartStation()
            if not activeLiftID then return nil end
            local def = LIFTS[activeLiftID]
            local st  = liftState[activeLiftID]
            if st.lastSync <= 0 then return nil end
            local p = (GetTime() - st.lastSync) % def.cycleTime
            if not isPrimary and def.dualLift then
                p = (p + def.cycleTime / 2) % def.cycleTime
            end
            -- dwell at B (SW): phase [fallTime, fallTime+waitAtBottom)
            if p >= def.fallTime and p < def.fallTime + def.waitAtBottom then
                return "B"
            end
            -- dwell at A (IF): phase [fallTime+waitAtBottom+riseTime, cycleTime)
            if p >= def.fallTime + def.waitAtBottom + def.riseTime then
                return "A"
            end
            return nil -- in transit
        end

        clickBtn:SetScript("OnEnter", function(self)
            if not activeLiftID then return end
            local def = LIFTS[activeLiftID]
            local ds = getDepartStation()
            local stationName = ds == "B" and (def.endpointB or "B")
                or ds == "A" and (def.endpointA or "A")
                or nil
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if stationName then
                GameTooltip:SetText("Click when tram departs " .. stationName, 1, 0.82, 0, 1)
            else
                GameTooltip:SetText("Click when tram departs", 1, 0.82, 0, 1)
                GameTooltip:AddLine("Sync first, or click during a dwell phase", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        clickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        clickBtn:SetScript("OnClick", function(self)
            if not activeLiftID then return end
            local def = LIFTS[activeLiftID]
            local ds = getDepartStation()
            local phaseStart, phaseName
            if ds == "B" then
                phaseStart = def.fallTime + def.waitAtBottom
                phaseName = "departs " .. (def.endpointB or "B")
            elseif ds == "A" then
                phaseStart = 0
                phaseName = "departs " .. (def.endpointA or "A")
            else
                return -- in transit or no sync — ignore click
            end
            if not isPrimary and def.dualLift then
                phaseStart = (phaseStart + def.cycleTime / 2) % def.cycleTime
            end
            PerformCalibrationClick(activeLiftID, phaseStart, phaseName .. (isPrimary and "" or " (2nd tram)"))
        end)

        return {
            row = row,
            bg = bg,
            bar = hbar,
            overlay = hover,
            cursor = cur,
            glow = glow,
            fillL = fillL,
            fillR = fillR,
            timeLabel = timeLbl,
            phaseLbl = phaseLbl,
            isPrimary = isPrimary,
            label = label,
            btnA = btnA,
            btnB = btnB,
            compactLblA = compactLblA,
            compactLblB = compactLblB,
            getDepartStation = getDepartStation,
        }
    end

    local hbar1 = MakeHBar(tramContainer, "Tram 1", true)
    local hbar2 = MakeHBar(tramContainer, "Tram 2", false)

    -- Station button labels, colors, and click handlers are set in ReconfigureLift.

    -- ═════════════════════════════════════════════════════════════════════════
    -- SHARED ELEMENTS
    -- ═════════════════════════════════════════════════════════════════════════

    -- Build the /say message text for the current lift state.
    -- Returns nil if no sync or no active lift.
    local function BuildSayMessage()
        if not activeLiftID then return nil end
        local def = LIFTS[activeLiftID]
        local st  = liftState[activeLiftID]
        if st.lastSync <= 0 then
            print("|cffff6600AldorTax: No sync — nothing to announce.|r")
            return nil
        end
        local phase = (GetTime() - st.lastSync) % def.cycleTime
        if def.horizontal then
            local nameA = def.endpointA or "A" -- IF
            local nameB = def.endpointB or "B" -- SW
            -- Phase tracks the "North" tram. South is offset by half cycle.
            -- Show per-station info with track name so players know which platform.
            if phase < def.fallTime then
                -- North heading to SW, South heading to IF
                local t = def.fallTime - phase
                return string.format("AldorTax Tram: South arrives %s in %02.0fs", nameA, t),
                    string.format("AldorTax Tram: North arrives %s in %02.0fs", nameB, t)
            elseif phase < def.fallTime + def.waitAtBottom then
                -- North docked at SW, South docked at IF
                local t = def.fallTime + def.waitAtBottom - phase
                return string.format("AldorTax Tram: South departs %s in %02.0fs", nameA, t),
                    string.format("AldorTax Tram: North departs %s in %02.0fs", nameB, t)
            elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
                -- North heading to IF, South heading to SW
                local t = def.fallTime + def.waitAtBottom + def.riseTime - phase
                return string.format("AldorTax Tram: North arrives %s in %02.0fs", nameA, t),
                    string.format("AldorTax Tram: South arrives %s in %02.0fs", nameB, t)
            else
                -- North docked at IF, South docked at SW
                local t = def.cycleTime - phase
                return string.format("AldorTax Tram: North departs %s in %02.0fs", nameA, t),
                    string.format("AldorTax Tram: South departs %s in %02.0fs", nameB, t)
            end
        elseif def.dualLift then
            local sd = SecDef(def)
            local ttfPrimary = def.cycleTime - phase
            local phase2
            if st.lastSync2 > 0 then
                phase2 = (GetTime() - st.lastSync2) % sd.cycleTime
            else
                local offset = def.dualOffset or def.cycleTime / 2
                phase2 = (phase + offset) % sd.cycleTime
            end
            local ttfSecondary = sd.cycleTime - phase2
            local platName1 = def.barLabel1 or "Primary"
            local platName2 = def.barLabel2 or "Secondary"
            local platName, ttf
            if ttfPrimary <= ttfSecondary then
                platName, ttf = platName1, ttfPrimary
            else
                platName, ttf = platName2, ttfSecondary
            end
            return string.format("AldorTax: %s lift going down in: %.1f seconds", platName, ttf)
        else
            local ttd = def.cycleTime - phase
            return string.format("AldorTax: Lift going down in: %.1f seconds", ttd)
        end
    end

    -- Say the current position via SendChatMessage (works indoors without hardware event)
    local function DoSayPosition()
        local msg1, msg2 = BuildSayMessage()
        if msg1 then
            SendChatMessage(msg1, "SAY")
            if msg2 then SendChatMessage(msg2, "SAY") end
            if activeLiftID then
                local st = liftState[activeLiftID]
                if st then st.lastSayTime = GetTime() end
            end
        end
    end

    local sayBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    sayBtn:SetSize(130, 24)
    sayBtn:SetText("|cffffcc00Say Warning|r")
    sayBtn:SetNormalFontObject("GameFontNormalSmall")
    sayBtn:SetHighlightFontObject("GameFontHighlightSmall")
    local sayOverlay = sayBtn:CreateTexture(nil, "ARTWORK", nil, 2)
    sayOverlay:SetColorTexture(0.7, 0.55, 0.05, 0.25)
    sayOverlay:SetAllPoints()
    p.sayBtn = sayBtn

    sayBtn:SetScript("OnClick", function() DoSayPosition() end)

    sayBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 8)

    local tyLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tyLabel:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -8, 6)
    tyLabel:SetTextColor(0.85, 0.75, 0.35, 0.5)
    tyLabel:SetText(AldorTaxDB and AldorTaxDB.ty and AldorTaxDB.ty > 0 and tostring(AldorTaxDB.ty) or "")
    p.tyLabel = tyLabel

    local sayIcon = CreateFrame("Button", nil, p)
    sayIcon:SetSize(22, 22)
    sayIcon:SetNormalTexture("Interface/Common/VoiceChat-Speaker")
    local waves = sayIcon:CreateTexture(nil, "OVERLAY")
    waves:SetTexture("Interface/Common/VoiceChat-On")
    waves:SetAllPoints()
    sayIcon:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
    sayIcon:Hide()
    sayIcon:SetScript("OnClick", function() DoSayPosition() end)
    sayIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(isTram and "Say position" or "Say warning", 1, 0.82, 0, 1)
        GameTooltip:Show()
    end)
    sayIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.sayIcon = sayIcon

    -- ═════════════════════════════════════════════════════════════════════════
    -- LAYOUT FUNCTIONS
    -- ═════════════════════════════════════════════════════════════════════════

    local function HideTram()
        tramContainer:Hide()
    end

    local function ShowHorizontal()
        barBg:Show(); bar:Show(); overlay:Show()
        for i = 1, 4 do phaseLabels[i]:Show() end
        dualContainer:Hide()
        HideTram()
    end

    local function HideHorizontal()
        barBg:Hide(); bar:Hide(); overlay:Hide()
        for i = 1, 4 do phaseLabels[i]:Hide() end
    end

    local function ShowDual()
        dualContainer:Show()
        HideHorizontal()
        HideTram()
    end

    local function ShowTram()
        tramContainer:Show()
        HideHorizontal()
        dualContainer:Hide()
    end

    local function LayoutDualFull()
        local totalW = VBAR_W * 2 + VBAR_GAP + 6 * 2 -- bars + gap + borders
        local frameW = totalW + PAD * 2 + 40
        if frameW < 200 then frameW = 200 end
        -- title(20) + labelAbove(14) + bars + timeBelow(14) + sayBtn(24) + padding
        local frameH = 20 + 14 + VBAR_H + 6 + 14 + 24 + PAD + 8
        p:SetSize(frameW, frameH)

        dualContainer:ClearAllPoints()
        dualContainer:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        dualContainer:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

        vbar1.bg:ClearAllPoints()
        vbar1.bg:SetPoint("TOP", dualContainer, "TOP", -(VBAR_GAP / 2 + VBAR_W / 2), -36)
        vbar2.bg:ClearAllPoints()
        vbar2.bg:SetPoint("TOP", dualContainer, "TOP", (VBAR_GAP / 2 + VBAR_W / 2), -36)

        -- Background image fills entire container
        dualBgTex:ClearAllPoints()
        dualBgTex:SetAllPoints(dualContainer)

        sayBtn:ClearAllPoints()
        sayBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 8)
    end

    local function LayoutDualCompact()
        local frameW = VBAR_W * 2 + VBAR_GAP + PAD * 2 + 10
        local frameH = VBAR_H + PAD * 2
        p:SetSize(frameW, frameH)

        dualContainer:ClearAllPoints()
        dualContainer:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        dualContainer:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

        vbar1.bg:ClearAllPoints()
        vbar1.bg:SetPoint("LEFT", dualContainer, "LEFT", PAD, 0)
        vbar2.bg:ClearAllPoints()
        vbar2.bg:SetPoint("LEFT", vbar1.bg, "RIGHT", VBAR_GAP - 6, 0)

        dualBgTex:Hide() -- no room in compact mode

        sayIcon:ClearAllPoints()
        sayIcon:SetPoint("LEFT", vbar2.bg, "RIGHT", 8, 0)
        sayIcon:Show()
    end

    local function LayoutTramFull()
        local rowW = HBAR_W + STATION_BTN_W * 2 + 16 -- bar + 2 station buttons + gaps
        local frameW = rowW + PAD * 2
        -- title(20) + row1 + gap + row2 + portalIcons(35) + sayBtn(24) + padding
        local frameH = 20 + (HBAR_H + 6 + 12) * 2 + HBAR_GAP + 35 + 24 + PAD + 12
        p:SetSize(frameW, frameH)

        tramContainer:ClearAllPoints()
        tramContainer:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        tramContainer:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

        hbar2.row:ClearAllPoints()
        hbar2.row:SetPoint("TOP", tramContainer, "TOP", 0, -42)
        hbar2.row:SetSize(rowW, HBAR_H + 10)

        hbar1.row:ClearAllPoints()
        hbar1.row:SetPoint("TOP", hbar2.row, "BOTTOM", 0, -HBAR_GAP - 12)
        hbar1.row:SetSize(rowW, HBAR_H + 10)

        if not tramContainer.portalL then
            local function CreatePortal(icon, label, cr, cg, cb)
                local tex = tramContainer:CreateTexture(nil, "ARTWORK")
                tex:SetSize(28, 28)
                tex:SetTexture(icon)
                local lbl = tramContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                lbl:SetPoint("TOP", tex, "BOTTOM", 0, -2)
                lbl:SetText(label)
                lbl:SetTextColor(cr, cg, cb, 0.8)
                return tex, lbl
            end
            tramContainer.portalL, tramContainer.portalLLbl = CreatePortal(
                "Interface\\Icons\\Spell_Arcane_PortalIronforge", "IF", 0.30, 0.55, 0.85)
            tramContainer.portalR, tramContainer.portalRLbl = CreatePortal(
                "Interface\\Icons\\Spell_Arcane_PortalStormwind", "SW", 0.85, 0.55, 0.30)
        end

        tramContainer.portalL:ClearAllPoints()
        tramContainer.portalL:SetPoint("TOP", hbar1.btnA, "BOTTOM", 0, -2)
        tramContainer.portalR:ClearAllPoints()
        tramContainer.portalR:SetPoint("TOP", hbar1.btnB, "BOTTOM", 0, -2)

        tramContainer.portalL:Show(); tramContainer.portalLLbl:Show()
        tramContainer.portalR:Show(); tramContainer.portalRLbl:Show()

        sayBtn:ClearAllPoints()
        sayBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 8)
    end

    -- ── Compact tram layout ───────────────────────────────────────────────
    -- Scales the existing row architecture down: narrower travel bar, smaller
    -- station buttons, no track labels or portal icons.  Station buttons remain
    -- fully clickable (required for calibration).  sayIcon replaces sayBtn
    -- and calls DoSayPosition() on click, same as sayBtn.

    local COMPACT_HBAR_W = 180 -- travel bar width in compact mode (full = 400)
    local COMPACT_BTN_W  = 30  -- station button width (full = 40)
    local COMPACT_HBAR_H = 16  -- bar height (full = 20)
    local COMPACT_GAP    = 4   -- gap between hbar2 and hbar1 rows

    local function LayoutTramCompact()
        local rowW = COMPACT_HBAR_W + COMPACT_BTN_W * 2 + 16
        local rowH = COMPACT_HBAR_H + 8
        -- Frame: two rows + gap + small top/bottom padding
        local frameW = rowW + PAD * 2 + 28 -- +28 for sayIcon to the right
        local frameH = rowH * 2 + COMPACT_GAP + 14
        p:SetSize(frameW, frameH)

        tramContainer:ClearAllPoints()
        tramContainer:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
        tramContainer:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

        -- Row 2 (south tram) on top, row 1 (north tram) below — same as full mode
        hbar2.row:ClearAllPoints()
        hbar2.row:SetPoint("TOPLEFT", tramContainer, "TOPLEFT", PAD, -6)
        hbar2.row:SetSize(rowW, rowH)

        hbar1.row:ClearAllPoints()
        hbar1.row:SetPoint("TOP", hbar2.row, "BOTTOM", 0, -COMPACT_GAP)
        hbar1.row:SetSize(rowW, rowH)

        -- Resize station buttons to compact size
        for _, hb in ipairs({ hbar1, hbar2 }) do
            hb.btnA:SetSize(COMPACT_BTN_W, rowH)
            hb.btnB:SetSize(COMPACT_BTN_W, rowH)
            -- Shrink button label font
            hb.btnA.label:SetFontObject("GameFontNormalSmall")
            hb.btnB.label:SetFontObject("GameFontNormalSmall")
            -- bg auto-sizes via LEFT/RIGHT anchors between btnA and btnB
            hb.bg:SetHeight(COMPACT_HBAR_H + 4)
            -- Update fill widths to match the narrower bar
            local innerW = COMPACT_HBAR_W - 6 -- hbar inset is 3px each side
            hb.fillL:SetWidth(innerW / 2)
            hb.fillR:SetWidth(innerW / 2)
            -- Resize cursor and glow for the shorter bar height
            hb.cursor:SetSize(3, COMPACT_HBAR_H + 2)
            hb.glow:SetSize(8, COMPACT_HBAR_H + 4)
        end

        -- Hide decorative elements
        if tramContainer.portalL then
            tramContainer.portalL:Hide(); tramContainer.portalLLbl:Hide()
            tramContainer.portalR:Hide(); tramContainer.portalRLbl:Hide()
        end
        -- Hide track labels
        if hbar1.row.trackLabel then hbar1.row.trackLabel:Hide() end
        if hbar2.row.trackLabel then hbar2.row.trackLabel:Hide() end

        -- Position sayIcon to the right of the rows
        sayIcon:ClearAllPoints()
        sayIcon:SetPoint("LEFT", hbar1.row, "RIGHT", 6, 0)
        sayIcon:SetSize(20, 20)
        sayIcon:Show()
    end

    -- Restore full-size tram layout after leaving compact mode
    local function RestoreTramFull()
        local rowW = HBAR_W + STATION_BTN_W * 2 + 16
        local rowH = HBAR_H + 10

        -- Restore station buttons to full size
        for _, hb in ipairs({ hbar1, hbar2 }) do
            hb.btnA:SetSize(STATION_BTN_W, rowH)
            hb.btnB:SetSize(STATION_BTN_W, rowH)
            hb.btnA.label:SetFontObject("GameFontNormal")
            hb.btnB.label:SetFontObject("GameFontNormal")
            hb.bg:SetHeight(HBAR_H + 6)
            local innerW = HBAR_W - 6
            hb.fillL:SetWidth(innerW / 2)
            hb.fillR:SetWidth(innerW / 2)
            hb.cursor:SetSize(3, HBAR_H + 4)
            hb.glow:SetSize(10, HBAR_H + 6)
        end

        -- Show track labels
        if hbar1.row.trackLabel then hbar1.row.trackLabel:Show() end
        if hbar2.row.trackLabel then hbar2.row.trackLabel:Show() end

        -- Show portals
        if tramContainer.portalL then
            tramContainer.portalL:Show(); tramContainer.portalLLbl:Show()
            tramContainer.portalR:Show(); tramContainer.portalRLbl:Show()
        end

        -- Re-run full layout (repositions rows, frame size, portals, sayBtn)
        LayoutTramFull()
    end

    -- ── Reconfigure for a different lift ─────────────────────────────────────
    local function ReconfigureLift(liftID)
        local def = LIFTS[liftID]
        if not def then return end
        curLiftID = liftID
        p.curLiftID = liftID -- expose on frame for external guard
        isDual = def.dualLift and not settings.segmentInput and true or false
        isTram = def.horizontal and true or false
        if isDual then
            title:SetText(def.displayName .. "  |cff888888click segment to sync|r")
            -- Update bar labels for this lift type
            vbar1.label:SetText(def.barLabel1 or "Primary")
            vbar2.label:SetText(def.barLabel2 or "Secondary")
            -- Background image (e.g. screenshot showing platform positions)
            if def.dualBgTexture then
                dualBgTex:SetTexture(def.dualBgTexture)
                dualBgTex:Show()
            else
                dualBgTex:Hide()
            end
        else
            title:SetText(def.displayName .. "  |cff888888click phase to sync|r")
        end

        if isTram then
            ShowTram()
            sayBtn:SetText("|cffffcc00Say Position|r")

            -- Track labels (Bottom = North, Top = South)
            hbar1.row.trackLabel = hbar1.row.trackLabel or
                hbar1.row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hbar1.row.trackLabel:SetPoint("BOTTOMLEFT", hbar1.bg, "TOPLEFT", 0, 2)
            hbar1.row.trackLabel:SetText("NORTH TRAM (closer to entrance)")
            hbar1.row.trackLabel:SetTextColor(0.7, 0.7, 0.9)

            hbar2.row.trackLabel = hbar2.row.trackLabel or
                hbar2.row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hbar2.row.trackLabel:SetPoint("BOTTOMLEFT", hbar2.bg, "TOPLEFT", 0, 2)
            hbar2.row.trackLabel:SetText("SOUTH TRAM")
            hbar2.row.trackLabel:SetTextColor(0.9, 0.7, 0.7)

            local atA = def.fallTime + def.waitAtBottom + def.riseTime -- phase: arrived at A
            local atB = def.fallTime                                   -- phase: arrived at B
            local colorA = { 0.30, 0.55, 0.85 }                        -- IF blue
            local colorB = { 0.85, 0.55, 0.30 }                        -- SW orange
            local nameA = def.endpointA or "A"
            local nameB = def.endpointB or "B"

            for _, hb in ipairs({ hbar1, hbar2 }) do
                local primary = hb.isPrimary
                -- departure context derived from timer phase (no manual state to reset)
                -- Configure compact endpoint labels
                hb.compactLblA:SetText(nameA)
                hb.compactLblA:SetTextColor(colorA[1], colorA[2], colorA[3], primary and 0.9 or 0.6)
                hb.compactLblB:SetText(nameB)
                hb.compactLblB:SetTextColor(colorB[1], colorB[2], colorB[3], primary and 0.9 or 0.6)
                -- Configure station button A (left)
                hb.btnA.label:SetText(nameA)
                hb.btnA:SetBackdropColor(colorA[1] * 0.45, colorA[2] * 0.45, colorA[3] * 0.45, 0.95)
                hb.btnA:SetBackdropBorderColor(colorA[1], colorA[2], colorA[3], primary and 1.0 or 0.65)
                hb.btnA:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(nameA, 1, 0.82, 0, 1)
                    GameTooltip:AddLine("Click when tram arrives at " .. nameA, 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                hb.btnA:SetScript("OnClick", function()
                    if not activeLiftID then return end
                    local ld = LIFTS[activeLiftID]
                    local ps = atA
                    if not primary and ld.dualLift then
                        local off = ld.dualOffset or ld.cycleTime / 2
                        ps = (ps + off) % ld.cycleTime
                    end
                    PerformCalibrationClick(activeLiftID, ps, nameA .. (primary and "" or " (2nd tram)"))
                end)
                -- Configure station button B (right)
                hb.btnB.label:SetText(nameB)
                hb.btnB:SetBackdropColor(colorB[1] * 0.45, colorB[2] * 0.45, colorB[3] * 0.45, 0.95)
                hb.btnB:SetBackdropBorderColor(colorB[1], colorB[2], colorB[3], primary and 1.0 or 0.65)
                hb.btnB:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(nameB, 1, 0.82, 0, 1)
                    GameTooltip:AddLine("Click when tram arrives at " .. nameB, 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                hb.btnB:SetScript("OnClick", function()
                    if not activeLiftID then return end
                    local ld = LIFTS[activeLiftID]
                    local ps = atB
                    if not primary and ld.dualLift then
                        local off = ld.dualOffset or ld.cycleTime / 2
                        ps = (ps + off) % ld.cycleTime
                    end
                    PerformCalibrationClick(activeLiftID, ps, nameB .. (primary and "" or " (2nd tram)"))
                end)
            end

            if isCompact then
                LayoutTramCompact()
            else
                LayoutTramFull()
            end
        elseif isDual then
            sayBtn:SetText("|cffffcc00Say Warning|r")
            ShowDual()
            if isCompact then
                LayoutDualCompact()
            else
                LayoutDualFull()
            end
        else
            sayBtn:SetText("|cffffcc00Say Warning|r")
            dualContainer:Hide()
            ShowHorizontal()
            -- Restore single-lift frame dimensions
            if isCompact then
                p:SetSize(BAR_W_COMPACT + PAD * 2, 50)
            else
                p:SetSize(BAR_W_FULL + PAD * 2, 94)
            end
            -- Reposition and recolor horizontal segments
            local xOff = 0
            local segTimes = { def.fallTime, def.waitAtBottom, def.riseTime, def.waitAtTop }
            for i = 1, 4 do
                local w = (segTimes[i] / def.cycleTime) * barW
                segBtns[i]:ClearAllPoints()
                segBtns[i]:SetPoint("TOPLEFT", bar, "TOPLEFT", xOff, 0)
                segBtns[i]:SetSize(w, BAR_H)
                local c = def.segColors[i]
                segTextures[i]:SetColorTexture(c.r, c.g, c.b, 0.85)
                xOff = xOff + w
            end
            local labelFracs = {
                (def.fallTime * 0.5) / def.cycleTime,
                (def.fallTime + def.waitAtBottom * 0.5) / def.cycleTime,
                (def.fallTime + def.waitAtBottom + def.riseTime * 0.5) / def.cycleTime,
                (def.cycleTime - def.waitAtTop * 0.5) / def.cycleTime,
            }
            for i = 1, 4 do
                phaseLabels[i]:ClearAllPoints()
                phaseLabels[i]:SetPoint("CENTER", overlay, "LEFT", labelFracs[i] * barW, 0)
            end
        end
    end
    p.ReconfigureLift = ReconfigureLift

    -- ── Compact / full mode toggle ──────────────────────────────────────────
    function p.SetCompact(compact)
        if compact == isCompact then return end
        isCompact = compact

        if isTram then
            if isCompact then
                title:Hide(); sourceLabel:Hide(); sayBtn:Hide(); tyLabel:Hide()
                LayoutTramCompact()
            else
                title:Show(); sourceLabel:Show(); sayIcon:Hide()
                if AldorTaxDB and AldorTaxDB.ty and AldorTaxDB.ty > 0 then tyLabel:Show() end
                RestoreTramFull()
            end
        elseif isDual then
            if isCompact then
                title:Hide(); sourceLabel:Hide(); sayBtn:Hide(); tyLabel:Hide()
                vbar1.label:Hide(); vbar2.label:Hide()
                vbar1.phaseLbl:Hide(); vbar2.phaseLbl:Hide()
                LayoutDualCompact()
            else
                title:Show(); sourceLabel:Show(); sayIcon:Hide()
                if AldorTaxDB and AldorTaxDB.ty and AldorTaxDB.ty > 0 then tyLabel:Show() end
                vbar1.label:Show(); vbar2.label:Show()
                vbar1.phaseLbl:Show(); vbar2.phaseLbl:Show()
                LayoutDualFull()
            end
        else
            if isCompact then
                barW = BAR_W_COMPACT
                p:SetSize(BAR_W_COMPACT + PAD * 2 + 30, 50)
                title:Hide(); sourceLabel:Hide(); sayBtn:Hide(); tyLabel:Hide()
                for i = 1, 4 do phaseLabels[i]:Hide() end
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", PAD, -12)
                bar:SetSize(BAR_W_COMPACT, BAR_H)
                barBg:ClearAllPoints()
                barBg:SetPoint("TOPLEFT", PAD - 2, -10)
                barBg:SetSize(BAR_W_COMPACT + 4, BAR_H + 4)
                overlay:ClearAllPoints()
                overlay:SetPoint("TOPLEFT", PAD, -12)
                overlay:SetSize(BAR_W_COMPACT, BAR_H)

                sayIcon:ClearAllPoints()
                sayIcon:SetPoint("LEFT", barBg, "RIGHT", 10, 0)
                sayIcon:Show()
            else
                barW = BAR_W_FULL
                p:SetSize(BAR_W_FULL + PAD * 2, 94)
                title:Show(); sourceLabel:Show(); sayIcon:Hide()
                if AldorTaxDB and AldorTaxDB.ty and AldorTaxDB.ty > 0 then tyLabel:Show() end
                for i = 1, 4 do phaseLabels[i]:Show() end
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", PAD, -26)
                bar:SetSize(BAR_W_FULL, BAR_H)
                barBg:ClearAllPoints()
                barBg:SetPoint("TOPLEFT", PAD - 2, -24)
                barBg:SetSize(BAR_W_FULL + 4, BAR_H + 4)
                overlay:ClearAllPoints()
                overlay:SetPoint("TOPLEFT", PAD, -26)
                overlay:SetSize(BAR_W_FULL, BAR_H)
            end
            if curLiftID then ReconfigureLift(curLiftID) end
        end
    end

    -- ── Cursor update ───────────────────────────────────────────────────────
    local function UpdateHBarCursor(hbarObj, phase, def, primary)
        local barWidth = hbarObj.overlay:GetWidth()
        local pos = GetTramPosition(phase, def)
        -- Use tram-specific segment colors instead of elevator colors
        local seg
        if phase < def.fallTime then
            seg = 1
        elseif phase < def.fallTime + def.waitAtBottom then
            seg = 2
        elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
            seg = 3
        else
            seg = 4
        end
        local sc = def.segColors and def.segColors[seg]
        local r, g, b = sc and sc.r or 0.5, sc and sc.g or 0.5, sc and sc.b or 0.5
        local alpha = primary and 0.90 or 0.60
        local glowAlpha = primary and 0.25 or 0.12

        hbarObj.cursor:SetColorTexture(r, g, b, alpha)
        hbarObj.cursor:ClearAllPoints()
        hbarObj.cursor:SetPoint("CENTER", hbarObj.overlay, "LEFT", pos * barWidth, 0)
        hbarObj.glow:SetColorTexture(r, g, b, glowAlpha)
        hbarObj.glow:ClearAllPoints()
        hbarObj.glow:SetPoint("CENTER", hbarObj.cursor, "CENTER")

        local names = def.phaseNames or { "FALL", "BTM", "RISE", "TOP" }
        local phaseName
        if phase < def.fallTime then
            phaseName = names[1]
        elseif phase < def.fallTime + def.waitAtBottom then
            phaseName = names[2]
        elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
            phaseName = names[3]
        else
            phaseName = names[4]
        end
        hbarObj.phaseLbl:SetText(phaseName)
        hbarObj.phaseLbl:SetTextColor(r, g, b, primary and 0.85 or 0.55)
        -- Clamp phase label to stay within bar bounds
        local clampMin = 20
        local clampMax = barWidth - 20
        local cursorX = pos * barWidth
        hbarObj.phaseLbl:ClearAllPoints()
        if cursorX < clampMin then
            hbarObj.phaseLbl:SetPoint("BOTTOMLEFT", hbarObj.overlay, "TOPLEFT", 2, 2)
        elseif cursorX > clampMax then
            hbarObj.phaseLbl:SetPoint("BOTTOMRIGHT", hbarObj.overlay, "TOPRIGHT", -2, 2)
        else
            hbarObj.phaseLbl:SetPoint("BOTTOM", hbarObj.cursor, "TOP", 0, 2)
        end

        -- Countdown to next event (arrival or departure)
        local ttd
        if def.horizontal then
            if phase < def.fallTime then
                ttd = def.fallTime - phase                                   -- arriving at B
            elseif phase < def.fallTime + def.waitAtBottom then
                ttd = def.fallTime + def.waitAtBottom - phase                -- departing B
            elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
                ttd = def.fallTime + def.waitAtBottom + def.riseTime - phase -- arriving at A
            else
                ttd = def.cycleTime - phase                                  -- departing A
            end
        else
            ttd = def.cycleTime - phase
        end
        hbarObj.timeLabel:SetText(string.format("%.0fs", ttd))
        hbarObj.timeLabel:ClearAllPoints()
        if cursorX < clampMin then
            hbarObj.timeLabel:SetPoint("TOPLEFT", hbarObj.overlay, "BOTTOMLEFT", 2, -2)
        elseif cursorX > clampMax then
            hbarObj.timeLabel:SetPoint("TOPRIGHT", hbarObj.overlay, "BOTTOMRIGHT", -2, -2)
        else
            hbarObj.timeLabel:SetPoint("TOP", hbarObj.cursor, "BOTTOM", 0, -2)
        end
    end

    local function ParkHBarCursor(hbarObj)
        hbarObj.cursor:ClearAllPoints()
        hbarObj.cursor:SetPoint("CENTER", hbarObj.overlay, "LEFT", -5, 0)
        hbarObj.cursor:SetColorTexture(0.30, 0.30, 0.28, 0.40)
        hbarObj.glow:ClearAllPoints()
        hbarObj.glow:SetPoint("CENTER", hbarObj.cursor, "CENTER")
        hbarObj.glow:SetColorTexture(1, 1, 1, 0.05)
        hbarObj.timeLabel:SetText("")
        hbarObj.phaseLbl:SetText("")
    end

    function p.UpdateCursor()
        if not activeLiftID then return end
        local def = LIFTS[activeLiftID]
        local st  = liftState[activeLiftID]

        if isTram then
            -- Dual horizontal bars
            if st.lastSync <= 0 then
                ParkHBarCursor(hbar1)
                ParkHBarCursor(hbar2)
                sourceLabel:SetText("|cffff4400no sync|r")
                sayBtn:Hide()
                return
            end

            local phase1 = (GetTime() - st.lastSync) % def.cycleTime
            local phase2 = (phase1 + def.cycleTime / 2) % def.cycleTime
            UpdateHBarCursor(hbar1, phase1, def, true)
            UpdateHBarCursor(hbar2, phase2, def, false)

            if st.lastSyncSource then
                sourceLabel:SetText(string.format("|cff88ff88received from %s|r", st.lastSyncSource.name))
            else
                sourceLabel:SetText("|cff00cc00local|r")
            end
        elseif isDual then
            -- Dual vertical bars (each platform tracked independently)
            local hasSync1 = st.lastSync > 0
            local hasSync2 = st.lastSync2 > 0

            if not hasSync1 and not hasSync2 then
                vbar1.cursor:ClearAllPoints()
                vbar1.cursor:SetPoint("CENTER", vbar1.overlay, "BOTTOM", 0, -5)
                vbar1.glow:ClearAllPoints()
                vbar1.glow:SetPoint("CENTER", vbar1.cursor, "CENTER")
                vbar1.cursor:SetColorTexture(0.30, 0.30, 0.28, 0.40)
                vbar1.glow:SetColorTexture(1, 1, 1, 0.05)
                vbar1.timeLabel:SetText("")
                vbar1.phaseLbl:SetText("")
                vbar2.cursor:ClearAllPoints()
                vbar2.cursor:SetPoint("CENTER", vbar2.overlay, "BOTTOM", 0, -5)
                vbar2.glow:ClearAllPoints()
                vbar2.glow:SetPoint("CENTER", vbar2.cursor, "CENTER")
                vbar2.cursor:SetColorTexture(0.30, 0.30, 0.28, 0.40)
                vbar2.glow:SetColorTexture(1, 1, 1, 0.05)
                vbar2.timeLabel:SetText("")
                vbar2.phaseLbl:SetText("")
                sourceLabel:SetText("|cffff4400no sync|r")
                sayBtn:Hide()
                return
            end

            local sd = SecDef(def)

            -- Primary bar: from lastSync, or estimate from lastSync2 + offset
            local phase1
            if hasSync1 then
                phase1 = (GetTime() - st.lastSync) % def.cycleTime
            else
                local offset = def.dualOffset or def.cycleTime / 2
                phase1 = ((GetTime() - st.lastSync2) - offset) % def.cycleTime
            end
            -- Secondary bar: from lastSync2, or estimate from lastSync + offset
            local phase2
            if hasSync2 then
                phase2 = (GetTime() - st.lastSync2) % sd.cycleTime
            else
                local offset = def.dualOffset or def.cycleTime / 2
                phase2 = (phase1 + offset) % sd.cycleTime
            end
            -- Helper: get phase name from cycle phase using given segment def
            local function PhaseName(ph, d)
                if ph < d.fallTime then
                    return "FALL"
                elseif ph < d.fallTime + d.waitAtBottom then
                    return "BTM"
                elseif ph < d.fallTime + d.waitAtBottom + d.riseTime then
                    return "RISE"
                else
                    return "TOP"
                end
            end

            local h1 = GetLiftHeight(phase1, def)
            local h2 = GetLiftHeight(phase2, sd)
            local r1, g1, b1 = GetPhaseColor(phase1, def)
            local r2, g2, b2 = GetPhaseColor(phase2, sd)

            -- Primary bar: phase-colored cursor with glow
            vbar1.cursor:SetColorTexture(r1, g1, b1, 0.90)
            vbar1.cursor:ClearAllPoints()
            vbar1.cursor:SetPoint("CENTER", vbar1.overlay, "BOTTOM", 0, h1 * VBAR_H)
            vbar1.glow:SetColorTexture(r1, g1, b1, 0.25)
            vbar1.glow:ClearAllPoints()
            vbar1.glow:SetPoint("CENTER", vbar1.cursor, "CENTER")
            vbar1.phaseLbl:SetText(PhaseName(phase1, def))
            vbar1.phaseLbl:SetTextColor(r1, g1, b1, 0.85)
            vbar1.phaseLbl:ClearAllPoints()
            vbar1.phaseLbl:SetPoint("LEFT", vbar1.cursor, "RIGHT", 4, 0)
            vbar1.timeLabel:SetText(string.format("%.1fs", def.cycleTime - phase1))

            -- Secondary bar: dimmer phase-colored cursor
            vbar2.cursor:SetColorTexture(r2, g2, b2, 0.60)
            vbar2.cursor:ClearAllPoints()
            vbar2.cursor:SetPoint("CENTER", vbar2.overlay, "BOTTOM", 0, h2 * VBAR_H)
            vbar2.glow:SetColorTexture(r2, g2, b2, 0.12)
            vbar2.glow:ClearAllPoints()
            vbar2.glow:SetPoint("CENTER", vbar2.cursor, "CENTER")
            vbar2.phaseLbl:SetText(PhaseName(phase2, sd))
            vbar2.phaseLbl:SetTextColor(r2, g2, b2, 0.55)
            vbar2.phaseLbl:ClearAllPoints()
            vbar2.phaseLbl:SetPoint("RIGHT", vbar2.cursor, "LEFT", -4, 0)
            vbar2.timeLabel:SetText(string.format("%.1fs", sd.cycleTime - phase2))

            if st.lastSyncSource then
                sourceLabel:SetText(string.format("|cff88ff88received from %s|r", st.lastSyncSource.name))
            else
                sourceLabel:SetText("|cff00cc00local|r")
            end
        else
            -- Single horizontal bar
            if st.lastSync <= 0 then
                cursor:ClearAllPoints()
                cursor:SetPoint("CENTER", overlay, "LEFT", -10, 0)
                cursorGlow:ClearAllPoints()
                cursorGlow:SetPoint("CENTER", cursor, "CENTER", 0, 0)
                timeLabel:SetText("")
                sourceLabel:SetText("|cffff4400no sync|r")
                sayBtn:Hide()
                return
            end

            local phase = (GetTime() - st.lastSync) % def.cycleTime
            local xPos  = (phase / def.cycleTime) * barW
            cursor:ClearAllPoints()
            cursor:SetPoint("CENTER", overlay, "LEFT", xPos, 0)
            cursorGlow:ClearAllPoints()
            cursorGlow:SetPoint("CENTER", cursor, "CENTER", 0, 0)
            local ttd = def.cycleTime - phase
            timeLabel:SetText(string.format("%.1fs", ttd))

            if st.lastSyncSource then
                sourceLabel:SetText(string.format("|cff88ff88received from %s|r", st.lastSyncSource.name))
            else
                sourceLabel:SetText("|cff00cc00local|r")
            end
        end

        -- Show Say button
        if isCompact or st.lastSync <= 0 then
            sayBtn:Hide()
        elseif isTram then
            -- Tram: always show Report Position when synced (transit info is useful)
            sayBtn:Show()
        else
            local topStart = def.fallTime + def.waitAtBottom + def.riseTime
            local phase = (GetTime() - st.lastSync) % def.cycleTime
            local showSay = phase >= topStart
            if def.dualLift then
                local sd = SecDef(def)
                local topStart2 = sd.fallTime + sd.waitAtBottom + sd.riseTime
                local phase2
                if st.lastSync2 > 0 then
                    phase2 = (GetTime() - st.lastSync2) % sd.cycleTime
                else
                    local offset = def.dualOffset or def.cycleTime / 2
                    phase2 = (phase + offset) % sd.cycleTime
                end
                showSay = showSay or phase2 >= topStart2
            end
            if showSay then sayBtn:Show() else sayBtn:Hide() end
        end
    end

    return p
end


-- ─── Dev panel ─────────────────────────────────────────────────────────────

local devPanel

local function BuildDevPanel()
    local DEV_BAR_W = 420
    local DEV_BAR_H = 18
    local DEV_PAD   = 12

    local p         = CreateFrame("Frame", "AldorTaxDevPanel", UIParent, "BackdropTemplate")
    p:SetSize(DEV_BAR_W + DEV_PAD * 2, 370)
    p:SetPoint("CENTER", 300, 0)
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    p:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    p:SetBackdropBorderColor(0.50, 0.40, 0.20, 0.80)

    -- Title
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", DEV_PAD, -8)
    title:SetTextColor(1, 0.82, 0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() p:Hide() end)

    -- ── Helper: make a labeled number input ─────────────────────────────────
    local function MakeInput(parent, label, x, y, width, tooltip)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", x, y)
        lbl:SetText(label)
        lbl:SetTextColor(0.75, 0.75, 0.65)

        local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", x, y - 12)
        bg:SetSize(width, 20)
        bg:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 4,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        bg:SetBackdropColor(0, 0, 0, 0.8)
        bg:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)

        local eb = CreateFrame("EditBox", nil, bg)
        eb:SetPoint("TOPLEFT", 4, -2)
        eb:SetPoint("BOTTOMRIGHT", -4, 2)
        eb:SetFontObject("ChatFontSmall")
        eb:SetAutoFocus(false)
        eb:SetNumeric(false) -- we handle decimals ourselves
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        if tooltip then
            eb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            eb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        return eb, lbl
    end

    -- ── Segment bars ────────────────────────────────────────────────────────
    local SEG_NAMES = { "FALL", "BTM", "RISE", "TOP" }

    local function MakeSegBar(parent, yTop, label, alpha)
        local row = {}
        row.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("TOPLEFT", DEV_PAD, yTop)
        row.label:SetText(label)
        row.label:SetTextColor(0.85, 0.78, 0.50)

        row.bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row.bg:SetPoint("TOPLEFT", DEV_PAD - 1, yTop - 13)
        row.bg:SetSize(DEV_BAR_W + 2, DEV_BAR_H + 2)
        row.bg:SetBackdrop({
            bgFile = "Interface/ChatFrame/ChatFrameBackground",
            tile = true,
            tileSize = 4,
        })
        row.bg:SetBackdropColor(0.02, 0.02, 0.04, 0.9)

        row.bar = CreateFrame("Frame", nil, parent)
        row.bar:SetPoint("TOPLEFT", DEV_PAD, yTop - 14)
        row.bar:SetSize(DEV_BAR_W, DEV_BAR_H)

        row.segs = {}
        row.segLabels = {}
        row.segBtns = {}
        for i = 1, 4 do
            local seg = row.bar:CreateTexture(nil, "ARTWORK")
            seg:SetHeight(DEV_BAR_H)
            row.segs[i] = seg

            local lbl = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetTextColor(1, 1, 1, 0.85)
            row.segLabels[i] = lbl

            -- Clickable button overlaying each segment
            local btn = CreateFrame("Button", nil, row.bar)
            btn:RegisterForClicks("LeftButtonUp")
            btn:SetHeight(DEV_BAR_H)
            btn:SetFrameLevel(row.bar:GetFrameLevel() + 3)
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetColorTexture(1, 1, 1, 0.12)
            hl:SetAllPoints()
            hl:SetBlendMode("ADD")
            row.segBtns[i] = btn
        end

        row.overlay = CreateFrame("Frame", nil, parent)
        row.overlay:SetPoint("TOPLEFT", DEV_PAD, yTop - 14)
        row.overlay:SetSize(DEV_BAR_W, DEV_BAR_H)
        row.overlay:SetFrameLevel(row.bar:GetFrameLevel() + 5)
        row.overlay:EnableMouse(false)

        row.cursor = row.overlay:CreateTexture(nil, "OVERLAY", nil, 2)
        row.cursor:SetColorTexture(1, 1, 1, 0.95)
        row.cursor:SetSize(3, DEV_BAR_H + 4)

        row.glow = row.overlay:CreateTexture(nil, "OVERLAY", nil, 1)
        row.glow:SetColorTexture(1, 1, 1, 0.20)
        row.glow:SetSize(9, DEV_BAR_H + 6)
        row.glow:SetBlendMode("ADD")

        row.timeLabel = row.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.timeLabel:SetShadowOffset(1, -1)
        row.timeLabel:SetShadowColor(0, 0, 0, 1)

        row.alpha = alpha or 1.0
        return row
    end

    local bar1 = MakeSegBar(p, -28, "Primary", 1.0)
    local bar2 = MakeSegBar(p, -70, "Secondary (offset)", 0.65)

    -- ── Layout segments for a bar ───────────────────────────────────────────
    local function LayoutBar(row, def, segOverrides, isPrimary)
        local ft  = segOverrides and segOverrides.fallTime or def.fallTime
        local wb  = segOverrides and segOverrides.waitAtBottom or def.waitAtBottom
        local rt  = segOverrides and segOverrides.riseTime or def.riseTime
        local wt  = segOverrides and segOverrides.waitAtTop or def.waitAtTop
        local cyc = ft + wb + rt + wt
        if cyc <= 0 then return end
        local times = { ft, wb, rt, wt }
        local starts = { 0, ft, ft + wb, ft + wb + rt }
        local xOff = 0
        for i = 1, 4 do
            local w = (times[i] / cyc) * DEV_BAR_W
            row.segs[i]:ClearAllPoints()
            row.segs[i]:SetPoint("TOPLEFT", row.bar, "TOPLEFT", xOff, 0)
            row.segs[i]:SetSize(w, DEV_BAR_H)
            local c = def.segColors and def.segColors[i]
            local a = row.alpha
            if c then
                row.segs[i]:SetColorTexture(c.r, c.g, c.b, 0.85 * a)
            else
                row.segs[i]:SetColorTexture(0.3, 0.3, 0.3, 0.5 * a)
            end
            row.segs[i]:Show()
            row.segLabels[i]:ClearAllPoints()
            row.segLabels[i]:SetPoint("CENTER", row.bar, "TOPLEFT", xOff + w / 2, -DEV_BAR_H / 2)
            row.segLabels[i]:SetText(string.format("%s\n%.2f", SEG_NAMES[i], times[i]))
            row.segLabels[i]:SetAlpha(a)
            row.segLabels[i]:Show()
            -- Position and wire up click button
            local btn = row.segBtns[i]
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", row.bar, "TOPLEFT", xOff, 0)
            btn:SetSize(w, DEV_BAR_H)
            local segStart = starts[i]
            local segName = SEG_NAMES[i]
            btn:SetScript("OnClick", function()
                if not devLiftID then return end
                local curDef = LIFTS[devLiftID]
                if not curDef then return end
                if isPrimary then
                    PerformCalibrationClick(devLiftID, segStart, segName)
                else
                    local st = liftState[devLiftID]
                    if not st then return end
                    local now = GetTime() - CLICK_REACTION_TIME
                    st.lastSync2 = now - segStart
                    Log(string.format("|cff00ff00AldorTax: %s synced at %s (%s)|r",
                        curDef.displayName, segName, curDef.barLabel2 or "Secondary"))
                end
            end)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(string.format("Click to sync at %s", segName), 1, 0.82, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:Show()
            xOff = xOff + w
        end
    end

    local function UpdateBarCursor(row, phase, def, segOverrides)
        local ft  = segOverrides and segOverrides.fallTime or def.fallTime
        local wb  = segOverrides and segOverrides.waitAtBottom or def.waitAtBottom
        local rt  = segOverrides and segOverrides.riseTime or def.riseTime
        local wt  = segOverrides and segOverrides.waitAtTop or def.waitAtTop
        local cyc = ft + wb + rt + wt
        if cyc <= 0 then return end
        local xPos = (phase / cyc) * DEV_BAR_W
        local a = row.alpha
        -- Segment color for cursor
        local seg
        if phase < ft then
            seg = 1
        elseif phase < ft + wb then
            seg = 2
        elseif phase < ft + wb + rt then
            seg = 3
        else
            seg = 4
        end
        local c = def.segColors and def.segColors[seg]
        local r, g, b = c and c.r or 0.8, c and c.g or 0.8, c and c.b or 0.8
        row.cursor:SetColorTexture(r, g, b, 0.95 * a)
        row.cursor:ClearAllPoints()
        row.cursor:SetPoint("CENTER", row.overlay, "LEFT", xPos, 0)
        row.glow:SetColorTexture(r, g, b, 0.25 * a)
        row.glow:ClearAllPoints()
        row.glow:SetPoint("CENTER", row.cursor, "CENTER")
        local ttd = cyc - phase
        row.timeLabel:SetText(string.format("%.1fs", ttd))
        row.timeLabel:SetAlpha(a)
        row.timeLabel:ClearAllPoints()
        row.timeLabel:SetPoint("BOTTOM", row.cursor, "TOP", 0, 1)
    end

    -- ── Primary segment time inputs ────────────────────────────────────────
    local inputY = -112

    local segHdr = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    segHdr:SetPoint("TOPLEFT", DEV_PAD, inputY)
    segHdr:SetText("Primary Segments")
    segHdr:SetTextColor(0.85, 0.78, 0.50)

    local colW        = 70
    local inputStartX = DEV_PAD
    local inputStartY = inputY - 18

    local ebFall, _   = MakeInput(p, "Fall", inputStartX, inputStartY, colW, "Fall duration (seconds)")
    local ebBottom, _ = MakeInput(p, "Bottom", inputStartX + colW + 10, inputStartY, colW, "Wait at bottom (seconds)")
    local ebRise, _   = MakeInput(p, "Rise", inputStartX + (colW + 10) * 2, inputStartY, colW, "Rise duration (seconds)")
    local ebTop, _    = MakeInput(p, "Top", inputStartX + (colW + 10) * 3, inputStartY, colW, "Wait at top (seconds)")

    local cycleLabel  = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cycleLabel:SetPoint("TOPLEFT", inputStartX + (colW + 10) * 4 + 5, inputStartY - 12)
    cycleLabel:SetTextColor(0.6, 0.8, 0.6)

    -- ── Secondary segment time inputs ───────────────────────────────────────
    local sec2Y = inputStartY - 44

    local seg2Hdr = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    seg2Hdr:SetPoint("TOPLEFT", DEV_PAD, sec2Y)
    seg2Hdr:SetText("Secondary Segments")
    seg2Hdr:SetTextColor(0.70, 0.65, 0.45)

    local sec2StartY   = sec2Y - 18

    local ebFall2, _   = MakeInput(p, "Fall", inputStartX, sec2StartY, colW, "Secondary fall duration (seconds)")
    local ebBottom2, _ = MakeInput(p, "Bottom", inputStartX + colW + 10, sec2StartY, colW,
        "Secondary wait at bottom (seconds)")
    local ebRise2, _   = MakeInput(p, "Rise", inputStartX + (colW + 10) * 2, sec2StartY, colW,
        "Secondary rise duration (seconds)")
    local ebTop2, _    = MakeInput(p, "Top", inputStartX + (colW + 10) * 3, sec2StartY, colW,
        "Secondary wait at top (seconds)")

    local cycleLabel2  = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cycleLabel2:SetPoint("TOPLEFT", inputStartX + (colW + 10) * 4 + 5, sec2StartY - 12)
    cycleLabel2:SetTextColor(0.6, 0.8, 0.6)

    -- Group secondary elements for show/hide
    local sec2Elements = { seg2Hdr, ebFall2:GetParent(), ebBottom2:GetParent(), ebRise2:GetParent(), ebTop2:GetParent(),
        cycleLabel2 }

    -- Offset input
    local offsetY = sec2StartY - 42

    local offsetHdr = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetHdr:SetPoint("TOPLEFT", DEV_PAD, offsetY)
    offsetHdr:SetText("Dual Offset")
    offsetHdr:SetTextColor(0.85, 0.78, 0.50)

    local ebOffset, _ = MakeInput(p, "Offset (s)", DEV_PAD, offsetY - 18, 80,
        "Phase offset of secondary lift from primary (seconds)")

    local offsetInfo = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offsetInfo:SetPoint("LEFT", ebOffset:GetParent(), "RIGHT", 8, 0)
    offsetInfo:SetTextColor(0.6, 0.6, 0.6)

    -- ── Apply / Revert buttons ──────────────────────────────────────────────
    local btnY = offsetY - 58

    local applyBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    applyBtn:SetSize(90, 22)
    applyBtn:SetPoint("TOPLEFT", DEV_PAD, btnY)
    applyBtn:SetText("Apply")
    applyBtn:SetNormalFontObject("GameFontNormalSmall")

    local revertBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    revertBtn:SetSize(90, 22)
    revertBtn:SetPoint("LEFT", applyBtn, "RIGHT", 8, 0)
    revertBtn:SetText("Revert")
    revertBtn:SetNormalFontObject("GameFontNormalSmall")

    local statusLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusLabel:SetPoint("LEFT", revertBtn, "RIGHT", 10, 0)
    statusLabel:SetTextColor(0.5, 0.8, 0.5)

    -- ── State ───────────────────────────────────────────────────────────────
    local devLiftID = nil
    local origDef = nil       -- stashed original values for Revert
    local devOverrides = nil  -- { fallTime, waitAtBottom, riseTime, waitAtTop }
    local devOverrides2 = nil -- secondary overrides
    local devOffset = nil

    local function ReadInputs()
        local ft = tonumber(ebFall:GetText())
        local wb = tonumber(ebBottom:GetText())
        local rt = tonumber(ebRise:GetText())
        local wt = tonumber(ebTop:GetText())
        local off = tonumber(ebOffset:GetText())
        return ft, wb, rt, wt, off
    end

    local function ReadInputs2()
        local ft = tonumber(ebFall2:GetText())
        local wb = tonumber(ebBottom2:GetText())
        local rt = tonumber(ebRise2:GetText())
        local wt = tonumber(ebTop2:GetText())
        return ft, wb, rt, wt
    end

    local function PopulateInputs(def)
        ebFall:SetText(string.format("%.2f", def.fallTime))
        ebBottom:SetText(string.format("%.2f", def.waitAtBottom))
        ebRise:SetText(string.format("%.2f", def.riseTime))
        ebTop:SetText(string.format("%.2f", def.waitAtTop))
        local cyc = def.fallTime + def.waitAtBottom + def.riseTime + def.waitAtTop
        cycleLabel:SetText(string.format("= %.2fs", cyc))
        -- Secondary: use dedicated values or fall back to primary
        local sd = SecDef(def)
        ebFall2:SetText(string.format("%.2f", sd.fallTime))
        ebBottom2:SetText(string.format("%.2f", sd.waitAtBottom))
        ebRise2:SetText(string.format("%.2f", sd.riseTime))
        ebTop2:SetText(string.format("%.2f", sd.waitAtTop))
        local cyc2 = sd.fallTime + sd.waitAtBottom + sd.riseTime + sd.waitAtTop
        cycleLabel2:SetText(string.format("= %.2fs", cyc2))
        local off = def.dualOffset or (def.dualLift and def.cycleTime / 2 or 0)
        ebOffset:SetText(string.format("%.2f", off))
    end

    local function UpdateCycleLabels()
        local ft, wb, rt, wt = ReadInputs()
        if ft and wb and rt and wt then
            cycleLabel:SetText(string.format("= %.2fs", ft + wb + rt + wt))
        end
        local ft2, wb2, rt2, wt2 = ReadInputs2()
        if ft2 and wb2 and rt2 and wt2 then
            cycleLabel2:SetText(string.format("= %.2fs", ft2 + wb2 + rt2 + wt2))
        end
    end

    -- Auto-update cycle labels on any input change
    for _, eb in ipairs({ ebFall, ebBottom, ebRise, ebTop, ebFall2, ebBottom2, ebRise2, ebTop2 }) do
        eb:SetScript("OnTextChanged", function() UpdateCycleLabels() end)
    end

    local function ConfigureLift(liftID)
        local def = LIFTS[liftID]
        if not def then return end
        devLiftID = liftID
        -- Stash originals on first configure (or if switching lifts)
        if not origDef or origDef._id ~= liftID then
            origDef = {
                _id           = liftID,
                fallTime      = def.fallTime,
                waitAtBottom  = def.waitAtBottom,
                riseTime      = def.riseTime,
                waitAtTop     = def.waitAtTop,
                cycleTime     = def.cycleTime,
                dualOffset    = def.dualOffset,
                fallTime2     = def.fallTime2,
                waitAtBottom2 = def.waitAtBottom2,
                riseTime2     = def.riseTime2,
                waitAtTop2    = def.waitAtTop2,
                cycleTime2    = def.cycleTime2,
            }
        end
        devOverrides = nil
        devOverrides2 = nil
        devOffset = nil
        title:SetText(string.format("Dev: %s", def.displayName))
        PopulateInputs(def)
        LayoutBar(bar1, def, nil, true)
        if def.dualLift then
            bar2.label:SetText(string.format("Secondary (%s)",
                def.barLabel2 or "Secondary"))
            bar2.bg:Show(); bar2.bar:Show(); bar2.overlay:Show()
            bar2.label:Show()
            local sd = SecDef(def)
            LayoutBar(bar2, sd, nil, false)
            for _, el in ipairs(sec2Elements) do el:Show() end
            offsetHdr:Show(); ebOffset:GetParent():Show(); offsetInfo:Show()
        else
            bar2.bg:Hide(); bar2.bar:Hide(); bar2.overlay:Hide()
            bar2.label:Hide()
            for i = 1, 4 do
                bar2.segs[i]:Hide(); bar2.segLabels[i]:Hide()
            end
            bar2.cursor:Hide(); bar2.glow:Hide(); bar2.timeLabel:SetText("")
            for _, el in ipairs(sec2Elements) do el:Hide() end
            offsetHdr:Hide(); ebOffset:GetParent():Hide(); offsetInfo:Hide()
        end
        statusLabel:SetText("")
    end
    p.ConfigureLift = ConfigureLift

    -- Apply: write input values into the live LIFTS definition
    applyBtn:SetScript("OnClick", function()
        if not devLiftID then return end
        local def = LIFTS[devLiftID]
        if not def then return end
        local ft, wb, rt, wt, off = ReadInputs()
        if not (ft and wb and rt and wt) then
            statusLabel:SetText("|cffff4400Invalid primary input|r")
            return
        end
        if ft <= 0 or wb <= 0 or rt <= 0 or wt <= 0 then
            statusLabel:SetText("|cffff4400All primary values must be > 0|r")
            return
        end
        def.fallTime     = ft
        def.waitAtBottom = wb
        def.riseTime     = rt
        def.waitAtTop    = wt
        def.cycleTime    = ft + wb + rt + wt
        if off and def.dualLift then
            def.dualOffset = off
            devOffset = off
        end
        devOverrides = { fallTime = ft, waitAtBottom = wb, riseTime = rt, waitAtTop = wt }
        LayoutBar(bar1, def, devOverrides, true)
        -- Secondary segments
        if def.dualLift then
            local ft2, wb2, rt2, wt2 = ReadInputs2()
            if not (ft2 and wb2 and rt2 and wt2) then
                statusLabel:SetText("|cffff4400Invalid secondary input|r")
                return
            end
            if ft2 <= 0 or wb2 <= 0 or rt2 <= 0 or wt2 <= 0 then
                statusLabel:SetText("|cffff4400All secondary values must be > 0|r")
                return
            end
            def.fallTime2     = ft2
            def.waitAtBottom2 = wb2
            def.riseTime2     = rt2
            def.waitAtTop2    = wt2
            def.cycleTime2    = ft2 + wb2 + rt2 + wt2
            devOverrides2     = { fallTime = ft2, waitAtBottom = wb2, riseTime = rt2, waitAtTop = wt2 }
            local sd          = SecDef(def)
            LayoutBar(bar2, sd, devOverrides2, false)
        end
        -- Refresh the sync UI if it exists
        if syncUI and syncUI.ReconfigureLift then
            syncUI.ReconfigureLift(devLiftID)
        end
        local msg = string.format("|cff88ff88Applied (pri=%.2fs", def.cycleTime)
        if def.cycleTime2 then
            msg = msg .. string.format(", sec=%.2fs", def.cycleTime2)
        end
        statusLabel:SetText(msg .. ")|r")
    end)

    -- Revert: restore original values
    revertBtn:SetScript("OnClick", function()
        if not devLiftID or not origDef then return end
        local def = LIFTS[devLiftID]
        if not def then return end
        def.fallTime     = origDef.fallTime
        def.waitAtBottom = origDef.waitAtBottom
        def.riseTime     = origDef.riseTime
        def.waitAtTop    = origDef.waitAtTop
        def.cycleTime    = origDef.cycleTime
        if origDef.dualOffset then def.dualOffset = origDef.dualOffset end
        -- Restore secondary segments
        def.fallTime2     = origDef.fallTime2
        def.waitAtBottom2 = origDef.waitAtBottom2
        def.riseTime2     = origDef.riseTime2
        def.waitAtTop2    = origDef.waitAtTop2
        def.cycleTime2    = origDef.cycleTime2
        devOverrides      = nil
        devOverrides2     = nil
        devOffset         = nil
        PopulateInputs(def)
        LayoutBar(bar1, def, nil, true)
        if def.dualLift then
            local sd = SecDef(def)
            LayoutBar(bar2, sd, nil, false)
        end
        if syncUI and syncUI.ReconfigureLift then
            syncUI.ReconfigureLift(devLiftID)
        end
        statusLabel:SetText("|cffffff00Reverted|r")
    end)

    -- ── OnUpdate: animate cursors ───────────────────────────────────────────
    p:SetScript("OnUpdate", function()
        if not devLiftID then return end
        local def = LIFTS[devLiftID]
        local st = liftState[devLiftID]
        if not def or not st or st.lastSync <= 0 then
            bar1.cursor:Hide(); bar1.glow:Hide(); bar1.timeLabel:SetText("")
            bar2.cursor:Hide(); bar2.glow:Hide(); bar2.timeLabel:SetText("")
            return
        end
        local cyc = def.cycleTime
        local phase1 = (GetTime() - st.lastSync) % cyc
        bar1.cursor:Show(); bar1.glow:Show()
        UpdateBarCursor(bar1, phase1, def, devOverrides)

        if def.dualLift then
            local sd = SecDef(def)
            local phase2
            if st.lastSync2 > 0 then
                phase2 = (GetTime() - st.lastSync2) % sd.cycleTime
            else
                local off = devOffset or def.dualOffset or cyc / 2
                phase2 = (phase1 + off) % sd.cycleTime
            end
            bar2.cursor:Show(); bar2.glow:Show()
            UpdateBarCursor(bar2, phase2, sd, devOverrides2)
            offsetInfo:SetText(string.format("phase2 = %.2fs", phase2))
        end
    end)

    p:Hide()
    return p
end

-- ─── Log panel ──────────────────────────────────────────────────────────────

local logPanel

local function BuildLogPanel()
    local p = CreateFrame("Frame", "AldorTaxLogPanel", UIParent, "BackdropTemplate")
    p:SetSize(520, 340)
    p:SetPoint("CENTER", 0, 60)
    p:SetFrameStrata("DIALOG")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText("AldorTax Log  |cff888888(Ctrl+A, Ctrl+C to copy)|r")

    local clearBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    clearBtn:SetSize(70, 22)
    clearBtn:SetText("Clear")
    clearBtn:SetPoint("TOPLEFT", 16, -38)
    clearBtn:SetScript("OnClick", function()
        logLines = {}
        if logEB then logEB:SetText("") end
    end)

    local closeBtn = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() p:Hide() end)

    local ebFrame = CreateFrame("Frame", nil, p, "BackdropTemplate")
    ebFrame:SetPoint("TOPLEFT", 16, -68)
    ebFrame:SetPoint("BOTTOMRIGHT", -16, 16)
    ebFrame:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        tile = true,
        tileSize = 5,
        edgeSize = 0,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ebFrame:SetBackdropColor(0, 0, 0, 0.9)

    local eb = CreateFrame("EditBox", nil, ebFrame)
    eb:SetPoint("TOPLEFT", 4, -4)
    eb:SetPoint("BOTTOMRIGHT", -4, 4)
    eb:SetMultiLine(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)
    eb:EnableMouse(true)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    logEB = eb
    if #logLines > 0 then
        eb:SetText(table.concat(logLines, "\n"))
        eb:SetCursorPosition(0)
    end

    p:Hide()
    return p
end

-- ─── Interface Options panel ────────────────────────────────────────────────

local function SaveSettings()
    if AldorTaxDB then
        local copy = {}
        for k, v in pairs(settings) do copy[k] = v end
        AldorTaxDB.settings = copy
    end
end

local function MakeCheckbox(parent, anchorTo, anchorOffset, key, label, tooltip)
    local cb = CreateFrame("CheckButton", "AldorTaxOpt_" .. key, parent)
    cb:SetSize(26, 26)
    if anchorTo then
        cb:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, anchorOffset or -4)
    else
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -48)
    end
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb.label = text
    cb:SetHitRectInsets(0, -text:GetStringWidth() - 4, 0, 0)
    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        settings[key] = val
        SaveSettings()
    end)
    cb.Refresh = function() cb:SetChecked(settings[key]) end
    cb.Refresh()
    return cb
end

local optionsPanel = nil

BuildOptionsPanel = function()
    if optionsPanel then return optionsPanel end

    local panel = CreateFrame("Frame", "AldorTaxOptionsPanel", UIParent)
    panel.name = "AldorTax"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AldorTax")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Elevator tracker — TBC Classic Anniversary")
    sub:SetTextColor(0.7, 0.7, 0.7)

    local behHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    behHdr:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    behHdr:SetText("Behaviour")

    local cbThank   = MakeCheckbox(panel, behHdr, -4, "autoThank",
        "Auto-thank warnings", "Automatically /thank players who announce lift departures in /say.")
    local alwaysHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    alwaysHdr:SetPoint("TOPLEFT", cbThank, "BOTTOMLEFT", 0, -6)
    alwaysHdr:SetText("Always show:")
    alwaysHdr:SetTextColor(0.9, 0.9, 0.9)

    local cbAlways = MakeCheckbox(panel, nil, nil, "alwaysShowUI",
        "Calibration UI", "Show the full progress bar panel instead of blinking text warnings.")
    cbAlways:ClearAllPoints()
    cbAlways:SetPoint("LEFT", alwaysHdr, "RIGHT", 4, 0)

    local cbCompact = MakeCheckbox(panel, nil, nil, "alwaysCompact",
        "Compact UI", "Use the sleek, minimalist version of the progress bar.")
    cbCompact:ClearAllPoints()
    cbCompact:SetPoint("LEFT", cbAlways.label, "RIGHT", 12, 0)

    -- Mutual exclusion: enabling one disables the other
    cbAlways:HookScript("OnClick", function(self)
        if self:GetChecked() and settings.alwaysCompact then
            settings.alwaysCompact = false
            SaveSettings()
            cbCompact:Refresh()
        end
    end)
    cbCompact:HookScript("OnClick", function(self)
        if self:GetChecked() and settings.alwaysShowUI then
            settings.alwaysShowUI = false
            SaveSettings()
            cbAlways:Refresh()
        end
    end)

    local liftHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    liftHdr:SetPoint("TOPLEFT", alwaysHdr, "BOTTOMLEFT", 0, -24)
    liftHdr:SetText("Lifts")

    -- Row 1
    local cbAldor = MakeCheckbox(panel, liftHdr, -4, "enableAldor",
        "Aldor Rise", "Track the Aldor Rise elevator in Shattrath City.")
    local cbGreatLift = MakeCheckbox(panel, nil, nil, "enableGreatLift",
        "Great Lift", "Track the Great Lift between Barrens and Thousand Needles.")
    cbGreatLift:ClearAllPoints()
    cbGreatLift:SetPoint("LEFT", cbAldor.label, "RIGHT", 16, 0)
    local cbTram = MakeCheckbox(panel, nil, nil, "enableTram",
        "Deeprun Tram", "Track the Deeprun Tram between Ironforge and Stormwind.")
    cbTram:ClearAllPoints()
    cbTram:SetPoint("LEFT", cbGreatLift.label, "RIGHT", 16, 0)
    -- Row 2
    local cbTBLift = MakeCheckbox(panel, cbAldor, nil, "enableTBLift",
        "Thunder Bluff Lift", "Track the Thunder Bluff elevators.")
    local cbStormspire = MakeCheckbox(panel, nil, nil, "enableStormspire",
        "Stormspire Lift", "Track the Stormspire elevator in Netherstorm.")
    cbStormspire:ClearAllPoints()
    cbStormspire:SetPoint("LEFT", cbTBLift.label, "RIGHT", 16, 0)
    local cbSSC = MakeCheckbox(panel, nil, nil, "enableSSC",
        "SSC Elevator", "Track the Serpentshrine Cavern elevator.")
    cbSSC:ClearAllPoints()
    cbSSC:SetPoint("LEFT", cbStormspire.label, "RIGHT", 16, 0)

    local safetyHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    safetyHdr:SetPoint("TOPLEFT", cbTBLift, "BOTTOMLEFT", 0, -16)
    safetyHdr:SetText("Safety")

    local cbFallSave = MakeCheckbox(panel, safetyHdr, -4, "fallSaveAlert",
        "Fall-save alert",
        "When you fall near a lift, show a clickable button to cast a class save spell (Slow Fall, Levitate, Divine Shield, etc).")

    -- ─── Dev tools (hidden unless devTools is enabled) ─────────────────────
    local devHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    devHdr:SetPoint("TOPLEFT", cbFallSave, "BOTTOMLEFT", 0, -16)
    devHdr:SetText("Developer")

    local cbDevTools = MakeCheckbox(panel, devHdr, -4, "devTools",
        "Show dev tools",
        "Toggle visibility of developer/diagnostic options below.")

    local cbVerbose = MakeCheckbox(panel, cbDevTools, nil, "verbose",
        "Verbose chat",
        "Print sync and calibration messages to the chat window. Messages are always recorded in the log (/atax log).")
    local cbDebug = MakeCheckbox(panel, nil, nil, "debugChannel",
        "Debug logging",
        "Log outgoing sync messages and other diagnostic info.")
    cbDebug:ClearAllPoints()
    cbDebug:SetPoint("LEFT", cbVerbose.label, "RIGHT", 12, 0)
    local cbSegInput = MakeCheckbox(panel, nil, nil, "segmentInput",
        "Segment calibration",
        "Show 4-segment calibration bar for dual lifts instead of the top/bottom click UI. For measuring individual phase durations.")
    cbSegInput:ClearAllPoints()
    cbSegInput:SetPoint("LEFT", cbDebug.label, "RIGHT", 12, 0)

    local devWidgets = { cbVerbose, cbDebug, cbSegInput }

    -- Dev action buttons (migrated from slash commands)
    local function MakeDevButton(anchorTo, yOff, label, onClick)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(170, 22)
        b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, yOff or -6)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        devWidgets[#devWidgets + 1] = b
        return b
    end

    local btnLog = MakeDevButton(cbVerbose, -8, "Toggle log panel", function()
        if not logPanel then logPanel = BuildLogPanel() end
        if logPanel:IsShown() then logPanel:Hide() else logPanel:Show() end
    end)

    local btnDevTimer = MakeDevButton(btnLog, nil, "Toggle dev timer overlay", function()
        if devTimerFrame:IsShown() then
            devTimerFrame:Hide()
            devTimerStart = nil
        else
            devTimerStart = GetTime()
            devTimerFrame:Show()
        end
    end)

    -- Lift selector shared by timing + segment tuning actions
    local liftIDs = {}
    for id in pairs(LIFTS) do liftIDs[#liftIDs + 1] = id end
    table.sort(liftIDs)
    local selectedLift = liftIDs[1] or "aldor"

    local liftLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    liftLabel:SetPoint("TOPLEFT", btnDevTimer, "BOTTOMLEFT", 0, -10)
    liftLabel:SetText("Lift for dev actions:")
    devWidgets[#devWidgets + 1] = liftLabel

    local liftDropdown = CreateFrame("Frame", "AldorTaxDevLiftDropdown", panel, "UIDropDownMenuTemplate")
    liftDropdown:SetPoint("LEFT", liftLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(liftDropdown, 120)
    UIDropDownMenu_SetText(liftDropdown, LIFTS[selectedLift] and LIFTS[selectedLift].displayName or selectedLift)
    UIDropDownMenu_Initialize(liftDropdown, function(self, level)
        for _, id in ipairs(liftIDs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = LIFTS[id].displayName or id
            info.func = function()
                selectedLift = id
                UIDropDownMenu_SetText(liftDropdown, LIFTS[id].displayName or id)
            end
            info.checked = (id == selectedLift)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    devWidgets[#devWidgets + 1] = liftDropdown

    local function PrintTiming(liftID)
        local r = AnalyzeTiming(liftID)
        if not r then
            local count = AldorTaxDB and AldorTaxDB.timing and AldorTaxDB.timing[liftID]
                and #AldorTaxDB.timing[liftID] or 0
            print(string.format("|cffffff00AldorTax timing [%s]: %d sample(s) — need at least 2.|r",
                liftID, count))
            return
        end
        local def = LIFTS[liftID]
        local hours = r.timeSpan / 3600
        print(string.format("|cffffff00AldorTax timing: %s (%d samples over %.1fh)|r",
            def and def.displayName or liftID, r.n, hours))
        print(string.format("  Epoch offset: %.3f ± %.3f  (configured: %.1f, cycle: %.2f)",
            r.meanEpoch, r.stdEpoch, def and def.epochOffset or 0, def and def.cycleTime or 0))
        if hours >= 0.1 then
            print(string.format("  Drift: %+.3fs/hour → cycle error: %+.4fs",
                r.driftPerHour, r.impliedCycleError))
            if math.abs(r.impliedCycleError) > 0.05 then
                print(string.format("  |cffff6600⚠ Implied true cycle: %.3fs (configured: %.2fs)|r",
                    (def and def.cycleTime or 0) + r.impliedCycleError, def and def.cycleTime or 0))
            end
        else
            print("  Drift: (need >6min of data)")
        end
        local segs = {}
        for label, s in pairs(r.segments) do segs[#segs + 1] = { label = label, data = s } end
        table.sort(segs, function(a, b) return a.label < b.label end)
        if #segs > 0 then
            print("  Segment corrections:")
            for _, seg in ipairs(segs) do
                local bias = ""
                if seg.data.n >= 3 and math.abs(seg.data.meanCorr) > 0.15 then
                    bias = seg.data.meanCorr > 0 and "  ← segment may be too short"
                        or "  ← segment may be too long"
                end
                print(string.format("    %-12s n=%-3d  mean=%+.3fs  std=%.3fs%s",
                    seg.label, seg.data.n, seg.data.meanCorr, seg.data.stdCorr, bias))
            end
        end
    end

    local btnTiming = MakeDevButton(liftLabel, -22, "Show timing diagnostics", function()
        PrintTiming(selectedLift)
    end)

    local btnTuning = MakeDevButton(btnTiming, nil, "Open segment tuning panel", function()
        if not devPanel then devPanel = BuildDevPanel() end
        devPanel.ConfigureLift(selectedLift)
        if devPanel:IsShown() then devPanel:Hide() else devPanel:Show() end
    end)

    local function RefreshDevVisibility()
        for _, w in ipairs(devWidgets) do
            if settings.devTools then w:Show() else w:Hide() end
        end
    end
    cbDevTools:HookScript("OnClick", RefreshDevVisibility)

    local cfLink = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cfLink:SetPoint("TOPLEFT", btnTuning, "BOTTOMLEFT", 4, -12)
    cfLink:SetText("Feedback: |cff00ccffwww.curseforge.com/wow/addons/aldor-tax|r")

    panel:SetScript("OnShow", function()
        cbThank:Refresh(); cbAlways:Refresh(); cbCompact:Refresh()
        cbAldor:Refresh(); cbGreatLift:Refresh()
        cbTram:Refresh(); cbTBLift:Refresh(); cbStormspire:Refresh(); cbSSC:Refresh()
        cbFallSave:Refresh()
        cbDevTools:Refresh(); cbVerbose:Refresh(); cbDebug:Refresh(); cbSegInput:Refresh()
        RefreshDevVisibility()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "AldorTax")
        category.ID = "AldorTax"
        Settings.RegisterAddOnCategory(category)
        panel._settingsCategory = category
    end
    optionsPanel = panel
    return panel
end

-- ─── Slash commands ─────────────────────────────────────────────────────────

SLASH_ALDORTAX1 = "/aldortax"
SLASH_ALDORTAX2 = "/atax"
SlashCmdList["ALDORTAX"] = function(msg)
    if msg == "sync" then
        if not activeLiftID then
            print("|cffff6600AldorTax: Not near a tracked lift.|r")
            return
        end
        local def = LIFTS[activeLiftID]
        local st  = liftState[activeLiftID]
        if st.lastSync <= 0 then
            print("|cffff6600AldorTax: No sync to broadcast — calibrate first.|r")
            return
        end
        BroadcastSync(activeLiftID)
        print(string.format("|cff00ff00AldorTax: %s sync broadcast.|r", def.displayName))
    elseif msg == "reset" then
        if activeLiftID then
            liftState[activeLiftID].lastSync = 0
            liftState[activeLiftID].lastSync2 = 0
            liftState[activeLiftID].lastSyncSource = nil
        end
        warnFrame:Hide()
        print("|cff00ff00AldorTax: Timer reset.|r")
    elseif msg == "ui" then
        if not syncUI then
            local ok, result = pcall(BuildSyncUI)
            if ok then
                syncUI = result
            else
                print("|cffff0000AldorTax BuildSyncUI error: " .. tostring(result) .. "|r")
            end
        end
        if syncUI then
            if activeLiftID and not syncUI.curLiftID then
                syncUI.ReconfigureLift(activeLiftID)
            end
            if syncUI:IsShown() then syncUI:Hide() else syncUI:Show() end
        end
    elseif msg == "config" then
        if not optionsPanel then BuildOptionsPanel() end
        if optionsPanel and optionsPanel._settingsCategory then
            Settings.OpenToCategory(optionsPanel._settingsCategory.ID)
        end
    elseif msg:sub(1, 7) == "unblock" then
        local target = msg:sub(9)
        if target ~= "" and AldorTaxDB and AldorTaxDB.blocklist then
            AldorTaxDB.blocklist[target] = nil
            print("|cff00ff00AldorTax: Unblocked " .. target .. "|r")
        end
    elseif msg == "" or msg == "help" then
        print("|cffffff00AldorTax Commands:|r")
        print("  /atax sync          — sync at departure + broadcast")
        print("  /atax reset         — clear timer")
        print("  /atax ui            — toggle sync panel")
        print("  /atax config        — open settings panel")
        print("  /atax unblock Name-Realm  — remove from blocklist")
        print("  (dev tools live in /atax config → Developer)")
    else
        print("|cffff0000AldorTax: Unknown command '" .. msg .. "'. Type /atax help for options.|r")
    end
end
