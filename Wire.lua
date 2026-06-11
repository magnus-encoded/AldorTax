-- Wire — pure codec for AldorTax's sync (S), death (D), and correction-report
-- (C) addon-message frames. No WoW API calls, no side effects, no state beyond
-- the version tables. The caller supplies every field already computed; Wire
-- only formats and parses.
--
-- Frame layouts (fields shown after the "S|"/"D|" tag, starting at the version):
--   S v6/v5: S|ver|transportID|phase|name|realm|fall|bottom|rise|top|origin|srvPhase
--   S v4:    S|ver|transportID|phase|name|realm|fall|bottom|rise|top              (no origin/srvPhase)
--   S v3:    S|ver|phase|name|realm|fall|bottom|rise|top                          (transportID implicitly "aldor")
--   D v6..4: D|ver|transportID|phase|name|realm|origin
--   D v3:    D|ver|phase|name|realm                                              (implicitly "aldor", no origin)
--   C v6:    C|ver|transportID|recvOffset|correction|name|realm|srcName|srcRealm
--            "name received a sync from srcName that put transportID's cycle
--            start at server epoch + recvOffset (mod cycleTime), and corrected
--            it by ±correction seconds with a first-hand calibration click."
--            Pre-v6 clients reject the unknown C tag in Parse and ignore it.

local _, NS = ...

local Wire = {}

-- Current send-side wire version. v6 is byte-identical to v5; the bump in
-- v0.9.1 only flags clients carrying the fixed BroadcastSync srvPhase math.
Wire.MSG_VERSION = 6

-- Versions the parser accepts. v3/v4 are legacy, v5/v6 current; they all share
-- one parse path. Anything outside this set is rejected so a future wire-format
-- break can't be silently misread.
Wire.KNOWN_MSG_VERSIONS = { [3] = true, [4] = true, [5] = true, [6] = true }

-- ─── Encode (send side) ──────────────────────────────────────────────────────

function Wire.EncodeSync(transportID, phase, name, realm, fall, bottom, rise, top, origin, srvPhase)
    return string.format("S|%d|%s|%.3f|%s|%s|%.3f|%.3f|%.3f|%.3f|%s|%.3f",
        Wire.MSG_VERSION, transportID, phase, name, realm,
        fall, bottom, rise, top, origin, srvPhase)
end

function Wire.EncodeDeath(transportID, phase, name, realm, origin)
    return string.format("D|%d|%s|%.3f|%s|%s|%s",
        Wire.MSG_VERSION, transportID, phase, name, realm, origin)
end

-- Empty fields would vanish in the pipe-split on the receive side and shift
-- everything after them; realms can legitimately be empty, so placeholder them.
local function nonEmpty(s)
    return (s and s ~= "") and s or "?"
end

function Wire.EncodeCorrection(transportID, recvOffset, correction, name, realm, srcName, srcRealm)
    return string.format("C|%d|%s|%.3f|%.3f|%s|%s|%s|%s",
        Wire.MSG_VERSION, transportID, recvOffset, correction,
        nonEmpty(name), nonEmpty(realm), nonEmpty(srcName), nonEmpty(srcRealm))
end

-- ─── Parse (receive side) ──────────────────────────────────────────────────────

-- Split the body (everything past the "X|" tag) into its pipe-delimited fields.
-- parts[1] is the version; transport-specific fields follow.
local function fields(message)
    local parts = {}
    for p in message:sub(3):gmatch("[^|]+") do parts[#parts + 1] = p end
    return parts
end

local function parseSync(version, parts)
    local t = { kind = "S", version = version }
    if version >= 4 and #parts >= 5 then
        t.transportID = parts[2]
        t.phase       = tonumber(parts[3])
        t.name        = parts[4]
        t.realm       = parts[5]
        t.fall        = tonumber(parts[6])
        t.bottom      = tonumber(parts[7])
        t.rise        = tonumber(parts[8])
        t.top         = tonumber(parts[9])
        t.origin      = parts[10] or "C"    -- v4 carries no origin; treat as calibrated
        t.srvPhase    = tonumber(parts[11]) -- v5+; nil for v4
    elseif version >= 3 and #parts >= 4 then
        t.transportID = "aldor"             -- v3 predates multi-transport IDs
        t.phase       = tonumber(parts[2])
        t.name        = parts[3]
        t.realm       = parts[4]
        t.fall        = tonumber(parts[5])
        t.bottom      = tonumber(parts[6])
        t.rise        = tonumber(parts[7])
        t.top         = tonumber(parts[8])
        t.origin      = "C"
    else
        return nil
    end
    if not t.phase then return nil end
    return t
end

local function parseDeath(version, parts)
    local t = { kind = "D", version = version }
    if version >= 4 and #parts >= 5 then
        t.transportID = parts[2]
        t.phase       = tonumber(parts[3])
        t.name        = parts[4]
        t.realm       = parts[5]
        t.origin      = parts[6]
    elseif version >= 3 and #parts >= 4 then
        t.transportID = "aldor"
        t.phase       = tonumber(parts[2])
        t.name        = parts[3]
        t.realm       = parts[4]
        t.origin      = "C"
    else
        return nil
    end
    return t
end

local function parseCorrection(version, parts)
    if version < 6 or #parts < 8 then return nil end
    local t = {
        kind        = "C",
        version     = version,
        transportID = parts[2],
        recvOffset  = tonumber(parts[3]),
        correction  = tonumber(parts[4]),
        name        = parts[5],
        realm       = parts[6],
        srcName     = parts[7],
        srcRealm    = parts[8],
    }
    if not t.recvOffset or not t.correction then return nil end
    return t
end

-- Decode an S, D, or C frame into a fully-populated table, or nil when the
-- frame is too short, has an unknown tag, or carries a version outside
-- KNOWN_MSG_VERSIONS.
function Wire.Parse(message)
    if not message or #message < 3 then return nil end
    local tag = message:sub(1, 1)
    if tag ~= "S" and tag ~= "D" and tag ~= "C" then return nil end

    local parts   = fields(message)
    local version = tonumber(parts[1])
    if not version or not Wire.KNOWN_MSG_VERSIONS[version] then return nil end

    if tag == "S" then return parseSync(version, parts) end
    if tag == "C" then return parseCorrection(version, parts) end
    return parseDeath(version, parts)
end

NS.Wire = Wire
