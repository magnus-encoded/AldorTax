-- WoW API mock for integration testing AldorTax
-- Provides the Blizzard API surface plus test helpers to drive frame updates,
-- fire events, intercept outgoing messages, and advance the clock.

local MockAPI = {}

-- Lua 5.3+ merged atan2 into atan; WoW uses Lua 5.1 which has math.atan2
if not math.atan2 then math.atan2 = math.atan end

-- ─── Clock state ────────────────────────────────────────────────────────────

local _serverTime = 1775168000
local _gameTime   = 10000.000    -- GetTime() — high-precision monotonic
local _wallTime   = 1775168000   -- time() — integer Unix

function GetTime()       return _gameTime   end
function time()          return _wallTime   end
function GetServerTime() return _serverTime end
function date(fmt, t)    return os.date(fmt, t or _wallTime) end

function MockAPI.SetClock(serverTime, gameTime, wallTime)
    _serverTime = serverTime
    _gameTime   = gameTime   or _gameTime
    _wallTime   = wallTime   or serverTime
end

function MockAPI.AdvanceTime(seconds)
    _gameTime   = _gameTime   + seconds
    _wallTime   = _wallTime   + math.floor(seconds)
    _serverTime = _serverTime + math.floor(seconds)
end

-- Tick server time by 1 without advancing game time much (simulates the
-- sub-second moment when GetServerTime() rolls over)
function MockAPI.TickServerTime()
    _serverTime = _serverTime + 1
    _wallTime   = _wallTime + 1
    _gameTime   = _gameTime + 0.016  -- one frame
end

-- ─── Frame system ───────────────────────────────────────────────────────────

local _allFrames    = {}   -- every frame created, in order
local _eventFrames  = {}   -- event name → list of frames registered for it

local FrameMethods = {}
FrameMethods.__index = FrameMethods

-- Dimensions / layout (no-ops for testing, but store values)
function FrameMethods:SetSize(w, h) self._w = w; self._h = h end
function FrameMethods:SetWidth(w)   self._w = w end
function FrameMethods:SetHeight(h)  self._h = h end
function FrameMethods:GetWidth()    return self._w or 0 end
function FrameMethods:GetBottom()   return 0 end
function FrameMethods:GetTop()      return self._h or 0 end
function FrameMethods:SetPoint(...)         end
function FrameMethods:ClearAllPoints()      end
function FrameMethods:SetAllPoints()        end
function FrameMethods:GetPoint()    return "CENTER", nil, "CENTER", 0, 0 end

-- Visibility
function FrameMethods:Show()    self._visible = true end
function FrameMethods:Hide()    self._visible = false end
function FrameMethods:IsShown() return self._visible == true end

-- Display properties (no-ops)
function FrameMethods:SetAlpha(a)              self._alpha = a end
function FrameMethods:SetScale(s)              self._scale = s end
function FrameMethods:GetEffectiveScale()       return self._scale or 1 end
function FrameMethods:SetMovable(m)            end
function FrameMethods:EnableMouse(e)           end
function FrameMethods:RegisterForDrag(...)     end
function FrameMethods:SetFrameStrata(s)        end
function FrameMethods:SetFrameLevel(l)         self._frameLevel = l end
function FrameMethods:GetFrameLevel()          return self._frameLevel or 1 end
function FrameMethods:SetBackdrop(bd)          end
function FrameMethods:SetBackdropColor(...)    end
function FrameMethods:SetBackdropBorderColor(...)  end
function FrameMethods:StartMoving()            end
function FrameMethods:StopMovingOrSizing()     end
function FrameMethods:SetHitRectInsets(...)     end

-- Scripts
function FrameMethods:SetScript(event, fn)
    self._scripts = self._scripts or {}
    self._scripts[event] = fn
end
function FrameMethods:GetScript(event)
    return self._scripts and self._scripts[event]
end
function FrameMethods:HookScript(event, fn)
    local old = self:GetScript(event)
    self:SetScript(event, function(...)
        if old then old(...) end
        fn(...)
    end)
end

-- Events
function FrameMethods:RegisterEvent(e)
    _eventFrames[e] = _eventFrames[e] or {}
    table.insert(_eventFrames[e], self)
end
function FrameMethods:UnregisterEvent(e)
    if not _eventFrames[e] then return end
    for i, f in ipairs(_eventFrames[e]) do
        if f == self then table.remove(_eventFrames[e], i); return end
    end
end

-- Children
function FrameMethods:CreateFontString(name, layer, template)
    local fs = setmetatable({
        _type = "FontString", _text = "", _visible = true,
    }, FrameMethods)
    return fs
end
function FrameMethods:CreateTexture(name, layer)
    return setmetatable({ _type = "Texture", _visible = true }, FrameMethods)
end

-- FontString
function FrameMethods:SetText(t)            self._text = t end
function FrameMethods:GetText()             return self._text or "" end
function FrameMethods:SetTextColor(...)     end
function FrameMethods:SetShadowColor(...)   end
function FrameMethods:SetShadowOffset(...)  end
function FrameMethods:SetFontObject(f)      end
function FrameMethods:GetStringWidth()      return #(self._text or "") * 7 end

-- Texture
function FrameMethods:SetTexture(t)         end
function FrameMethods:SetColorTexture(...)  end
function FrameMethods:SetBlendMode(m)       end

-- Button
function FrameMethods:SetNormalTexture(t)       end
function FrameMethods:SetPushedTexture(t)       end
function FrameMethods:SetHighlightTexture(t)    end
function FrameMethods:SetCheckedTexture(t)      end
function FrameMethods:SetNormalFontObject(f)    end
function FrameMethods:SetHighlightFontObject(f) end
function FrameMethods:GetChecked()  return self._checked end
function FrameMethods:SetChecked(v) self._checked = v end

-- EditBox
function FrameMethods:SetMultiLine(m)          end
function FrameMethods:SetAutoFocus(f)          end
function FrameMethods:SetCursorPosition(p)     end
function FrameMethods:ClearFocus()             end

-- Tooltip
function FrameMethods:SetOwner(...)  end
function FrameMethods:AddLine(...)   end

function CreateFrame(frameType, name, parent, template)
    local f = setmetatable({
        _type = frameType,
        _name = name,
        _visible = false,
        _scripts = {},
    }, FrameMethods)
    table.insert(_allFrames, f)
    if name then _G[name] = f end
    return f
end

UIParent    = setmetatable({ _type = "UIParent", _w = 1920, _h = 1080, _visible = true, _scripts = {} }, FrameMethods)
GameTooltip = setmetatable({ _type = "GameTooltip", _visible = false, _scripts = {} }, FrameMethods)

-- ─── Network / messaging ────────────────────────────────────────────────────

local _sentMessages = {}   -- captured outgoing messages
local _latencyHome  = 50
local _latencyWorld = 80

function GetNetStats()
    return 0, 0, _latencyHome, _latencyWorld
end

C_ChatInfo = {}
function C_ChatInfo.RegisterAddonMessagePrefix(prefix) return true end
function C_ChatInfo.SendAddonMessage(prefix, msg, chatType, target)
    table.insert(_sentMessages, {
        prefix   = prefix,
        message  = msg,
        chatType = chatType,
        target   = target,
        time     = _gameTime,
    })
    return true
end

function RegisterAddonMessagePrefix(prefix) return true end
function SendAddonMessage(prefix, msg, chatType, target)
    return C_ChatInfo.SendAddonMessage(prefix, msg, chatType, target)
end
function GetChannelName(name) return 1, name end
function JoinChannelByName(name) return 1, name end

function MockAPI.GetSentMessages() return _sentMessages end
function MockAPI.ClearSentMessages() _sentMessages = {} end
function MockAPI.SetLatency(home, world)
    _latencyHome  = home
    _latencyWorld = world
end

-- ─── Player / world ─────────────────────────────────────────────────────────

local _zone     = "Shattrath City"
local _subZone  = "Aldor Rise"
local _mapX, _mapY = 0.4169, 0.3860

function UnitName(unit)
    if unit == "player" then return "TestPlayer" end
    return nil
end
function UnitExists(unit) return unit == "player" end
function UnitInRaid(unit) return false end
function GetRealmName() return "TestRealm" end
function GetZoneText() return _zone end
function GetSubZoneText() return _subZone end
function GetMinimapZoneText() return _subZone end
function GetNumGroupMembers() return 0 end
function InCombatLockdown() return false end
function IsInInstance() return false, nil end
function DoEmote(emote, target) end
function SendChatMessage(msg, chatType, lang, channel) end
function GetCursorPosition() return 0, 0 end
function GetBuildInfo() return "2.5.5", "45745", "Mar 1 2026", 20505 end
function CombatLogGetCurrentEventInfo() return 0, "NONE" end

function MockAPI.SetZone(zone, subzone)
    _zone    = zone
    _subZone = subzone or zone
end
function MockAPI.SetMapPosition(x, y)
    _mapX = x; _mapY = y
end

-- ─── Map API ────────────────────────────────────────────────────────────────

C_Map = {}
function C_Map.GetBestMapForUnit(unit) return 111 end
function C_Map.GetPlayerMapPosition(mapID, unit)
    return { GetXY = function() return _mapX, _mapY end }
end

-- ─── Settings / Interface Options ───────────────────────────────────────────

Settings = {}
function Settings.RegisterCanvasLayoutCategory(frame, name) return { ID = name } end
function Settings.RegisterAddOnCategory(category) end
function Settings.OpenToCategory(id) end

-- ─── Globals expected by the addon ──────────────────────────────────────────

SlashCmdList = SlashCmdList or {}
AldorTaxDB   = nil
ANCHOR_TOP   = "TOP"
ANCHOR_RIGHT = "RIGHT"
print        = print  -- keep Lua's print

-- ─── Test driver functions ──────────────────────────────────────────────────

-- Fire OnUpdate on every frame that has one
function MockAPI.FireOnUpdate(elapsed)
    elapsed = elapsed or 0.016
    for _, f in ipairs(_allFrames) do
        local fn = f._scripts and f._scripts["OnUpdate"]
        if fn then fn(f, elapsed) end
    end
end

-- Fire a WoW event on all frames registered for it
function MockAPI.FireEvent(event, ...)
    if not _eventFrames[event] then return end
    for _, f in ipairs(_eventFrames[event]) do
        local fn = f._scripts and f._scripts["OnEvent"]
        if fn then fn(f, event, ...) end
    end
end

-- Run calibration: tick server time and fire OnUpdate until the calibration
-- frame detects the tick and sets serverTimeOffset / realTimeOffset
function MockAPI.RunCalibration()
    -- Fire one OnUpdate at current time (sets prevSrv)
    MockAPI.FireOnUpdate(0.016)
    -- Tick the server clock and fire again (triggers calibration)
    MockAPI.TickServerTime()
    MockAPI.FireOnUpdate(0.016)
end

-- Simulate receiving an addon message from another player
function MockAPI.ReceiveAddonMessage(prefix, message, chatType, sender)
    MockAPI.FireEvent("CHAT_MSG_ADDON", prefix, message, chatType, sender)
end

-- Full initialization sequence: calibrate → ADDON_LOADED → zone detect
function MockAPI.InitAddon()
    MockAPI.RunCalibration()
    MockAPI.FireEvent("ADDON_LOADED", "AldorTax")
    -- Fire a couple OnUpdates for the channel join poller
    MockAPI.FireOnUpdate(0.016)
    MockAPI.FireOnUpdate(0.016)
end

-- Reset all state (for running multiple tests in sequence)
function MockAPI.Reset()
    _allFrames   = {}
    _eventFrames = {}
    _sentMessages = {}
    _serverTime  = 1775168000
    _gameTime    = 10000.000
    _wallTime    = 1775168000
    _zone        = "Shattrath City"
    _subZone     = "Aldor Rise"
    _mapX, _mapY = 0.4169, 0.3860
    _latencyHome  = 50
    _latencyWorld = 80
    AldorTaxDB   = nil
    -- Re-create UIParent/GameTooltip
    UIParent    = setmetatable({ _type = "UIParent", _w = 1920, _h = 1080, _visible = true, _scripts = {} }, FrameMethods)
    GameTooltip = setmetatable({ _type = "GameTooltip", _visible = false, _scripts = {} }, FrameMethods)
end

return MockAPI
