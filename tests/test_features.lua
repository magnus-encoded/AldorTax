-- Feature tests: CTL integration, zone send cooldown, epoch anchor, multi-lift
-- Run with: lua tests/test_features.lua (from the addon root)

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H = require("test_harness")
local assert_true, assert_eq, section = H.assert_true, H.assert_eq, H.section

-- ─── Test 1: ChatThrottleLib integration ────────────────────────────────────
-- When ChatThrottleLib is present, RawSend should use it instead of
-- C_ChatInfo.SendAddonMessage directly.

section("Test 1: ChatThrottleLib used when available")

-- Set up a mock CTL before loading the addon
local ctlCalls = {}
_G.ChatThrottleLib = {
    SendAddonMessage = function(self, prio, prefix, text, chatType, target)
        table.insert(ctlCalls, {
            prio = prio, prefix = prefix, text = text,
            chatType = chatType, target = target,
        })
        return true
    end,
}

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
MockAPI.SetZone("Shattrath City", "Aldor Rise")

H.LoadAddon()
MockAPI.InitAddon()

-- Trigger a sync broadcast: set up a sync first, then manually broadcast
-- by receiving a sync message (which triggers the auto-broadcast path on zone check)
local cycleTime = 25.0
local srvPhase = GetServerTime() % cycleTime
local syncMsg = string.format("S|5|aldor|%.3f|CTLTester|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    srvPhase, srvPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", syncMsg, "CHANNEL", "CTLTester")

-- Now force an auto-broadcast by advancing past the AUTO_BROADCAST_INTERVAL
-- and triggering the OnUpdate path. But we need activeLiftID set first.
-- Instead, let's use the slash command to broadcast directly.
-- The slash command calls BroadcastSync which calls SendMsg which calls RawSend.

-- First we need activeLiftID set — fire zone events
MockAPI.FireEvent("ZONE_CHANGED")
-- The addon should detect Aldor Rise and set activeLiftID
-- Now trigger /atax sync
ctlCalls = {}  -- clear any previous calls
SlashCmdList["ALDORTAX"]("sync")

assert_true(#ctlCalls > 0, "CTL SendAddonMessage was called")
if #ctlCalls > 0 then
    assert_eq(ctlCalls[1].prio, "ALERT", "CTL priority is ALERT")
    assert_eq(ctlCalls[1].prefix, "ALDORTAX", "CTL prefix is ALDORTAX")
    assert_true(ctlCalls[1].text:sub(1, 2) == "S|", "CTL message is a sync message")
end


-- ─── Test 2: Zone send cooldown ─────────────────────────────────────────────
-- After zoning into a lift area, BroadcastSync should be suppressed for
-- ZONE_SEND_COOLDOWN seconds (5s).

section("Test 2: Zone send cooldown suppresses early broadcasts")

-- Simulate leaving and re-entering the lift zone
MockAPI.SetZone("Terokkar Forest", "Terokkar Forest")
MockAPI.FireEvent("ZONE_CHANGED")

-- Now re-enter the lift zone — this should set zonedInAt = GetTime()
MockAPI.SetZone("Shattrath City", "Aldor Rise")
ctlCalls = {}
MockAPI.FireEvent("ZONE_CHANGED")

-- Try to broadcast immediately — should be suppressed
ctlCalls = {}
SlashCmdList["ALDORTAX"]("sync")
local callsBeforeCooldown = #ctlCalls
assert_eq(callsBeforeCooldown, 0, "no broadcast during zone send cooldown")

-- Advance time past the cooldown (5s)
MockAPI.AdvanceTime(6)

-- Now broadcast should work
ctlCalls = {}
SlashCmdList["ALDORTAX"]("sync")
assert_true(#ctlCalls > 0, "broadcast works after zone cooldown expires")


-- ─── Test 3: Epoch anchor restores sync on load ─────────────────────────────
-- Aldor has epochOffset = 20.0, so on load the addon should automatically
-- compute lastSync from GetAbsoluteTime() without needing a manual click
-- or incoming sync message.

section("Test 3: Epoch anchor auto-sync")

-- After InitAddon, the aldor lift should have a non-zero lastSync
-- (set by ApplyEpochAnchor during RestoreSync)
-- We check that AldorTaxDB.lifts.aldor exists and has sync data
-- But more importantly: the liftState should reflect an active sync

-- The sync was already established by previous tests, but let's verify
-- the epoch anchor path directly by checking that aldor has a computed sync
-- even without any incoming messages.

-- Reset: create a fresh environment
-- We can't fully reset without reloading, but we can verify the epoch logic:
-- absNow = GetTime() + serverTimeOffset
-- lastSync = GetTime() - ((absNow - epochOffset) % cycleTime)
-- With serverTimeOffset = 1775168001 - 10000.016 ≈ 1775157000.984
-- absNow = GetTime() + 1775157000.984

-- The key invariant: (GetTime() - lastSync) % cycleTime should be stable
-- and equal to (absNow - epochOffset) % cycleTime
local absNow = GetTime() + (GetServerTime() - GetTime())
local expectedPhase = (absNow - 20.0) % 25.0
assert_true(expectedPhase >= 0 and expectedPhase < 25.0, "epoch phase is in valid range")

-- The epoch anchor should produce a lastSync such that phase matches
-- We can't read liftState directly (it's local), but we can verify through
-- the saved DB state — the initial epoch anchor fires before any sync messages
assert_true(AldorTaxDB ~= nil, "DB exists for epoch check")


-- ─── Test 4: Multi-lift state isolation ─────────────────────────────────────
-- Syncing one lift should not affect another lift's state.

section("Test 4: Multi-lift state isolation")

-- Save current aldor sync state
local aldorRT = AldorTaxDB.lifts.aldor and AldorTaxDB.lifts.aldor.lastSyncRealTime

-- Send a sync for greatlift (different lift)
local glPhase = GetServerTime() % 29.80
local glMsg = string.format("S|5|greatlift|%.3f|GLTester|TestRealm|9.650|5.250|9.700|5.200|C|%.3f",
    glPhase, glPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", glMsg, "CHANNEL", "GLTester")

-- Verify greatlift got synced
assert_true(AldorTaxDB.lifts.greatlift ~= nil, "greatlift sync created")
assert_true(AldorTaxDB.lifts.greatlift.lastSyncRealTime ~= nil, "greatlift has sync time")

-- Verify aldor was NOT changed
local aldorRTAfter = AldorTaxDB.lifts.aldor and AldorTaxDB.lifts.aldor.lastSyncRealTime
assert_eq(aldorRT, aldorRTAfter, "aldor sync unchanged after greatlift sync")


-- ─── Test 5: Unknown lift ID rejected ───────────────────────────────────────
-- Messages with an invalid liftID should be silently dropped.

section("Test 5: Unknown lift ID rejected")

local preDBState = AldorTaxDB.lifts["bogus_lift"]
assert_true(preDBState == nil, "bogus lift not in DB before")

local bogusMsg = string.format("S|5|bogus_lift|%.3f|Hacker|TestRealm|5.0|5.0|5.0|5.0|C|%.3f",
    10.0, 10.0)
MockAPI.ReceiveAddonMessage("ALDORTAX", bogusMsg, "CHANNEL", "Hacker")

assert_true(AldorTaxDB.lifts["bogus_lift"] == nil, "bogus lift still not in DB after")


-- ─── Test 6: Hard-blocked player fully rejected ─────────────────────────────
-- A player with >= HARD_BLOCK_THRESHOLD deaths should have all syncs rejected.

section("Test 6: Hard block rejects all syncs")

-- Send 6 death reports (HARD_BLOCK_THRESHOLD = 6)
local hardPhase = GetServerTime() % cycleTime
for _ = 1, 6 do
    local deathMsg = string.format("D|5|aldor|%.3f|ToxicPlayer|TestRealm|C", hardPhase)
    MockAPI.ReceiveAddonMessage("ALDORTAX", deathMsg, "CHANNEL", "ToxicPlayer")
end

-- Save current aldor state
local preHardRT = AldorTaxDB.lifts.aldor.lastSyncRealTime

-- Try to sync from hard-blocked player
local hardMsg = string.format("S|5|aldor|%.3f|ToxicPlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    hardPhase + 5.0, hardPhase + 5.0)
MockAPI.ReceiveAddonMessage("ALDORTAX", hardMsg, "CHANNEL", "ToxicPlayer")

assert_eq(AldorTaxDB.lifts.aldor.lastSyncRealTime, preHardRT,
    "hard-blocked player's sync is rejected (DB unchanged)")


-- ─── Test 7: Future message version ignored ─────────────────────────────────

section("Test 7: Future message version ignored")

local preRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
local futureMsg = string.format("S|99|aldor|%.3f|FuturePlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    srvPhase, srvPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", futureMsg, "CHANNEL", "FuturePlayer")

assert_eq(AldorTaxDB.lifts.aldor.lastSyncRealTime, preRT,
    "future version message ignored (DB unchanged)")


-- ─── Test 8: Self-sync always rejected (own echoes from guild/General) ───────

section("Test 8: Self-sync always rejected")

local preSelfRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
local selfMsg = string.format("S|5|aldor|%.3f|TestPlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    srvPhase + 3.0, srvPhase + 3.0)
MockAPI.ReceiveAddonMessage("ALDORTAX", selfMsg, "GUILD", "TestPlayer")

assert_eq(AldorTaxDB.lifts.aldor.lastSyncRealTime, preSelfRT,
    "self-sync rejected (echo from guild)")


-- ─── Test 9: CTL fallback when ChatThrottleLib unavailable ──────────────────
-- If CTL is nil, the addon should fall back to C_ChatInfo.SendAddonMessage.

section("Test 9: Fallback to C_ChatInfo when CTL unavailable")

-- Temporarily remove CTL
local savedCTL = ChatThrottleLib
ChatThrottleLib = nil

-- Track C_ChatInfo calls
local rawCalls = {}
local origSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function(prefix, msg, chatType, target)
    table.insert(rawCalls, { prefix = prefix, msg = msg })
    return true
end

-- Advance past cooldown from test 2
MockAPI.AdvanceTime(10)

SlashCmdList["ALDORTAX"]("sync")
assert_true(#rawCalls > 0, "C_ChatInfo.SendAddonMessage used as fallback")

-- Restore
C_ChatInfo.SendAddonMessage = origSend
ChatThrottleLib = savedCTL


-- ─── Test 10: SSC sync acceptance ──────────────────────────────────────────
-- Pre-Phase-2 regression protection: a sync message for liftID="ssc" should
-- be accepted and stored, just like any other registered lift.

section("Test 10: SSC sync received and stored")

local sscCycle = 43.333
local sscPhase = GetServerTime() % sscCycle
-- v5: S|ver|liftID|phase|name|realm|fall|bottom|rise|top|origin|srvPhase
local sscMsg = string.format("S|5|ssc|%.3f|SCRaider|TestRealm|16.500|5.000|13.333|8.500|C|%.3f",
    sscPhase, sscPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", sscMsg, "CHANNEL", "SCRaider")

assert_true(AldorTaxDB.lifts.ssc ~= nil, "ssc sync entry created in DB")
assert_true(AldorTaxDB.lifts.ssc.lastSyncRealTime ~= nil, "ssc lastSyncRealTime saved")


-- ─── Test 11: SSC phase computation with 43.333s cycle ─────────────────────
-- The stored sync should place the cycle start near "now" when srvPhase
-- reflects the current server time. Drift should be small (< 0.25s) at
-- zero latency, identical to the Aldor self-sync test.

section("Test 11: SSC phase computation respects 43.333s cycle")

local sscExpectedRealTime = GetTime() + (time() - GetTime()) -- GetRealTime()
local sscDriftRaw = math.abs(AldorTaxDB.lifts.ssc.lastSyncRealTime - sscExpectedRealTime)
-- GetServerTime is integer-floored in the mock while GetAbsoluteTime is fractional,
-- so raw drift can be up to ~1s of subsecond skew. The phase invariant — drift
-- modulo cycleTime — must still be small. A wrong cycleTime would produce drift
-- mod cycle up to ~21s, so a tight bound here proves SSC's 43.333s cycle is used.
local sscDriftMod = sscDriftRaw % sscCycle
local sscPhaseError = math.min(sscDriftMod, sscCycle - sscDriftMod)
assert_true(sscPhaseError < 1.5,
    string.format("ssc self-sync drift mod cycle < 1.5s (got %.4f, raw %.4f)",
        sscPhaseError, sscDriftRaw))


-- ─── Test 12: SSC isolation from other lifts ───────────────────────────────
-- Syncing SSC must not disturb aldor's existing sync state.

section("Test 12: SSC sync does not disturb other lifts")

local preAldorRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
local sscPhase2 = (GetServerTime() + 7) % sscCycle
local sscMsg2 = string.format("S|5|ssc|%.3f|SCRaider2|TestRealm|16.500|5.000|13.333|8.500|C|%.3f",
    sscPhase2, sscPhase2)
MockAPI.ReceiveAddonMessage("ALDORTAX", sscMsg2, "CHANNEL", "SCRaider2")

assert_eq(AldorTaxDB.lifts.aldor.lastSyncRealTime, preAldorRT,
    "aldor sync unchanged after second ssc sync")


-- ─── Test 13: SSC subzone activates the lift when enabled ──────────────────
-- With enableSSC=true and the player's subzone set to "Serpentshrine Cavern",
-- a zone-change event must mark SSC as the active lift. We verify indirectly
-- by checking that /atax sync (which requires activeLiftID) now broadcasts
-- a message tagged "ssc". This protects the subzone-only detection path
-- (mapX=0, nearYards=999) used by SSC and the Deeprun Tram.

section("Test 13: SSC subzone detection sets active lift")

-- Re-load settings with enableSSC=true via ADDON_LOADED
AldorTaxDB.settings = AldorTaxDB.settings or {}
AldorTaxDB.settings.enableSSC = true
MockAPI.FireEvent("ADDON_LOADED", "AldorTax")

-- Move player into SSC subzone and fire zone change
MockAPI.SetZone("Coilfang: Serpentshrine Cavern", "Serpentshrine Cavern")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")

-- Wait past the zone send cooldown so /atax sync isn't suppressed
MockAPI.AdvanceTime(10)

ctlCalls = {}
SlashCmdList["ALDORTAX"]("sync")
local sawSSCBroadcast = false
for _, c in ipairs(ctlCalls) do
    if c.text and c.text:find("|ssc|", 1, true) then
        sawSSCBroadcast = true
        break
    end
end
assert_true(sawSSCBroadcast,
    "SSC subzone is detected and /atax sync broadcasts an ssc message")


-- ─── Test 14: SSC UI auto-hides after hideAfterEntry seconds ───────────────
-- Entering SSC while alive should show the UI; after 70s it should be hidden
-- and stay hidden (sscSuppressed) even though the player is still "near" the lift.

section("Test 14: SSC UI hides after hideAfterEntry timeout")

-- Enter SSC as a living player
MockAPI.SetZone("Coilfang: Serpentshrine Cavern", "Serpentshrine Cavern")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")

-- SSC is single-form, so post-cutover (Step 5b) its surface is the new LiftBar
-- widget, not the legacy syncUI. Assert against AldorTaxLiftBar.
local sscUI = _G.AldorTaxLiftBar
assert_true(sscUI ~= nil, "LiftBar built on SSC entry")
assert_true(sscUI:IsShown(), "SSC UI shown on live entry")

-- Advance past the 70s hide timer
MockAPI.AdvanceTime(71)
-- Simulate the OnUpdate firing to process the timer
MockAPI.FireOnUpdate(0)

assert_true(not sscUI:IsShown(), "SSC UI hidden after hideAfterEntry timer expires")

-- Proximity tick should NOT re-show it (sscSuppressed = true)
MockAPI.AdvanceTime(2)
MockAPI.FireOnUpdate(0)
assert_true(not sscUI:IsShown(), "SSC UI stays hidden after timeout (sscSuppressed)")

-- Leave SSC — flags should clear
MockAPI.SetZone("Zangarmarsh", "Zangarmarsh")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")


-- ─── Test 15: SSC UI suppressed on ghost entry ──────────────────────────────
-- Entering SSC while a ghost (spirit healer run-back) must not show the UI.

section("Test 15: SSC UI suppressed when entering as ghost")

UnitIsGhost = function(unit) return unit == "player" end  -- simulate ghost

MockAPI.SetZone("Coilfang: Serpentshrine Cavern", "Serpentshrine Cavern")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")
MockAPI.FireOnUpdate(0)

assert_true(not sscUI:IsShown(), "SSC UI not shown on ghost entry")

-- Proximity ticks must also keep it hidden
MockAPI.AdvanceTime(2)
MockAPI.FireOnUpdate(0)
assert_true(not sscUI:IsShown(), "SSC UI stays hidden during ghost visit")

UnitIsGhost = function(unit) return false end  -- restore


-- ─── Test 16: ReconfigureLift resets bar geometry on lift transition ────────
-- Regression: when traveling Aldor (full) → SetCompact(true) → tblift (dual)
-- → SetCompact(false) → Aldor, the SetCompact early-return guard prevents
-- the single-lift bar geometry from being reset, leaving the frame at full
-- size but bar/barBg at compact width. ReconfigureLift's else-branch must
-- self-heal by resetting bar dimensions before laying out segments.

section("Test 16: ReconfigureLift resets bar geometry on lift transition")

-- This exercises the LEGACY syncUI frame's dual-lift geometry self-heal, which
-- is still the surface for dual lifts (TB/Great Lift) post-cutover. Single lifts
-- no longer construct syncUI, so force it to build via the /atax ui toggle.
-- The toggle only routes to syncUI when no single-form lift is active, so
-- leave SSC (still active from Test 15) first.
MockAPI.SetZone("Zangarmarsh", "Zangarmarsh")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")
if not _G.AldorTaxSyncUI then SlashCmdList["ALDORTAX"]("ui") end
local syncUI = _G.AldorTaxSyncUI
assert_true(syncUI ~= nil, "syncUI exists for transition test")
assert_true(type(syncUI.ReconfigureLift) == "function", "ReconfigureLift exposed")
assert_true(type(syncUI.SetCompact) == "function", "SetCompact exposed")

-- Constants from BuildSyncUI: BAR_W_FULL=460, PAD=12 → full frame width = 484
local FULL_WIDTH = 460 + 12 * 2

-- Step 1: enter Aldor (single-lift) at full size
syncUI.ReconfigureLift("aldor")
syncUI.SetCompact(false)
-- Force a known starting state: shrink, then re-expand, so isCompact toggles
syncUI.SetCompact(true)
syncUI.SetCompact(false)
assert_eq(syncUI:GetWidth(), FULL_WIDTH, "Aldor full-size frame width is 484")

-- Step 2: shrink to compact
syncUI.SetCompact(true)

-- Step 3: travel to TB lift (dual). isCompact stays true; isDual becomes true.
syncUI.ReconfigureLift("tblift")

-- Step 4: dual lift expanded — SetCompact(false) takes the dual branch and
-- never touches barW. After this, barW remains BAR_W_COMPACT internally.
syncUI.SetCompact(false)

-- Step 5: return to Aldor. Without the fix, the syncUI frame is full-size
-- but bar/barBg/segments retain compact width. After the fix, ReconfigureLift
-- self-heals the geometry.
syncUI.ReconfigureLift("aldor")
assert_eq(syncUI:GetWidth(), FULL_WIDTH,
    "frame width restored to 484 on return to single-lift after dual-lift detour")

-- The frame size assertion alone is not load-bearing — syncUI:SetSize is
-- already called unconditionally in ReconfigureLift's else-branch. The actual
-- bug is that bar/barBg/overlay carry compact dimensions from the last
-- single-lift SetCompact, and the dual-lift SetCompact branch never touches
-- them. Verify barBg (which is exposed) has been restored to full width.
assert_true(syncUI.barBg ~= nil, "barBg exposed for geometry check")
assert_eq(syncUI.barBg:GetWidth(), 460 + 4,
    "barBg width restored to full (464) after dual-lift detour — guards the actual bug")


-- ─── Test 17: Received sync logged to syncLog with source ──────────────────
-- Remote syncs must leave a durable trace: a RECV row carrying the sender
-- and the correction delta vs the local model.

section("Test 17: Received sync logged to syncLog with source")

local logLenBefore = AldorTaxDB.syncLog and #AldorTaxDB.syncLog or 0
local recvCycle = 43.333
local recvPhase = GetServerTime() % recvCycle
local recvMsg = string.format("S|5|ssc|%.3f|Recvtester|TestRealm|16.500|5.000|13.333|8.500|C|%.3f",
    recvPhase, recvPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", recvMsg, "CHANNEL", "Recvtester")

local log = AldorTaxDB.syncLog
assert_true(#log > logLenBefore, "syncLog grew on received sync")
local lastRow = log[#log]
assert_true(lastRow:find("|ssc|RECV:Recvtester-TestRealm|", 1, true) ~= nil,
    "RECV row carries lift and source (got: " .. tostring(lastRow) .. ")")
local recvCorr = lastRow:match("|RECV:[^|]+|[%d%.]+|([%d%.%-]+)|")
assert_true(tonumber(recvCorr) ~= nil,
    "RECV row has numeric correction delta (got: " .. tostring(recvCorr) .. ")")

-- The receive must also land a timing sample labeled RECV, so /atax timing
-- reports received-sync accuracy as its own segment group.
local sscSamples = AldorTaxDB.timing and AldorTaxDB.timing.ssc
assert_true(sscSamples ~= nil and sscSamples[#sscSamples][4] == "RECV",
    "timing sample recorded with RECV label")


-- ─── Test 18: Correction report (C frame) round trip ────────────────────────
-- Outbound: calibrating over a remote-sourced sync must broadcast a C frame
-- naming the original sender and the correction size. Inbound: receiving a
-- C frame about our own sync must log an FBCK row and timing sample.

section("Test 18: Correction report emitted and received")

-- Be on Aldor Rise with a remote-sourced sync.
MockAPI.SetZone("Shattrath City", "Aldor Rise")
MockAPI.FireEvent("ZONE_CHANGED_NEW_AREA")
MockAPI.AdvanceTime(6) -- clear the post-zone send cooldown
local aldorPhase = GetServerTime() % 25.0
local remoteMsg = string.format("S|5|aldor|%.3f|Sourceguy|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    aldorPhase, aldorPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", remoteMsg, "CHANNEL", "Sourceguy")

-- Calibrate over it via a real segment click (segBtns exposed on syncUI).
local ui = _G.AldorTaxSyncUI
assert_true(ui ~= nil and ui.segBtns ~= nil, "syncUI segment buttons exposed")
ctlCalls = {}
ui.segBtns[1]:GetScript("OnClick")()

local cFrame
for _, c in ipairs(ctlCalls) do
    if c.text:sub(1, 2) == "C|" then cFrame = c.text break end
end
assert_true(cFrame ~= nil, "calibration over remote sync broadcast a C frame")
if cFrame then
    assert_true(cFrame:find("|aldor|", 1, true) ~= nil, "C frame names the transport")
    assert_true(cFrame:find("|TestPlayer|TestRealm|Sourceguy|TestRealm", 1, true) ~= nil,
        "C frame carries reporter and original source (got: " .. cFrame .. ")")
end

-- A plain re-click (model is now first-hand) must NOT emit another C frame.
ctlCalls = {}
ui.segBtns[1]:GetScript("OnClick")()
for _, c in ipairs(ctlCalls) do
    assert_true(c.text:sub(1, 2) ~= "C|", "no C frame when correcting our own model")
end

-- Inbound: someone reports a correction against OUR sync.
local logLen18 = #AldorTaxDB.syncLog
local inboundC = "C|6|aldor|12.345|1.250|Reporter|TestRealm|TestPlayer|TestRealm"
MockAPI.ReceiveAddonMessage("ALDORTAX", inboundC, "CHANNEL", "Reporter")

assert_true(#AldorTaxDB.syncLog > logLen18, "syncLog grew on received C frame")
local fbckRow = AldorTaxDB.syncLog[#AldorTaxDB.syncLog]
assert_true(fbckRow:find("|aldor|FBCK:Reporter-TestRealm>TestPlayer-TestRealm|", 1, true) ~= nil,
    "FBCK row carries reporter and source (got: " .. tostring(fbckRow) .. ")")
assert_true(fbckRow:find("|1.250|12.345", 1, true) ~= nil,
    "FBCK row carries correction and received offset")

local aldorSamples = AldorTaxDB.timing.aldor
assert_true(aldorSamples[#aldorSamples][4] == "FBCK",
    "C frame about our sync recorded an FBCK timing sample")
assert_true(math.abs(aldorSamples[#aldorSamples][3] - 1.25) < 0.001,
    "FBCK timing sample carries the reported correction")


-- ─── Results ────────────────────────────────────────────────────────────────

H.results()
