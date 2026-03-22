-- ─── Top-of-screen blink warning ─────────────────────────────────────────────

local warnFrame = CreateFrame("Frame", "AldorTaxWarnFrame", UIParent)
warnFrame:SetSize(400, 100)
warnFrame:SetPoint("TOP", 0, -150)
warnFrame:Hide()
local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warnText:SetPoint("CENTER")
warnText:SetScale(2)

-- ─── Config ───────────────────────────────────────────────────────────────────

local FALL_TIME             = 6.5    -- lift falling: top → bottom
local RISE_TIME             = 7.5    -- lift rising:  bottom → top
local WAIT_AT_TOP           = 6.0
local WAIT_AT_BOTTOM        = 5.0
local CYCLE_TIME            = 25.0   -- fixed: the actual server cycle is 25s
local APPROACH_WARNING_TIME = 10.0
local CLICK_REACTION_TIME   = 0.2    -- human reaction time offset subtracted from sync clicks

local ADDON_PREFIX          = "ALDORTAX"
local MSG_VERSION           = 3
local SYNC_CHANNEL          = "AldorTaxSync"
local SOFT_BLOCK_THRESHOLD  = 3     -- death reports to stop auto-applying someone's syncs
local HARD_BLOCK_THRESHOLD  = 6     -- death reports to permanently ignore

-- ─── State ────────────────────────────────────────────────────────────────────

local lastSync         = 0
local lastSyncSource   = nil   -- { name, realm } of whoever provided the current sync
local realTimeOffset   = nil
local syncChanNum      = 0
local lastAutoBroadcast = 0
local AUTO_BROADCAST_INTERVAL = 45

-- User settings (persisted in AldorTaxDB.settings)
local settings = {
    syncParty    = true,   -- broadcast sync via party / raid
    syncChannel  = true,   -- broadcast sync via AldorTaxSync custom channel
    syncGuild    = false,  -- broadcast sync via guild
}

-- Forward-declare so the ADDON_LOADED closure (created before the definition) can see it
local BuildOptionsPanel

-- ─── Copyable log ─────────────────────────────────────────────────────────────

local LOG_MAX  = 500
local logLines = {}
local logEB    = nil   -- set when log panel is built

local function Log(msg)
    print(msg)
    local stamp = string.format("[%.1f] ", GetTime())
    table.insert(logLines, stamp .. msg)
    if #logLines > LOG_MAX then table.remove(logLines, 1) end
    if logEB then
        logEB:SetText(table.concat(logLines, "\n"))
        logEB:SetCursorPosition(0)
    end
end

-- ─── Real-time calibration ────────────────────────────────────────────────────

do
    local prev = time()
    local f    = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local t = time()
        if t > prev then
            realTimeOffset = t - GetTime()
            self:SetScript("OnUpdate", nil)
            if AldorTaxDB and AldorTaxDB.lastSyncRealTime then
                local elapsed = (GetTime() + realTimeOffset) - AldorTaxDB.lastSyncRealTime
                lastSync = GetTime() - elapsed
                lastSyncSource = nil   -- don't restore remote attribution across reloads
            end
        end
        prev = t
    end)
end

local function GetRealTime()
    return realTimeOffset and (GetTime() + realTimeOffset) or time()
end

-- ─── Sync persistence ─────────────────────────────────────────────────────────

local function SaveSync(sourceName, sourceRealm, realTime)
    if not AldorTaxDB then return end
    local realNow = realTime or GetRealTime()
    AldorTaxDB.lastSyncRealTime = realNow
    lastSyncSource = sourceName and { name = sourceName, realm = sourceRealm or "" } or nil
    AldorTaxDB.lastSyncSource  = lastSyncSource
end

local function RestoreSync()
    if not AldorTaxDB or not AldorTaxDB.lastSyncRealTime or not realTimeOffset then return end
    local elapsed = GetRealTime() - AldorTaxDB.lastSyncRealTime
    lastSync      = GetTime() - elapsed
    lastSyncSource = nil   -- don't restore remote attribution across reloads
end

-- ─── Trust / blocklist ────────────────────────────────────────────────────────

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

-- ─── Addon messaging ──────────────────────────────────────────────────────────

local prefixRegistered = false

local function RegisterPrefix()
    local ok
    if C_ChatInfo then
        ok = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    elseif RegisterAddonMessagePrefix then
        ok = RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
    -- TBC Classic returns 0/1 (not true/false) from RegisterAddonMessagePrefix
    prefixRegistered = ok and ok ~= false and ok ~= 0
    if prefixRegistered then
        Log("|cff00ff00AldorTax: prefix registered OK (ok=" .. tostring(ok) .. ").|r")
    else
        -- ok=0 in TBC Classic means already registered or succeeded (test for receive anyway)
        Log("|cffffff00AldorTax: prefix registration returned " .. tostring(ok) .. " — will attempt messaging regardless.|r")
        prefixRegistered = true   -- TBC returns 0 on success
    end
end

local function JoinSyncChannel()
    -- Custom addon channels may not work in all Classic variants.
    -- Attempt to join but don't treat failure as critical.
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
                Log("|cffffff00AldorTax: sync channel unavailable — syncing via party/raid/guild only|r")
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
    if settings.syncGuild then
        if RawSend(msg, "GUILD") then sent = true end
    end
    if not sent then
        -- Only warn once per minute to avoid log spam from auto-broadcast
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

local function BroadcastSync(realTime)
    local name  = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    -- realTime is the cycle-start real time when provided by a segment click.
    -- When auto-broadcasting (no arg), use the stored cycle-start real time so
    -- the phase encodes the same epoch-offset the receiver needs to reconstruct
    -- our cycle alignment.  Falling back to GetRealTime() (≡ "cycle starts now")
    -- only when there is no stored reference.
    local rt    = realTime
                  or (AldorTaxDB and AldorTaxDB.lastSyncRealTime)
                  or GetRealTime()
    local phase = rt % CYCLE_TIME
    SendMsg(string.format("S|%d|%.3f|%s|%s|%.3f|%.3f|%.3f|%.3f",
        MSG_VERSION, phase, name, realm, FALL_TIME, WAIT_AT_BOTTOM, RISE_TIME, WAIT_AT_TOP))
end

local function BroadcastDied()
    if not AldorTaxDB or not AldorTaxDB.lastSyncRealTime then return end
    if not lastSyncSource then return end  -- local calibration — no remote source to blame
    local phase = AldorTaxDB.lastSyncRealTime % CYCLE_TIME
    SendMsg(string.format("D|%d|%.3f|%s|%s", MSG_VERSION, phase, lastSyncSource.name, lastSyncSource.realm))
end

local function ApplyRemoteSync(phase, name, realm, fall, bottom, rise, top)
    if not realTimeOffset then return end
    -- Use sender's cycle time if segments provided, otherwise fall back to local
    local cycle_s = (fall and bottom and rise and top)
                    and (fall + bottom + rise + top)
                    or  CYCLE_TIME
    local nowReal = GetRealTime()
    -- How far into the current cycle are we past the sender's phase reference?
    local elapsedInCycle = (nowReal % cycle_s - phase + cycle_s) % cycle_s
    lastSync       = GetTime() - elapsedInCycle
    lastSyncSource = { name = name, realm = realm }
    if AldorTaxDB then
        AldorTaxDB.lastSyncRealTime = nowReal - elapsedInCycle  -- absolute top-departure time
        AldorTaxDB.lastSyncSource   = lastSyncSource
    end
end

local function HandleAddonMessage(prefix, message, chatType, sender)
    if prefix ~= ADDON_PREFIX then return end
    local msgType = message:sub(1, 1)

    -- Let test messages through from self; ignore all other self-broadcasts
    local myName = UnitName("player")
    local isSelf = sender and (sender == myName or sender:match("^" .. myName .. "%-"))

    if msgType == "T" then
        Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender), tostring(message)))
        Log("|cff00ff00AldorTax: TEST MESSAGE RECEIVED OK — addon messaging is working.|r")
        return
    end

    if isSelf then return end

    Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender), tostring(message)))
    local parts   = {}
    for p in message:sub(3):gmatch("[^|]+") do parts[#parts+1] = p end

    -- All other message types carry a version as parts[1]
    local ver = tonumber(parts[1])
    if not ver or ver > MSG_VERSION then
        Log("|cffffff00AldorTax: ignoring message with unknown version " .. tostring(parts[1]) .. "|r")
        return
    end

    if msgType == "S" and #parts >= 4 then
        -- v3: S|ver|phase|name|realm|fall|bottom|rise|top
        local phase        = tonumber(parts[2])
        local name, realm  = parts[3], parts[4]
        local fall         = tonumber(parts[5])
        local bottom       = tonumber(parts[6])
        local rise         = tonumber(parts[7])
        local top          = tonumber(parts[8])
        if not phase then return end
        if IsHardBlocked(name, realm) then return end
        if IsSoftBlocked(name, realm) then
            print(string.format("|cffff6600AldorTax: Ignored sync from soft-blocked %s-%s|r", name, realm))
            return
        end
        ApplyRemoteSync(phase, name, realm, fall, bottom, rise, top)
        if fall then
            print(string.format("|cff00ff00AldorTax: Sync from %s (%.2f+%.2f+%.2f+%.2f=%.2fs)|r",
                name, fall, bottom, rise, top, fall+bottom+rise+top))
        else
            print(string.format("|cff00ff00AldorTax: Sync received from %s-%s|r", name, realm))
        end

    elseif msgType == "D" and #parts >= 4 then
        -- v1: D|ver|phase|name|realm
        local syncTime     = tonumber(parts[2])
        local name, realm  = parts[3], parts[4]
        if not syncTime or not name then return end
        local count = RecordDeathReport(name, realm)
        -- Invalidate local sync if it came from this now-untrusted source
        if lastSyncSource and lastSyncSource.name == name and lastSyncSource.realm == realm then
            if count and count >= SOFT_BLOCK_THRESHOLD then
                lastSync       = 0
                lastSyncSource = nil
                warnFrame:Hide()
                print("|cffff0000AldorTax: Active sync invalidated — too many deaths reported.|r")
            end
        end
    end
end

-- ─── Events ───────────────────────────────────────────────────────────────────

local logicFrame = CreateFrame("Frame")
logicFrame:RegisterEvent("ADDON_LOADED")
logicFrame:RegisterEvent("CHAT_MSG_ADDON")
logicFrame:RegisterEvent("ZONE_CHANGED")
logicFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
logicFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
logicFrame:RegisterEvent("PLAYER_DEAD")

logicFrame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "AldorTax" then
        if not AldorTaxDB then AldorTaxDB = {} end
        if not AldorTaxDB.blocklist then AldorTaxDB.blocklist = {} end
        -- Load saved settings, falling back to defaults
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
        if GetZoneText() == "Shattrath City" then
            BroadcastDied()
            lastSync       = 0
            lastSyncSource = nil
            warnFrame:Hide()
            Log("|cffff0000AldorTax: Death detected in Shattrath — sync cleared and reported.|r")
        end

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local zone    = GetZoneText()
        local subzone = GetSubZoneText()
        if zone == "Shattrath City" and subzone ~= "Aldor Rise" then
            if not syncUI then syncUI = BuildSyncUI() end
            syncUI:Show()
        else
            if syncUI then syncUI:Hide() end
            -- One final broadcast as we leave, so nearby players keep a good sync
            if lastSync > 0 then BroadcastSync() end
        end
    end
end)

-- ─── Warning display (OnUpdate) ───────────────────────────────────────────────

logicFrame:SetScript("OnUpdate", function(self, elapsed)
    local subzone = GetSubZoneText()
    local status
    if subzone == "Aldor Rise" or subzone == "Terrace of Light" then
        status = "on_platform"
    elseif GetZoneText() == "Shattrath City" then
        status = "approaching"
    else
        status = "other"
    end

    local progress, timeUntilNextDrop
    if lastSync > 0 then
        progress          = (GetTime() - lastSync) % CYCLE_TIME
        timeUntilNextDrop = CYCLE_TIME - progress

        local uiVisible = syncUI and syncUI:IsShown()
        if uiVisible then
            warnFrame:Hide()
        elseif status == "on_platform" and timeUntilNextDrop <= WAIT_AT_TOP then
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

    -- /say countdown was removed: Blizzard blocks SendChatMessage("SAY") outdoors
    -- since patch 8.2.5 (confirmed in DBM source). Shattrath is outdoor, so there
    -- is no way for addons to send /say messages near the lift. The feature's purpose
    -- was to warn nearby players without the addon and advertise its existence —
    -- self-only notifications don't serve either goal.

    -- Re-anchor lastSync from the persisted real-time reference every cycle to
    -- prevent floating-point drift between GetTime() and the modulo'd CYCLE_TIME.
    if lastSync > 0 and realTimeOffset and AldorTaxDB and AldorTaxDB.lastSyncRealTime then
        local elapsed = GetRealTime() - AldorTaxDB.lastSyncRealTime
        lastSync = GetTime() - elapsed
    end

    -- Periodic auto-broadcast when in Shattrath and sync is valid
    -- Only broadcast if there's actually someone to send to
    if lastSync > 0 and GetZoneText() == "Shattrath City" then
        local hasRecipient = (settings.syncChannel and syncChanNum > 0)
            or (settings.syncParty and (UnitInRaid("player") or (GetNumGroupMembers and GetNumGroupMembers() > 0)))
            or settings.syncGuild
        if hasRecipient then
            local now = GetTime()
            if now - lastAutoBroadcast >= AUTO_BROADCAST_INTERVAL then
                lastAutoBroadcast = now
                BroadcastSync()
            end
        end
    end

    -- Tick the sync UI cursor
    if syncUI and syncUI:IsShown() and syncUI.UpdateCursor then
        syncUI.UpdateCursor()
    end
end)

-- ─── Sync UI ─────────────────────────────────────────────────────────────────
-- Shows when the player is in Shattrath City (but not Aldor Rise).
-- Progress bar: [FALL(red)][BOTTOM(blue)][RISE(yellow)][TOP(green)]
--               with a white cursor tracking current phase.
-- Departed button: records the lift just left the top → local sync + broadcast.
-- I Died button:   reports the current sync source killed you → death report + broadcast.

syncUI = nil  -- forward declaration used by OnUpdate above

function BuildSyncUI()
    if AldorTaxSyncUI then return AldorTaxSyncUI end  -- reuse if already built

    local BAR_W  = 460
    local BAR_H  = 28
    local PAD    = 14

    local p = CreateFrame("Frame", "AldorTaxSyncUI", UIParent, "BackdropTemplate")
    p:SetSize(BAR_W + PAD * 2, 100)
    p:SetPoint("TOP", UIParent, "TOP", 0, -120)
    p:SetFrameStrata("MEDIUM")
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop",  p.StopMovingOrSizing)
    p:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", PAD, -8)
    title:SetText("Aldor Lift  |cff888888click phase to sync|r")
    title:SetTextColor(1, 0.82, 0)

    local sourceLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceLabel:SetPoint("TOPRIGHT", -PAD, -8)
    sourceLabel:SetText("no sync")
    sourceLabel:SetTextColor(0.6, 0.6, 0.6)
    p.sourceLabel = sourceLabel

    -- ── Progress bar container ──────────────────────────────────────────────
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetPoint("TOPLEFT", PAD, -26)

    -- Phase definitions: index 0=FALL, 1=BOTTOM, 2=RISE, 3=TOP
    local segs = {
        { t = FALL_TIME,      r = 0.8, g = 0.15, b = 0.1,  name = "FALL"   },
        { t = WAIT_AT_BOTTOM, r = 0.3, g = 0.45, b = 0.8,  name = "BOTTOM" },
        { t = RISE_TIME,      r = 0.9, g = 0.7,  b = 0.1,  name = "RISE"   },
        { t = WAIT_AT_TOP,    r = 0.1, g = 0.75, b = 0.2,  name = "TOP"    },
    }

    local xOff = 0
    for i, s in ipairs(segs) do
        local w         = (s.t / CYCLE_TIME) * BAR_W
        local phaseIdx  = i - 1   -- 0-based
        local phaseName = s.name

        local segBtn = CreateFrame("Button", nil, bar)
        segBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", xOff, 0)
        segBtn:SetSize(w, BAR_H)

        local tex = segBtn:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(s.r, s.g, s.b, 0.85)
        tex:SetAllPoints()
        segBtn:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

        segBtn:SetScript("OnClick", function()
            -- Clicking a segment means "this phase just started".
            -- Subtract reaction time: the actual transition happened ~0.2s before
            -- the user clicked, so we back-date the reference accordingly.
            local now = GetTime() - CLICK_REACTION_TIME

            local phaseStart = ({ [0]=0, [1]=FALL_TIME, [2]=FALL_TIME+WAIT_AT_BOTTOM, [3]=FALL_TIME+WAIT_AT_BOTTOM+RISE_TIME })[phaseIdx]
            lastSync = now - phaseStart
            local rt = GetRealTime() - CLICK_REACTION_TIME - phaseStart
            if AldorTaxDB then
                AldorTaxDB.lastSyncRealTime = rt
                lastSyncSource = nil
                AldorTaxDB.lastSyncSource = nil
            end
            BroadcastSync(rt)

            print(string.format("|cff00ff00AldorTax: Synced at %s (−%.0fms reaction)|r", phaseName, CLICK_REACTION_TIME * 1000))
        end)

        xOff = xOff + w
    end

    -- Overlay frame above the segment buttons so labels and cursor are visible.
    -- Child Button frames render above bar's own textures/fonstrings, so we need
    -- a separate frame at a higher FrameLevel to hold the cursor and labels.
    local overlay = CreateFrame("Frame", nil, p)
    overlay:SetSize(BAR_W, BAR_H)
    overlay:SetPoint("TOPLEFT", PAD, -26)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 10)

    -- Phase labels
    local labelData = {
        { text = "FALL",   frac = (FALL_TIME * 0.5) / CYCLE_TIME },
        { text = "BOTTOM", frac = (FALL_TIME + WAIT_AT_BOTTOM * 0.5) / CYCLE_TIME },
        { text = "RISE",   frac = (FALL_TIME + WAIT_AT_BOTTOM + RISE_TIME * 0.5) / CYCLE_TIME },
        { text = "TOP",    frac = (CYCLE_TIME - WAIT_AT_TOP * 0.5) / CYCLE_TIME },
    }
    for _, ld in ipairs(labelData) do
        local lbl = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("CENTER", overlay, "LEFT", ld.frac * BAR_W, 0)
        lbl:SetText(ld.text)
        lbl:SetTextColor(1, 1, 1, 0.9)
    end

    -- Cursor (white vertical line)
    local cursor = overlay:CreateTexture(nil, "OVERLAY")
    cursor:SetColorTexture(1, 1, 1, 1)
    cursor:SetSize(3, BAR_H + 6)
    cursor:SetPoint("CENTER", overlay, "LEFT", 0, 0)
    p.cursor  = cursor
    p.bar     = bar
    p.overlay = overlay
    p:Hide()

    -- Time-remaining label riding the cursor
    local timeLabel = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("BOTTOM", cursor, "TOP", 0, 2)
    p.timeLabel = timeLabel

    -- ── I Died button ───────────────────────────────────────────────────────
    local diedBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    diedBtn:SetSize(130, 26)
    diedBtn:SetText("I Died")
    diedBtn:SetPoint("BOTTOM", 0, 12)
    diedBtn:SetScript("OnClick", function()
        BroadcastDied()
        lastSync       = 0
        lastSyncSource = nil
        warnFrame:Hide()
        print("|cffff0000AldorTax: Death reported and sync cleared.|r")
    end)

    -- ── Cursor update (called from OnUpdate) ────────────────────────────────
    function p.UpdateCursor()
        if lastSync <= 0 then
            p.cursor:SetPoint("CENTER", p.overlay, "LEFT", -10, 0)
            p.timeLabel:SetText("")
            p.sourceLabel:SetText("|cffff4400no sync|r")
            return
        end

        local phase = (GetTime() - lastSync) % CYCLE_TIME
        local xPos  = (phase / CYCLE_TIME) * BAR_W
        p.cursor:ClearAllPoints()
        p.cursor:SetPoint("CENTER", p.overlay, "LEFT", xPos, 0)
        p.timeLabel:SetText(string.format("%.1fs", CYCLE_TIME - phase))

        if lastSyncSource then
            p.sourceLabel:SetText(string.format("|cff88ff88received from %s|r", lastSyncSource.name))
        else
            p.sourceLabel:SetText("|cff00cc00local|r")
        end
    end

    return p
end

-- ─── Debug panel ─────────────────────────────────────────────────────────────

-- ─── Log panel ───────────────────────────────────────────────────────────────

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
    title:SetText("AldorTax — Log  |cff888888(select all, Ctrl+C to copy)|r")

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
    -- Populate with any messages already in the buffer
    if #logLines > 0 then
        eb:SetText(table.concat(logLines, "\n"))
        eb:SetCursorPosition(0)
    end

    p:Hide()  -- WoW frames start visible by default
    return p
end

-- ─── Interface Options panel ─────────────────────────────────────────────────

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
    sub:SetText("Aldor Rise elevator tracker — TBC Classic Anniversary")
    sub:SetTextColor(0.7, 0.7, 0.7)

    -- Sync output section
    local syncHdr = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    syncHdr:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    syncHdr:SetText("Sync broadcast channels")

    local cbParty   = MakeCheckbox(panel, syncHdr,  -4,  "syncParty",
        "Party / Raid",   "Broadcast calibration syncs to your party or raid group.")
    local cbChannel = MakeCheckbox(panel, cbParty,  nil, "syncChannel",
        "AldorTaxSync channel", "Broadcast to the shared AldorTaxSync custom channel.")
    local cbGuild   = MakeCheckbox(panel, cbChannel, nil, "syncGuild",
        "Guild",          "Broadcast calibration syncs to your guild.")

    panel:SetScript("OnShow", function()
        cbParty:Refresh(); cbChannel:Refresh(); cbGuild:Refresh()
    end)

    -- Register with Settings API
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "AldorTax")
        category.ID = "AldorTax"
        Settings.RegisterAddOnCategory(category)
        panel._settingsCategory = category
    end
    optionsPanel = panel
    return panel
end

-- ─── Slash commands ───────────────────────────────────────────────────────────

SLASH_ALDORTAX1 = "/aldortax"
SLASH_ALDORTAX2 = "/atax"
SlashCmdList["ALDORTAX"] = function(msg)
    if msg == "sync" then
        lastSync = GetTime()
        local rt = GetRealTime()
        if AldorTaxDB then
            AldorTaxDB.lastSyncRealTime = rt
            lastSyncSource = nil
            AldorTaxDB.lastSyncSource = nil
        end
        BroadcastSync(rt)
        print("|cff00ff00AldorTax: Synced and broadcast.|r")
    elseif msg == "log" then
        if not logPanel then logPanel = BuildLogPanel() end
        if logPanel:IsShown() then logPanel:Hide() else logPanel:Show() end
    elseif msg == "testmsg" then
        Log(string.format("|cffffff00AldorTax testmsg: prefixRegistered=%s  C_ChatInfo=%s  syncChanNum=%d|r",
            tostring(prefixRegistered), tostring(C_ChatInfo ~= nil), syncChanNum))
        SendTestWhisper()
    elseif msg == "reset" then
        lastSync = 0
        lastSyncSource = nil
        warnFrame:Hide()
        print("|cff00ff00AldorTax: Timer reset.|r")
    elseif msg == "ui" then
        if not syncUI then
            local ok, result = pcall(BuildSyncUI)
            if ok then syncUI = result
            else print("|cffff0000AldorTax BuildSyncUI error: " .. tostring(result) .. "|r") end
        end
        if syncUI then
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
    else
        print("|cffFFFF00AldorTax:|r")
        print("  /atax sync          — sync at departure + broadcast")
        print("  /atax reset         — clear timer")
        print("  /atax ui            — toggle sync panel")
        print("  /atax config        — open settings panel")
        print("  /atax log           — toggle copyable log panel")
        print("  /atax testmsg       — whisper yourself to test addon messaging")
        print("  /atax unblock Name-Realm  — remove from blocklist")
    end
end
