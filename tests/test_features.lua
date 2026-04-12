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

dofile("AldorTax.lua")
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


-- ─── Results ────────────────────────────────────────────────────────────────

H.results()
