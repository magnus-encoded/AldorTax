-- SyncBus — the transport layer between Wire (codec) and the addon's domain
-- state. Owns channel selection + sending, the post-zone send cooldown, sender
-- trust/blocklist gating, and inbound dispatch. It knows nothing about cycles,
-- phases, or UI: it routes decoded frames to handlers the addon registers via
-- SyncBus.Init, and the cycle-time math stays on the domain side.

local _, NS = ...

local Wire = NS.Wire

local SyncBus = {}

local ADDON_PREFIX       = "ALDORTAX"
local ZONE_SEND_COOLDOWN = 5  -- seconds after zoning before we send addon messages

-- Trust thresholds (sender-reputation model; see CONTEXT.md "Trust"). Exposed
-- so the domain layer can reuse the soft-block boundary when deciding whether a
-- death report should invalidate an active sync.
SyncBus.SOFT_BLOCK_THRESHOLD = 3
SyncBus.HARD_BLOCK_THRESHOLD = 6

-- Dispatch handlers, registered by the addon via SyncBus.Init.
local onSync, onDeath, onCorrection, isKnownTransport

-- The addon owns the copyable log; route through it when present so module
-- diagnostics land in the same place as everything else.
local function Log(msg)
    if NS.Log then NS.Log(msg) end
end

-- ─── Trust / blocklist ───────────────────────────────────────────────────────
-- Sender-reputation: a sender accrues death reports keyed by "name-realm" in
-- AldorTaxDB.blocklist. Past the soft threshold their syncs are ignored (but
-- logged); past the hard threshold they're dropped silently.

local function BlockKey(name, realm) return name .. "-" .. realm end

function SyncBus.GetDeathCount(name, realm)
    if not AldorTaxDB or not AldorTaxDB.blocklist then return 0 end
    return AldorTaxDB.blocklist[BlockKey(name, realm)] or 0
end

function SyncBus.IsSoftBlocked(name, realm)
    return SyncBus.GetDeathCount(name, realm) >= SyncBus.SOFT_BLOCK_THRESHOLD
end

function SyncBus.IsHardBlocked(name, realm)
    return SyncBus.GetDeathCount(name, realm) >= SyncBus.HARD_BLOCK_THRESHOLD
end

function SyncBus.RecordDeathReport(name, realm)
    if not AldorTaxDB then return end
    if not AldorTaxDB.blocklist then AldorTaxDB.blocklist = {} end
    local key                 = BlockKey(name, realm)
    local count               = (AldorTaxDB.blocklist[key] or 0) + 1
    AldorTaxDB.blocklist[key] = count
    if count == SyncBus.SOFT_BLOCK_THRESHOLD then
        print(string.format("|cffff6600AldorTax: %s has %d death reports — syncs ignored.|r", key, count))
    elseif count == SyncBus.HARD_BLOCK_THRESHOLD then
        print(string.format("|cffff0000AldorTax: %s hard-blocked (%d deaths).|r", key, count))
    end
    return count
end

-- ─── Zone send cooldown ─────────────────────────────────────────────────────
-- After zoning into a transport area we hold off sending for a few seconds so a
-- burst of joins doesn't trip the server's addon-message rate limiter. Death
-- broadcasts deliberately bypass this (the caller doesn't consult CanSend).
local zonedInAt = 0

function SyncBus.NotifyZonedIn()
    zonedInAt = GetTime()
end

function SyncBus.CanSend()
    return GetTime() - zonedInAt >= ZONE_SEND_COOLDOWN
end

-- ─── Channel selection & sending ────────────────────────────────────────────

local prefixRegistered = false

function SyncBus.RegisterPrefix()
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

-- Channel number for General (localized). On Classic TBC+ General is
-- zone-scoped, so addon messages sent there only reach players in the same
-- zone — exactly the audience for transport sync. nil if unavailable.
function SyncBus.GetGeneralChannelNum()
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

-- Fan a message out across every channel that reaches nearby peers: zone-scoped
-- General, plus Guild and Party/Raid. Returns true if it went out anywhere.
function SyncBus.Send(msg)
    local sent = false
    -- General channel (zone-scoped on Classic TBC+)
    local generalNum = SyncBus.GetGeneralChannelNum()
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
    if NS.settings and NS.settings.debugChannel then
        Log("|cff88aaff[SYNC OUT] " .. msg:gsub("|", "||") .. "|r")
    end
    if not sent then
        local now = GetTime()
        if now - lastNoChannelWarn > 60 then
            lastNoChannelWarn = now
            Log("|cffffff00AldorTax: no channel to send on (solo)|r")
        end
    end
    return sent
end

-- ─── Inbound dispatch ────────────────────────────────────────────────────────

-- Register the domain handlers:
--   onSync(parsed)           applies an accepted sync.
--   onDeath(parsed, count)   reacts to a death report; count is the sender's
--                            running death tally after recording this one.
--   onCorrection(parsed)     logs a correction report (sync-accuracy feedback);
--                            never mutates cycle state.
--   isKnownTransport(id)     gates messages naming a transport we don't track.
function SyncBus.Init(handlers)
    onSync           = handlers.onSync
    onDeath          = handlers.onDeath
    onCorrection     = handlers.onCorrection
    isKnownTransport = handlers.isKnownTransport
end

-- CHAT_MSG_ADDON entry point: prefix-filter, drop our own echoes, decode via
-- Wire, gate on sender trust, then route to the registered handler. The wire
-- format and trust policy live here; cycle/phase math lives behind the handlers.
function SyncBus.Receive(prefix, message, chatType, sender)
    if prefix ~= ADDON_PREFIX then return end

    local tag    = message:sub(1, 1)
    local myName = UnitName("player")
    local isSelf = sender and myName and (sender == myName or sender:match("^" .. myName .. "%-"))

    -- T = connectivity test ping; logged even when it's our own echo so a dev
    -- can confirm the round-trip is alive.
    if tag == "T" then
        Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender),
            tostring(message):gsub("|", "||")))
        Log("|cff00ff00AldorTax: TEST MESSAGE RECEIVED OK — addon messaging is working.|r")
        return
    end

    if isSelf then return end -- guild/General reflect our own sends back to us

    Log(string.format("|cffffff00AldorTax RECV [%s] from %s: %s|r", chatType, tostring(sender),
        tostring(message):gsub("|", "||")))

    local parsed = Wire.Parse(message)
    if not parsed then
        Log("|cffffff00AldorTax: ignoring malformed or unknown-version message|r")
        return
    end

    if parsed.kind == "S" then
        if not parsed.phase or not (isKnownTransport and isKnownTransport(parsed.transportID)) then return end
        if SyncBus.IsHardBlocked(parsed.name, parsed.realm) then return end
        if SyncBus.IsSoftBlocked(parsed.name, parsed.realm) then
            Log(string.format("|cffff6600AldorTax: Ignored sync from soft-blocked %s-%s|r",
                parsed.name, parsed.realm))
            return
        end
        if onSync then onSync(parsed) end
    elseif parsed.kind == "D" then
        if not parsed.phase or not parsed.name
            or not (isKnownTransport and isKnownTransport(parsed.transportID)) then
            return
        end
        local count = SyncBus.RecordDeathReport(parsed.name, parsed.realm)
        if onDeath then onDeath(parsed, count) end
    elseif parsed.kind == "C" then
        -- Correction reports are observability only — no cycle-state mutation —
        -- so hard-block is the only gate worth applying.
        if not (isKnownTransport and isKnownTransport(parsed.transportID)) then return end
        if SyncBus.IsHardBlocked(parsed.name, parsed.realm) then return end
        if onCorrection then onCorrection(parsed) end
    end
end

NS.SyncBus = SyncBus
