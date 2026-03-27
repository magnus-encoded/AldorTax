-- ─── Top-of-screen blink warning ─────────────────────────────────────────────

local warnFrame = CreateFrame("Frame", "AldorTaxWarnFrame", UIParent)
warnFrame:SetSize(400, 100)
warnFrame:SetPoint("TOP", 0, -150)
warnFrame:Hide()
local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warnText:SetPoint("CENTER")
warnText:SetScale(2)

-- ─── Dev-mode timer overlay ──────────────────────────────────────────────────

local devTimerStart = nil   -- GetTime() when dev mode was last enabled

local devTimerFrame = CreateFrame("Frame", "AldorTaxDevTimer", UIParent, "BackdropTemplate")
devTimerFrame:SetSize(160, 36)
devTimerFrame:SetPoint("TOP", 0, -10)
devTimerFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true, tileSize = 8 })
devTimerFrame:SetBackdropColor(0, 0, 0, 0.65)
devTimerFrame:SetMovable(true)
devTimerFrame:EnableMouse(true)
devTimerFrame:RegisterForDrag("LeftButton")
devTimerFrame:SetScript("OnDragStart", devTimerFrame.StartMoving)
devTimerFrame:SetScript("OnDragStop",  devTimerFrame.StopMovingOrSizing)
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
        id           = "aldor",
        displayName  = "Aldor Lift",
        fallTime     = 6.5,
        riseTime     = 7.8,
        waitAtTop    = 6.0,
        waitAtBottom = 4.7,
        cycleTime    = 25.0,
        mapX         = 0.4169,
        mapY         = 0.3860,
        mapScale     = 1200,   -- approximate zone width in yards
        nearYards    = 50,
        zones            = { ["Shattrath City"] = true },
        nearSubzones     = { ["Aldor Rise"] = true },
        approachSubzones = { ["Terrace of Light"] = true },
        deathZones       = { ["Shattrath City"] = true },
        segColors    = {
            { r = 0.85, g = 0.12, b = 0.10 },
            { r = 0.22, g = 0.42, b = 0.88 },
            { r = 0.95, g = 0.72, b = 0.08 },
            { r = 0.10, g = 0.78, b = 0.25 },
        },
    },
    deepruntram = {
        id           = "deepruntram",
        displayName  = "Deeprun Tram",
        fallTime     = 58.5,     -- travel IF -> SW
        waitAtBottom = 13.0,     -- dwell at SW
        riseTime     = 58.5,     -- travel SW -> IF
        waitAtTop    = 13.0,     -- dwell at IF
        cycleTime    = 143.0,
        mapX         = 0, mapY = 0,
        mapScale     = 1,
        nearYards    = 999,      -- subzone detection only
        zones        = { ["Deeprun Tram"] = true },
        nearSubzones = { ["Deeprun Tram"] = true },
        deathZones   = { ["Deeprun Tram"] = true },
        dualLift     = true,
        horizontal   = true,
        endpointA    = "IF",
        endpointB    = "SW",
        phaseNames   = { "TO SW", "AT SW", "TO IF", "AT IF" },
        segColors    = {
            { r = 0.75, g = 0.45, b = 0.20 },  -- traveling to SW (orange = destination)
            { r = 0.65, g = 0.55, b = 0.55 },  -- waiting at SW (warm gray)
            { r = 0.20, g = 0.45, b = 0.75 },  -- traveling to IF (blue = destination)
            { r = 0.55, g = 0.55, b = 0.65 },  -- waiting at IF (cool gray)
        },
    },
    greatlift = {
        id           = "greatlift",
        displayName  = "Great Lift",
        fallTime     = 11.0,
        riseTime     = 11.0,
        waitAtTop    = 4.0,
        waitAtBottom = 4.0,
        cycleTime    = 30.0,
        mapX         = 0.3222,  -- midpoint of east/west for general proximity
        mapY         = 0.2407,
        mapScale     = 1000,
        nearYards    = 60,
        zones        = { ["Thousand Needles"] = true, ["The Barrens"] = true },
        nearSubzones = { ["The Great Lift"] = true, ["Freewind Post"] = true },
        deathZones   = { ["Thousand Needles"] = true, ["The Barrens"] = true },
        dualLift     = true,   -- two complementary platforms, offset by half a cycle
        eastX        = 0.3222, eastY = 0.2407,  -- east platform coords
        westX        = 0.3169, westY = 0.2381,  -- west platform coords
        segColors    = {
            { r = 0.55, g = 0.20, b = 0.18 },
            { r = 0.22, g = 0.35, b = 0.55 },
            { r = 0.60, g = 0.50, b = 0.18 },
            { r = 0.20, g = 0.48, b = 0.28 },
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

-- ─── Shared config ───────────────────────────────────────────────────────────

local APPROACH_WARNING_TIME = 10.0
local CLICK_REACTION_TIME   = 0.2

local ADDON_PREFIX          = "ALDORTAX"
local MSG_VERSION           = 4
local SYNC_CHANNEL          = "AldorTaxSync"
local SOFT_BLOCK_THRESHOLD  = 3
local HARD_BLOCK_THRESHOLD  = 6

-- ─── Per-lift state ──────────────────────────────────────────────────────────

local liftState = {}

local function InitLiftState(id)
    liftState[id] = {
        lastSync          = 0,
        lastSyncSource    = nil,
        lastAutoBroadcast = 0,
        lastSayTime       = 0,
        isNearLift        = nil,
    }
end

for id in pairs(LIFTS) do InitLiftState(id) end

local activeLiftID = nil   -- which lift the player is currently near

-- ─── Shared state ────────────────────────────────────────────────────────────

local realTimeOffset   = nil
local syncChanNum      = 0
local AUTO_BROADCAST_INTERVAL = 45
local lastProximityCheck = 0
local PROXIMITY_CHECK_INTERVAL = 1.0

-- User settings (persisted in AldorTaxDB.settings)
local settings = {
    syncParty    = true,
    syncChannel  = true,
    debugChannel = false,
    autoThank    = true,
    alwaysShowUI = false,
    enableTram = false,
}

local BuildOptionsPanel   -- forward declaration

-- ─── Copyable log ─────────────────────────────────────────────────────────────

local LOG_MAX  = 500
local logLines = {}
local logEB    = nil

local function Log(msg)
    print(msg)
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

do
    local prev = time()
    local f    = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local t = time()
        if t > prev then
            realTimeOffset = t - GetTime()
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
        prev = t
    end)
end

local function GetRealTime()
    return realTimeOffset and (GetTime() + realTimeOffset) or time()
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
    local px, py = GetPlayerMapPos()
    if not px then return nil end
    local nearFrac = def.nearYards / def.mapScale
    if def.dualLift and def.eastX then
        local dxE = px - def.eastX
        local dyE = py - def.eastY
        local dxW = px - def.westX
        local dyW = py - def.westY
        return math.min((dxE*dxE + dyE*dyE)^0.5, (dxW*dxW + dyW*dyW)^0.5) <= nearFrac
    end
    local dx = px - def.mapX
    local dy = py - def.mapY
    return (dx*dx + dy*dy)^0.5 <= nearFrac
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
            if id == "deepruntram" and not settings.enableTram then
                -- Skip tram if not enabled in experimental settings
            else
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
end

local function RestoreSync()
    if not AldorTaxDB or not AldorTaxDB.lifts or not realTimeOffset then return end
    for id, dbLift in pairs(AldorTaxDB.lifts) do
        if dbLift.lastSyncRealTime and liftState[id] then
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
    local key   = BlockKey(name, realm)
    local count = (AldorTaxDB.blocklist[key] or 0) + 1
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
        Log("|cffffff00AldorTax: prefix registration returned " .. tostring(ok) .. " — will attempt messaging regardless.|r")
        prefixRegistered = true
    end
end

local function JoinSyncChannel()
    local ok, err = pcall(JoinChannelByName, SYNC_CHANNEL)
    if not ok then
        Log(string.format("|cffffff00AldorTax: JoinChannelByName failed: %s|r", tostring(err)))
        return
    end
    local waited = 0
    local attempts = 0
    local poller = CreateFrame("Frame")
    poller:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        local n = GetChannelName(SYNC_CHANNEL)
        if n and n > 0 then
            syncChanNum = n
            Log(string.format("|cff888888AldorTax: joined channel %s (#%d)|r", SYNC_CHANNEL, n))
            self:SetScript("OnUpdate", nil)
        elseif waited > 10 then
            attempts = attempts + 1
            if attempts < 3 then
                waited = 0
                pcall(JoinChannelByName, SYNC_CHANNEL)
            else
                Log("|cffffff00AldorTax: sync channel unavailable — syncing via party/raid only|r")
                self:SetScript("OnUpdate", nil)
            end
        end
    end)
end

local function RawSend(msg, chatType, target)
    local ok, err
    if C_ChatInfo then
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
    if settings.syncChannel and syncChanNum > 0 then
        if RawSend(msg, "CHANNEL", syncChanNum) then sent = true end
    end
    if settings.syncParty then
        if UnitInRaid("player") then
            if RawSend(msg, "RAID") then sent = true end
        elseif GetNumGroupMembers and GetNumGroupMembers() > 0 then
            if RawSend(msg, "PARTY") then sent = true end
        end
    end
    if settings.debugChannel then
        Log("|cff88aaff[SYNC OUT] " .. msg .. "|r")
    end
    if not sent then
        local now = GetTime()
        if now - lastNoChannelWarn > 60 then
            lastNoChannelWarn = now
            Log("|cffffff00AldorTax: no channel to send on (channel=" .. syncChanNum .. ", solo)|r")
        end
    end
end

local function SendTestWhisper()
    local me = UnitName("player")
    local ok = RawSend("T|ping from " .. me, "WHISPER", me)
    if ok then
        Log("|cff00ff00AldorTax: test whisper sent to self — waiting for echo...|r")
    end
end

local function BroadcastSync(liftID, realTime)
    local def = LIFTS[liftID]
    if not def then return end
    local st  = liftState[liftID]
    local name  = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    local rt = realTime
              or (AldorTaxDB and AldorTaxDB.lifts and AldorTaxDB.lifts[liftID]
                  and AldorTaxDB.lifts[liftID].lastSyncRealTime)
              or GetRealTime()
    local phase = rt % def.cycleTime
    SendMsg(string.format("S|%d|%s|%.3f|%s|%s|%.3f|%.3f|%.3f|%.3f",
        MSG_VERSION, liftID, phase, name, realm,
        def.fallTime, def.waitAtBottom, def.riseTime, def.waitAtTop))
end

local function BroadcastDied(liftID)
    if not AldorTaxDB or not AldorTaxDB.lifts then return end
    local dbLift = AldorTaxDB.lifts[liftID]
    if not dbLift or not dbLift.lastSyncRealTime then return end
    local st = liftState[liftID]
    if not st.lastSyncSource then return end
    local def = LIFTS[liftID]
    local phase = dbLift.lastSyncRealTime % def.cycleTime
    SendMsg(string.format("D|%d|%s|%.3f|%s|%s",
        MSG_VERSION, liftID, phase, st.lastSyncSource.name, st.lastSyncSource.realm))
end

local function ApplyRemoteSync(liftID, phase, name, realm, fall, bottom, rise, top)
    if not realTimeOffset then return end
    local def = LIFTS[liftID]
    if not def then return end
    local st = liftState[liftID]
    local cycle_s = (fall and bottom and rise and top)
                    and (fall + bottom + rise + top)
                    or  def.cycleTime
    local nowReal = GetRealTime()
    local elapsedInCycle = (nowReal % cycle_s - phase + cycle_s) % cycle_s
    st.lastSync       = GetTime() - elapsedInCycle
    st.lastSyncSource = { name = name, realm = realm }
    if AldorTaxDB then
        if not AldorTaxDB.lifts then AldorTaxDB.lifts = {} end
        if not AldorTaxDB.lifts[liftID] then AldorTaxDB.lifts[liftID] = {} end
        AldorTaxDB.lifts[liftID].lastSyncRealTime = nowReal - elapsedInCycle
        AldorTaxDB.lifts[liftID].lastSyncSource   = st.lastSyncSource
    end
end

local function HandleAddonMessage(prefix, message, chatType, sender)
    if prefix ~= ADDON_PREFIX then return end
    local msgType = message:sub(1, 1)

    local myName = UnitName("player")
    local isSelf = sender and (sender == myName or sender:match("^" .. myName .. "%-"))

    if msgType == "T" then
        Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender), tostring(message)))
        Log("|cff00ff00AldorTax: TEST MESSAGE RECEIVED OK — addon messaging is working.|r")
        return
    end

    if isSelf then return end

    Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender), tostring(message)))
    local parts = {}
    for p in message:sub(3):gmatch("[^|]+") do parts[#parts + 1] = p end

    local ver = tonumber(parts[1])
    if not ver or ver > MSG_VERSION then
        Log("|cffffff00AldorTax: ignoring message with unknown version " .. tostring(parts[1]) .. "|r")
        return
    end

    -- v4: S|ver|liftID|phase|name|realm|fall|bottom|rise|top
    -- v3: S|ver|phase|name|realm|fall|bottom|rise|top  (assumed aldor)
    if msgType == "S" then
        local liftID, phase, name, realm, fall, bottom, rise, top
        if ver >= 4 and #parts >= 5 then
            liftID = parts[2]
            phase  = tonumber(parts[3])
            name   = parts[4]
            realm  = parts[5]
            fall   = tonumber(parts[6])
            bottom = tonumber(parts[7])
            rise   = tonumber(parts[8])
            top    = tonumber(parts[9])
        elseif ver >= 3 and #parts >= 4 then
            liftID = "aldor"
            phase  = tonumber(parts[2])
            name   = parts[3]
            realm  = parts[4]
            fall   = tonumber(parts[5])
            bottom = tonumber(parts[6])
            rise   = tonumber(parts[7])
            top    = tonumber(parts[8])
        else
            return
        end
        if not phase or not LIFTS[liftID] then return end
        if IsHardBlocked(name, realm) then return end
        if IsSoftBlocked(name, realm) then
            print(string.format("|cffff6600AldorTax: Ignored sync from soft-blocked %s-%s|r", name, realm))
            return
        end
        ApplyRemoteSync(liftID, phase, name, realm, fall, bottom, rise, top)
        if fall then
            print(string.format("|cff00ff00AldorTax: %s sync from %s (%.2f+%.2f+%.2f+%.2f=%.2fs)|r",
                LIFTS[liftID].displayName, name, fall, bottom, rise, top, fall + bottom + rise + top))
        else
            print(string.format("|cff00ff00AldorTax: %s sync from %s-%s|r", LIFTS[liftID].displayName, name, realm))
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
logicFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
logicFrame:RegisterEvent("CHAT_MSG_SAY")

logicFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "AldorTax" then
        if not AldorTaxDB then AldorTaxDB = {} end
        if not AldorTaxDB.blocklist then AldorTaxDB.blocklist = {} end
        if not AldorTaxDB.ty then AldorTaxDB.ty = 0 end
        -- Migrate old flat sync state into per-lift structure
        if AldorTaxDB.lastSyncRealTime and not AldorTaxDB.lifts then
            AldorTaxDB.lifts = {
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
        JoinSyncChannel()
        RestoreSync()
        BuildOptionsPanel()

    elseif event == "CHAT_MSG_ADDON" then
        HandleAddonMessage(arg1, arg2, arg3, arg4)

    elseif event == "PLAYER_DEAD" then
        local zone = GetZoneText()
        for id, def in pairs(LIFTS) do
            if def.deathZones and def.deathZones[zone] then
                BroadcastDied(id)
                liftState[id].lastSync       = 0
                liftState[id].lastSyncSource = nil
                warnFrame:Hide()
                Log("|cffff0000AldorTax: Death detected — sync cleared and reported.|r")
                break
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
        local me = UnitName("player")
        if settings.autoThank and sender ~= me and not sender:find("^" .. me .. "%-") and msg:find("^AldorTax:.*lift going down in:") then
            DoEmote("THANK", sender)
        end

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local newLiftID = DetectActiveLift()
        if newLiftID then
            if newLiftID ~= activeLiftID then
                activeLiftID = newLiftID
                if not syncUI then syncUI = BuildSyncUI() end
                syncUI.ReconfigureLift(activeLiftID)
            end
            local def = LIFTS[activeLiftID]
            local st  = liftState[activeLiftID]
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
            if not syncUI then syncUI = BuildSyncUI(); syncUI.ReconfigureLift(activeLiftID) end
            syncUI.SetCompact(true)
            if not syncUI:IsShown() then syncUI:Show() end
        elseif settings.alwaysShowUI then
            if not syncUI then syncUI = BuildSyncUI(); syncUI.ReconfigureLift(activeLiftID) end
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

        local uiVisible = (syncUI and syncUI:IsShown()) or settings.alwaysShowUI
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

    -- Auto-broadcast
    local hasRecipient = (settings.syncChannel and syncChanNum > 0)
        or (settings.syncParty and (UnitInRaid("player") or (GetNumGroupMembers and GetNumGroupMembers() > 0)))
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
        return 0.85, 0.12, 0.10     -- falling: red
    elseif phase < def.fallTime + def.waitAtBottom then
        return 0.22, 0.42, 0.88     -- bottom: blue
    elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
        return 0.95, 0.72, 0.08     -- rising: yellow
    else
        return 0.10, 0.78, 0.25     -- top: green
    end
end

-- (VBarClickToPhase and GetPhaseColorMuted removed — dual-lift sync uses TOP/BTM buttons now)

BuildSyncUI = function()
    if AldorTaxSyncUI then return AldorTaxSyncUI end

    local BAR_W_FULL    = 460
    local BAR_W_COMPACT = 280
    local BAR_H         = 28
    local PAD           = 12
    local VBAR_W        = 26     -- vertical bar width
    local VBAR_H        = 130    -- vertical bar height
    local VBAR_GAP      = 40     -- gap between the two vertical bars

    local barW      = BAR_W_FULL
    local isCompact = false
    local isDual    = false
    local curLiftID = nil

    -- ── Main frame ──────────────────────────────────────────────────────────
    local p = CreateFrame("Frame", "AldorTaxSyncUI", UIParent, "BackdropTemplate")
    p:SetSize(BAR_W_FULL + PAD * 2, 94)
    p:SetPoint("TOP", UIParent, "TOP", 0, -120)
    p:SetFrameStrata("MEDIUM")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop",  p.StopMovingOrSizing)
    p:SetBackdrop({
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
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
        bgFile   = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
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
            local st  = liftState[activeLiftID]
            local now = GetTime() - CLICK_REACTION_TIME
            local starts = { [0] = 0, def.fallTime, def.fallTime + def.waitAtBottom,
                             def.fallTime + def.waitAtBottom + def.riseTime }
            local phaseStart = starts[phaseIdx]
            st.lastSync = now - phaseStart
            st.lastAutoBroadcast = GetTime()
            local rt = GetRealTime() - CLICK_REACTION_TIME - phaseStart
            SaveSync(activeLiftID, nil, nil, rt)
            BroadcastSync(activeLiftID, rt)
            if not AldorTaxDB.syncLog then AldorTaxDB.syncLog = {} end
            table.insert(AldorTaxDB.syncLog, string.format(
                "%s|%s|%s|%.3f|%.3f",
                date("%Y-%m-%d %H:%M:%S"), activeLiftID,
                SEG_NAMES[i], GetTime(), phaseStart))
            Log(string.format("|cff00ff00AldorTax: %s synced at %s|r", def.displayName, SEG_NAMES[i]))
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

    -- Phase segment labels for click feedback
    local VBAR_PHASE_NAMES = { "FALL", "BOTTOM", "RISE", "TOP" }

    local OnBarClick  -- forward declaration; assigned after MakeVBar

    local function MakeVBar(parent, label, isPrimary)
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
            GameTooltip:SetText("Click to sync (" .. label .. ")", 1, 0.82, 0, 1)
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
            bg = bg, bar = vbar, overlay = voverlay,
            cursor = cur, glow = glow,
            label = lbl, timeLabel = tlbl, phaseLbl = phaseLbl,
            isPrimary = isPrimary,
        }
    end

    -- ── Dual-lift click-on-bar sync ────────────────────────────────────────
    -- Top half = "lift is at the top now", bottom half = "lift is at the bottom now".
    -- Single click is enough if the cycle timing is correct.
    OnBarClick = function(isPrimary, clickFrac)
        if not activeLiftID then return end
        local def = LIFTS[activeLiftID]
        local st  = liftState[activeLiftID]
        local phaseName, phaseStart
        if clickFrac >= 0.5 then
            phaseName  = isPrimary and "TOP" or "TOP (West)"
            phaseStart = def.fallTime + def.waitAtBottom + def.riseTime
        else
            phaseName  = isPrimary and "BOTTOM" or "BOTTOM (West)"
            phaseStart = def.fallTime
        end
        -- West lift is offset by half a cycle; convert to East-relative phase
        if not isPrimary and def.dualLift then
            phaseStart = (phaseStart + def.cycleTime / 2) % def.cycleTime
        end
        local now = GetTime() - CLICK_REACTION_TIME
        st.lastSync = now - phaseStart
        st.lastAutoBroadcast = GetTime()
        local rt = GetRealTime() - CLICK_REACTION_TIME - phaseStart
        SaveSync(activeLiftID, nil, nil, rt)
        BroadcastSync(activeLiftID, rt)
        if not AldorTaxDB.syncLog then AldorTaxDB.syncLog = {} end
        table.insert(AldorTaxDB.syncLog, string.format(
            "%s|%s|%s|%.3f|%.3f",
            date("%Y-%m-%d %H:%M:%S"), activeLiftID,
            phaseName, GetTime(), phaseStart))
        local label = phaseName == "TOP" and "arrived at top" or "arrived at bottom"
        Log(string.format("SYNC %s %s t=%.3f",
            def.displayName, label, GetTime()))
    end

    local vbar1 = MakeVBar(dualContainer, "East", true)
    local vbar2 = MakeVBar(dualContainer, "West", false)

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
            bgFile   = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        }
        local BAR_BD = {
            bgFile   = "Interface/ChatFrame/ChatFrameBackground",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
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

        -- Last station context: set by station button clicks, used by depart button
        local departStation = nil  -- "A" or "B"

        clickBtn:SetScript("OnEnter", function(self)
            if not activeLiftID then return end
            local def = LIFTS[activeLiftID]
            local stationName = departStation == "B" and (def.endpointB or "B")
                or departStation == "A" and (def.endpointA or "A")
                or nil
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if stationName then
                GameTooltip:SetText("Click when tram departs " .. stationName, 1, 0.82, 0, 1)
            else
                GameTooltip:SetText("Click when tram departs", 1, 0.82, 0, 1)
                GameTooltip:AddLine("Click a station button first to set context", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        clickBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        clickBtn:SetScript("OnClick", function(self)
            if not activeLiftID then return end
            local def = LIFTS[activeLiftID]
            local st  = liftState[activeLiftID]
            local phaseStart, phaseName
            if departStation == "B" then
                phaseStart = def.fallTime + def.waitAtBottom
                phaseName = "departs " .. (def.endpointB or "B")
            elseif departStation == "A" then
                phaseStart = 0
                phaseName = "departs " .. (def.endpointA or "A")
            else
                -- No station context: fall back to cursor position
                local cursorX = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                local left, right = self:GetLeft(), self:GetRight()
                if not left or not right or left == right then return end
                local frac = ((cursorX / scale) - left) / (right - left)
                if frac < 0.5 then
                    phaseStart = 0
                    phaseName = "departs " .. (def.endpointA or "A")
                else
                    phaseStart = def.fallTime + def.waitAtBottom
                    phaseName = "departs " .. (def.endpointB or "B")
                end
            end
            if not isPrimary and def.dualLift then
                phaseStart = (phaseStart + def.cycleTime / 2) % def.cycleTime
            end
            local now = GetTime() - CLICK_REACTION_TIME
            st.lastSync = now - phaseStart
            st.lastAutoBroadcast = GetTime()
            local rt = GetRealTime() - CLICK_REACTION_TIME - phaseStart
            SaveSync(activeLiftID, nil, nil, rt)
            BroadcastSync(activeLiftID, rt)
            Log(string.format("|cff00ff00AldorTax: %s synced at %s%s|r",
                def.displayName, phaseName, isPrimary and "" or " (2nd tram)"))
        end)

        return {
            row = row, bg = bg, bar = hbar, overlay = hover,
            cursor = cur, glow = glow,
            fillL = fillL, fillR = fillR,
            timeLabel = timeLbl, phaseLbl = phaseLbl,
            isPrimary = isPrimary, label = label,
            btnA = btnA, btnB = btnB,
            compactLblA = compactLblA, compactLblB = compactLblB,
            setDepartStation = function(s) departStation = s end,
        }
    end

    local hbar1 = MakeHBar(tramContainer, "Tram 1", true)
    local hbar2 = MakeHBar(tramContainer, "Tram 2", false)

    -- Station button labels, colors, and click handlers are set in ReconfigureLift.

    -- ═════════════════════════════════════════════════════════════════════════
    -- SHARED ELEMENTS
    -- ═════════════════════════════════════════════════════════════════════════

    -- Shared say logic: callable directly from both sayBtn and sayIcon.
    -- SendChatMessage requires a hardware event in the call chain, so both
    -- callers must invoke this from their own OnClick — no Click() delegation.
    local function DoSayPosition()
        if not activeLiftID then return end
        local def = LIFTS[activeLiftID]
        local st  = liftState[activeLiftID]
        if st.lastSync <= 0 then
            print("|cffff6600AldorTax: No sync — nothing to announce.|r")
            return
        end
        local phase = (GetTime() - st.lastSync) % def.cycleTime
        if def.horizontal then
            local nameA = def.endpointA or "A"
            local nameB = def.endpointB or "B"
            local phase2 = (phase + def.cycleTime / 2) % def.cycleTime
            local function tramLine(ph)
                if ph < def.fallTime then
                    local t = def.fallTime - ph
                    return string.format("[%s] -%ds-> [%s]", nameA, t, nameB)
                elseif ph < def.fallTime + def.waitAtBottom then
                    local t = def.fallTime + def.waitAtBottom - ph
                    return string.format("At [%s], departs in %ds", nameB, t)
                elseif ph < def.fallTime + def.waitAtBottom + def.riseTime then
                    local t = def.fallTime + def.waitAtBottom + def.riseTime - ph
                    return string.format("[%s] <-%ds- [%s]", nameA, t, nameB)
                else
                    local t = def.cycleTime - ph
                    return string.format("At [%s], departs in %ds", nameA, t)
                end
            end
            SendChatMessage(string.format("AldorTax: North: %s | South: %s", tramLine(phase), tramLine(phase2)), "SAY")
        elseif def.dualLift then
            local ttfEast = def.cycleTime - phase
            local phase2 = (phase + def.cycleTime / 2) % def.cycleTime
            local ttfWest = def.cycleTime - phase2
            local platName, ttf
            if ttfEast <= ttfWest then
                platName, ttf = "East", ttfEast
            else
                platName, ttf = "West", ttfWest
            end
            SendChatMessage(string.format("AldorTax: %s lift going down in: %.1f seconds", platName, ttf), "SAY")
        else
            local ttd = def.cycleTime - phase
            SendChatMessage(string.format("AldorTax: Lift going down in: %.1f seconds", ttd), "SAY")
        end
        st.lastSayTime = GetTime()
    end
    p.DoSayPosition = DoSayPosition  -- expose for external use if needed

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
        local totalW = VBAR_W * 2 + VBAR_GAP + 6 * 2  -- bars + gap + borders
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
        vbar2.bg:SetPoint("TOP", dualContainer, "TOP",  (VBAR_GAP / 2 + VBAR_W / 2), -36)

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

        sayIcon:ClearAllPoints()
        sayIcon:SetPoint("LEFT", vbar2.bg, "RIGHT", 8, 0)
        sayIcon:Show()
    end

    local function LayoutTramFull()
        local rowW = HBAR_W + STATION_BTN_W * 2 + 16  -- bar + 2 station buttons + gaps
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
    -- and calls DoSayPosition() directly so SendChatMessage gets a real
    -- hardware event.

    local COMPACT_HBAR_W  = 180   -- travel bar width in compact mode (full = 400)
    local COMPACT_BTN_W   = 30    -- station button width (full = 40)
    local COMPACT_HBAR_H  = 16    -- bar height (full = 20)
    local COMPACT_GAP     = 4     -- gap between hbar2 and hbar1 rows

    local function LayoutTramCompact()
        local rowW = COMPACT_HBAR_W + COMPACT_BTN_W * 2 + 16
        local rowH = COMPACT_HBAR_H + 8
        -- Frame: two rows + gap + small top/bottom padding
        local frameW = rowW + PAD * 2 + 28  -- +28 for sayIcon to the right
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
            local innerW = COMPACT_HBAR_W - 6  -- hbar inset is 3px each side
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
        p.curLiftID = liftID  -- expose on frame for external guard
        isDual = def.dualLift and true or false
        isTram = def.horizontal and true or false
        if isDual then
            title:SetText(def.displayName .. "  |cff888888click segment to sync|r")
        else
            title:SetText(def.displayName .. "  |cff888888click phase to sync|r")
        end

        if isTram then
            ShowTram()
            sayBtn:SetText("|cffffcc00Say Position|r")

            -- Track labels (Bottom = North, Top = South)
            hbar1.row.trackLabel = hbar1.row.trackLabel or hbar1.row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hbar1.row.trackLabel:SetPoint("BOTTOMLEFT", hbar1.bg, "TOPLEFT", 0, 2)
            hbar1.row.trackLabel:SetText("NORTH TRAM (closer to entrance)")
            hbar1.row.trackLabel:SetTextColor(0.7, 0.7, 0.9)

            hbar2.row.trackLabel = hbar2.row.trackLabel or hbar2.row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hbar2.row.trackLabel:SetPoint("BOTTOMLEFT", hbar2.bg, "TOPLEFT", 0, 2)
            hbar2.row.trackLabel:SetText("SOUTH TRAM")
            hbar2.row.trackLabel:SetTextColor(0.9, 0.7, 0.7)

            local atA = def.fallTime + def.waitAtBottom + def.riseTime  -- phase: arrived at A
            local atB = def.fallTime                                    -- phase: arrived at B
            local colorA = { 0.30, 0.55, 0.85 }  -- IF blue
            local colorB = { 0.85, 0.55, 0.30 }  -- SW orange
            local nameA = def.endpointA or "A"
            local nameB = def.endpointB or "B"

            for _, hb in ipairs({ hbar1, hbar2 }) do
                local primary = hb.isPrimary
                hb.setDepartStation(nil)  -- reset stale departure context
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
                    local st = liftState[activeLiftID]
                    local ps = atA
                    if not primary and ld.dualLift then ps = (ps + ld.cycleTime / 2) % ld.cycleTime end
                    local now = GetTime() - CLICK_REACTION_TIME
                    st.lastSync = now - ps
                    st.lastAutoBroadcast = GetTime()
                    local rt = GetRealTime() - CLICK_REACTION_TIME - ps
                    SaveSync(activeLiftID, nil, nil, rt)
                    BroadcastSync(activeLiftID, rt)
                    hb.setDepartStation("A")
                    Log(string.format("|cff00ff00AldorTax: %s synced at %s%s|r",
                        ld.displayName, nameA, primary and "" or " (2nd tram)"))
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
                    local st = liftState[activeLiftID]
                    local ps = atB
                    if not primary and ld.dualLift then ps = (ps + ld.cycleTime / 2) % ld.cycleTime end
                    local now = GetTime() - CLICK_REACTION_TIME
                    st.lastSync = now - ps
                    st.lastAutoBroadcast = GetTime()
                    local rt = GetRealTime() - CLICK_REACTION_TIME - ps
                    SaveSync(activeLiftID, nil, nil, rt)
                    BroadcastSync(activeLiftID, rt)
                    hb.setDepartStation("B")
                    Log(string.format("|cff00ff00AldorTax: %s synced at %s%s|r",
                        ld.displayName, nameB, primary and "" or " (2nd tram)"))
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
        if phase < def.fallTime then seg = 1
        elseif phase < def.fallTime + def.waitAtBottom then seg = 2
        elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then seg = 3
        else seg = 4 end
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
        if phase < def.fallTime then phaseName = names[1]
        elseif phase < def.fallTime + def.waitAtBottom then phaseName = names[2]
        elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then phaseName = names[3]
        else phaseName = names[4] end
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
                ttd = def.fallTime - phase                             -- arriving at B
            elseif phase < def.fallTime + def.waitAtBottom then
                ttd = def.fallTime + def.waitAtBottom - phase          -- departing B
            elseif phase < def.fallTime + def.waitAtBottom + def.riseTime then
                ttd = def.fallTime + def.waitAtBottom + def.riseTime - phase  -- arriving at A
            else
                ttd = def.cycleTime - phase                            -- departing A
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
            -- Dual vertical bars
            if st.lastSync <= 0 then
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

            local phase1 = (GetTime() - st.lastSync) % def.cycleTime
            local phase2 = (phase1 + def.cycleTime / 2) % def.cycleTime
            local h1 = GetLiftHeight(phase1, def)
            local h2 = GetLiftHeight(phase2, def)
            local r1, g1, b1 = GetPhaseColor(phase1, def)
            local r2, g2, b2 = GetPhaseColor(phase2, def)

            -- Helper: get phase name from cycle phase
            local function PhaseName(ph)
                if ph < def.fallTime then return "FALL"
                elseif ph < def.fallTime + def.waitAtBottom then return "BTM"
                elseif ph < def.fallTime + def.waitAtBottom + def.riseTime then return "RISE"
                else return "TOP" end
            end

            -- Primary bar: phase-colored cursor with glow
            vbar1.cursor:SetColorTexture(r1, g1, b1, 0.90)
            vbar1.cursor:ClearAllPoints()
            vbar1.cursor:SetPoint("CENTER", vbar1.overlay, "BOTTOM", 0, h1 * VBAR_H)
            vbar1.glow:SetColorTexture(r1, g1, b1, 0.25)
            vbar1.glow:ClearAllPoints()
            vbar1.glow:SetPoint("CENTER", vbar1.cursor, "CENTER")
            vbar1.phaseLbl:SetText(PhaseName(phase1))
            vbar1.phaseLbl:SetTextColor(r1, g1, b1, 0.85)
            vbar1.phaseLbl:ClearAllPoints()
            vbar1.phaseLbl:SetPoint("LEFT", vbar1.cursor, "RIGHT", 4, 0)

            -- Secondary bar: dimmer phase-colored cursor
            vbar2.cursor:SetColorTexture(r2, g2, b2, 0.60)
            vbar2.cursor:ClearAllPoints()
            vbar2.cursor:SetPoint("CENTER", vbar2.overlay, "BOTTOM", 0, h2 * VBAR_H)
            vbar2.glow:SetColorTexture(r2, g2, b2, 0.12)
            vbar2.glow:ClearAllPoints()
            vbar2.glow:SetPoint("CENTER", vbar2.cursor, "CENTER")
            vbar2.phaseLbl:SetText(PhaseName(phase2))
            vbar2.phaseLbl:SetTextColor(r2, g2, b2, 0.55)
            vbar2.phaseLbl:ClearAllPoints()
            vbar2.phaseLbl:SetPoint("RIGHT", vbar2.cursor, "LEFT", -4, 0)

            local ttd1 = def.cycleTime - phase1
            local ttd2 = def.cycleTime - phase2
            vbar1.timeLabel:SetText(string.format("%.1fs", ttd1))
            vbar2.timeLabel:SetText(string.format("%.1fs", ttd2))

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
                local phase2 = (phase + def.cycleTime / 2) % def.cycleTime
                showSay = showSay or phase2 >= topStart
            end
            if showSay then sayBtn:Show() else sayBtn:Hide() end
        end
    end

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
    p:SetScript("OnDragStop",  p.StopMovingOrSizing)
    p:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
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
        tile = true, tileSize = 5, edgeSize = 0,
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

    local syncHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    syncHdr:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    syncHdr:SetText("Sync broadcast channels")

    local cbParty   = MakeCheckbox(panel, syncHdr,  -4,  "syncParty",
        "Party / Raid",   "Broadcast syncs to your party or raid group.")
    local cbChannel = MakeCheckbox(panel, cbParty,  nil, "syncChannel",
        "AldorTaxSync channel", "Broadcast to the shared AldorTaxSync custom channel.")
    local cbDebug   = MakeCheckbox(panel, cbChannel, nil, "debugChannel",
        "Debug channel",  "Log all outgoing sync messages to chat for debugging.")

    local behHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    behHdr:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -16)
    behHdr:SetText("Behaviour")

    local cbThank   = MakeCheckbox(panel, behHdr, -4, "autoThank",
        "Auto-thank warnings", "Automatically /thank players who announce lift departures in /say.")
    local alwaysHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    alwaysHdr:SetPoint("TOPLEFT", cbThank, "BOTTOMLEFT", 0, -6)
    alwaysHdr:SetText("Always show:")
    alwaysHdr:SetTextColor(0.9, 0.9, 0.9)

    local cbAlways  = MakeCheckbox(panel, nil, nil, "alwaysShowUI",
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

    local expHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    expHdr:SetPoint("TOPLEFT", cbCompact, "BOTTOMLEFT", 0, -24)
    expHdr:SetText("Experimental")

    local cbTram = MakeCheckbox(panel, expHdr, -4, "enableTram",
        "Enable Deeprun Tram (Beta)", "Experimental support for tracking the Deeprun Tram. Timings may vary.")

    local cfLink = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cfLink:SetPoint("TOPLEFT", cbTram, "BOTTOMLEFT", 4, -8)
    cfLink:SetText("Feedback: |cff00ccffwww.curseforge.com/wow/addons/aldor-tax|r")

    panel:SetScript("OnShow", function()
        cbParty:Refresh(); cbChannel:Refresh(); cbDebug:Refresh()
        cbThank:Refresh(); cbAlways:Refresh(); cbCompact:Refresh()
        cbTram:Refresh()
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
    elseif msg == "log" then
        if not logPanel then logPanel = BuildLogPanel() end
        if logPanel:IsShown() then logPanel:Hide() else logPanel:Show() end
    elseif msg == "testmsg" then
        Log(string.format("|cffffff00AldorTax testmsg: prefixRegistered=%s  C_ChatInfo=%s  syncChanNum=%d|r",
            tostring(prefixRegistered), tostring(C_ChatInfo ~= nil), syncChanNum))
        SendTestWhisper()
    elseif msg == "reset" then
        if activeLiftID then
            liftState[activeLiftID].lastSync = 0
            liftState[activeLiftID].lastSyncSource = nil
        end
        warnFrame:Hide()
        print("|cff00ff00AldorTax: Timer reset.|r")
    elseif msg == "ui" then
        if not syncUI then
            local ok, result = pcall(BuildSyncUI)
            if ok then syncUI = result
            else print("|cffff0000AldorTax BuildSyncUI error: " .. tostring(result) .. "|r") end
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
    elseif msg == "where" then
        local zone = GetZoneText() or "?"
        local sub = GetSubZoneText() or "?"
        local mini = GetMinimapZoneText() or "?"
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local mx, my = 0, 0
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then mx, my = pos:GetXY() end
        end
        print(string.format("|cffffff00AldorTax where: zone=%s sub=%s mini=%s map=%s (%.4f, %.4f)|r",
            zone, sub, mini, tostring(mapID), mx, my))
        -- Scan nameplates for known NPCs
        local npcs = {}
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then
                npcs[#npcs + 1] = UnitName(unit)
            end
        end
        if #npcs > 0 then
            print("|cffffff00  Nameplates: " .. table.concat(npcs, ", ") .. "|r")
        else
            print("|cffffff00  Nameplates: (none visible)|r")
        end
    elseif msg == "dev" then
        if devTimerFrame:IsShown() then
            devTimerFrame:Hide()
            devTimerStart = nil
            print("|cff00ff00AldorTax: Dev timer hidden.|r")
        else
            devTimerStart = GetTime()
            devTimerFrame:Show()
            print("|cff00ff00AldorTax: Dev timer started — drag to reposition.|r")
        end
    elseif msg == "" or msg == "help" then
        print("|cffffff00AldorTax Commands:|r")
        print("  /atax sync          — sync at departure + broadcast")
        print("  /atax reset         — clear timer")
        print("  /atax ui            — toggle sync panel")
        print("  /atax config        — open settings panel")
        print("  /atax log           — toggle copyable log panel")
        print("  /atax testmsg       — whisper yourself to test addon messaging")
        print("  /atax unblock Name-Realm  — remove from blocklist")
        print("  /atax dev           — toggle dev timer overlay (for video calibration)")
    else
        print("|cffff0000AldorTax: Unknown command '" .. msg .. "'. Type /atax help for options.|r")
    end
end
