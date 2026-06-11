-- Integration test: sync pipeline end-to-end
-- Run with: lua tests/test_sync.lua (from the addon root)
--
-- Exercises the full path:
--   calibration click → BroadcastSync → network → HandleAddonMessage → ApplyRemoteSync
-- Verifies that the receiver's computed phase matches the sender's within tolerance.

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H = require("test_harness")
local assert_near, assert_true, section = H.assert_near, H.assert_true, H.section

-- ─── Load the addon ─────────────────────────────────────────────────────────

-- Set clock: server time = 1775168000, GetTime() = 10000.0
MockAPI.SetClock(1775168000, 10000.0, 1775168000)
MockAPI.SetZone("Shattrath City", "Aldor Rise")

local NS = H.LoadAddon()
local Wire = NS.Wire

-- ─── Initialize ─────────────────────────────────────────────────────────────

MockAPI.InitAddon()

-- After calibration, serverTimeOffset = serverTime - GetTime()
-- With our mock: 1775168001 - 10000.016 = 1775157000.984
-- realTimeOffset = time() - GetTime() = 1775168001 - 10000.016 = 1775157000.984

section("Calibration")
assert_true(AldorTaxDB ~= nil, "AldorTaxDB initialized")
assert_true(AldorTaxDB.lifts ~= nil, "AldorTaxDB.lifts initialized")

-- ─── Test 1: Self-sync round-trip ───────────────────────────────────────────
-- Simulate: player clicks FALL (phase 0) exactly when the lift starts falling.
-- Then receive our own message back. The result should match precisely.

section("Test 1: Self-sync round-trip (zero latency)")

MockAPI.ClearSentMessages()
MockAPI.SetLatency(0, 0)

-- Build the message through the real codec, exactly as BroadcastSync would for
-- a FALL click at "now", then feed it through the receive path.
local cycleTime = 25.0 -- aldor cycle
-- Sender clicked FALL (phase 0) at this instant, so the cycle started now.
-- srvPhase = absoluteTime % cycleTime at the click moment
local srvPhase = GetServerTime() % cycleTime

-- phase and srvPhase are the same when sent at the click moment
local syncMsg = Wire.EncodeSync("aldor", srvPhase, "SenderPlayer", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", srvPhase)

MockAPI.ReceiveAddonMessage("ALDORTAX", syncMsg, "CHANNEL", "SenderPlayer")

-- Check: AldorTaxDB should now have a sync for aldor
assert_true(AldorTaxDB.lifts.aldor ~= nil, "aldor sync saved")
assert_true(AldorTaxDB.lifts.aldor.lastSyncRealTime ~= nil, "aldor lastSyncRealTime saved")

-- Verify the stored sync implies the cycle just started (phase ≈ 0)
local expectedRealTime = GetTime() + (time() - GetTime()) -- GetRealTime()
local syncDrift = math.abs(AldorTaxDB.lifts.aldor.lastSyncRealTime - expectedRealTime)
assert_near(syncDrift, 0, 0.1, "self-sync drift should be ~0")


-- ─── Test 2: Sync with network latency ──────────────────────────────────────
-- Sender clicks at T=0. Message arrives 200ms later. Because v5 syncs are
-- anchored to absolute server time, transit delay must not shift the model.

section("Test 2: Sync with 200ms world latency")

MockAPI.SetLatency(50, 200)

-- Sender clicked FALL at current server time
local sendTime = GetServerTime()
local sendSrvPhase = sendTime % cycleTime

local delayedMsg = Wire.EncodeSync("aldor", sendSrvPhase, "DelayedSender", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", sendSrvPhase)

-- Advance time by 200ms to simulate network transit
MockAPI.AdvanceTime(0)      -- server time only ticks in integers
_G._testGameTimeAdd = 0.200 -- we need sub-second advance
-- Manually advance just GetTime
local savedGetTime = GetTime
local addedDelay = 0.200
GetTime = function() return savedGetTime() + addedDelay end

MockAPI.ReceiveAddonMessage("ALDORTAX", delayedMsg, "CHANNEL", "DelayedSender")

-- srvPhase is anchored to absolute server time, which is delivery-delay-
-- invariant: 200ms after sending, elapsedInCycle is genuinely 0.2, and
-- lastSyncRealTime still resolves to the sender's cycle start. Applying
-- latency compensation on this path would lag the model by ~netDelay.

-- Check stored sync: lastSyncRealTime should be the SEND time (not receive time)
local receiverRealTime = AldorTaxDB.lifts.aldor.lastSyncRealTime
local senderCycleStart = expectedRealTime -- the real time when sender clicked
local transitDrift = math.abs(receiverRealTime - senderCycleStart)
assert_near(transitDrift, 0, 0.1, "absolute-anchored sync unaffected by 200ms transit")

-- Restore GetTime
GetTime = savedGetTime


-- ─── Test 3: v4 fallback (no srvPhase) ─────────────────────────────────────
-- Older clients send phase computed from local time() which has ~1s precision.
-- Verify the fallback path works and the error is bounded.

section("Test 3: v4 message (no srvPhase, uses realTimeOffset path)")

MockAPI.SetLatency(0, 0)

local v4Phase = (time() % cycleTime) -- how a v4 sender would compute phase
local v4Msg = string.format("S|4|aldor|%.3f|OldClient|TestRealm|6.500|4.700|7.800|6.000",
    v4Phase)

MockAPI.ReceiveAddonMessage("ALDORTAX", v4Msg, "CHANNEL", "OldClient")

assert_true(AldorTaxDB.lifts.aldor ~= nil, "v4 sync saved")
-- v4 path uses GetRealTime() and phase from time() — both use realTimeOffset
-- so they should be consistent with each other, even if imprecise vs server time.
-- The drift should be < 1s (realTimeOffset precision)
local v4RealTime = AldorTaxDB.lifts.aldor.lastSyncRealTime
local v4Diff = math.abs(v4RealTime - expectedRealTime)
assert_near(v4Diff % cycleTime, 0, 1.5, "v4 sync should be within ~1s (realTimeOffset precision)")


-- ─── Test 4: Phase wrap near cycle boundary ─────────────────────────────────
-- If the sender's srvPhase is 24.9 and by the time the receiver processes it
-- 0.2s has elapsed, nowAbs % cycle would wrap to ~0.1. The modular arithmetic
-- should still produce elapsedInCycle ≈ 0.2, not ≈ 24.8.

section("Test 4: Phase wrap at cycle boundary")

MockAPI.SetLatency(0, 0)

-- We can't do sub-second server time advances easily, so construct srvPhase directly
local wrapSrvPhase = 24.900

local wrapMsg = Wire.EncodeSync("aldor", wrapSrvPhase, "WrapSender", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", wrapSrvPhase)

-- Receive it at a time where nowAbs % 25 ≈ 0.1 (just past the boundary)
-- We need GetAbsoluteTime() % 25 ≈ 0.1
-- GetAbsoluteTime = GetTime() + serverTimeOffset
-- serverTimeOffset was set during calibration = 1775168001 - 10000.016 = 1775157000.984
-- So GetAbsoluteTime() = GetTime() + 1775157000.984
-- We need (GetTime() + 1775157000.984) % 25 ≈ 0.1
-- Current: GetTime() ≈ 10000.016, so abs ≈ 1775168001.0, mod 25 ≈ 1.0
-- Advance GetTime by (25 - 1.0 + 0.1) = 24.1 to get mod ≈ 0.1
savedGetTime = GetTime
local wrapAdvance = 24.1
GetTime = function() return savedGetTime() + wrapAdvance end

MockAPI.ReceiveAddonMessage("ALDORTAX", wrapMsg, "CHANNEL", "WrapSender")

-- elapsedInCycle = (0.1 - 24.9 + 25) % 25 = 0.2
-- So the receiver thinks 0.2s has elapsed since the sender's click — correct!
-- lastSync = GetTime() - 0.2
-- Phase at receiver = (GetTime() - lastSync) % 25 = 0.2
local wrapRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
assert_true(wrapRT ~= nil, "wrap sync saved")

-- The stored sync should place us 0.2s into the cycle
-- GetRealTime() - lastSyncRealTime should ≈ 0.2
local wrapElapsed = (savedGetTime() + wrapAdvance + (time() - savedGetTime())) - wrapRT
local wrapPhase = wrapElapsed % cycleTime
assert_near(wrapPhase, 0.2, 0.15, "phase wrap should compute ~0.2s elapsed, not ~24.8")

GetTime = savedGetTime


-- ─── Test 5: Death report invalidation ──────────────────────────────────────
-- Receive enough death reports from a source to trigger soft-block,
-- then verify their syncs are rejected.

section("Test 5: Death report soft-blocking")

MockAPI.SetLatency(0, 0)

-- First, accept a sync from "BadPlayer"
local badPhase = GetServerTime() % cycleTime
local goodMsg = Wire.EncodeSync("aldor", badPhase, "BadPlayer", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", badPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", goodMsg, "CHANNEL", "BadPlayer")

-- Send 3 death reports (SOFT_BLOCK_THRESHOLD = 3)
for _ = 1, 3 do
    local deathMsg = Wire.EncodeDeath("aldor", badPhase, "BadPlayer", "TestRealm", "C")
    MockAPI.ReceiveAddonMessage("ALDORTAX", deathMsg, "CHANNEL", "BadPlayer")
end

-- Record the state after death reports invalidated the sync
local postDeathRT = AldorTaxDB.lifts.aldor.lastSyncRealTime

-- Now try another sync from BadPlayer — should be ignored (soft-blocked)
local badMsg2 = Wire.EncodeSync("aldor", badPhase + 5.0, "BadPlayer", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", badPhase + 5.0)
MockAPI.ReceiveAddonMessage("ALDORTAX", badMsg2, "CHANNEL", "BadPlayer")

-- The sync should NOT have updated — lastSyncRealTime should be unchanged
local postBlockRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
assert_true(postBlockRT == postDeathRT,
    "blocked player's second sync should be rejected (DB unchanged)")


-- ─── Test 6: Verify CLICK_REACTION_TIME is not double-counted ──────────────
-- The 0.2s reaction time is subtracted at click time on the sender side.
-- Verify it doesn't appear again on the receiver side.

section("Test 6: CLICK_REACTION_TIME not double-counted")

MockAPI.SetLatency(0, 0)
MockAPI.ClearSentMessages()

-- Simulate what happens at a click: sender computes
--   rt = GetRealTime() - 0.2 - phaseStart
-- For FALL (phaseStart=0): rt = GetRealTime() - 0.2
-- Then BroadcastSync computes srvPhase = absRT % cycle
-- where absRT = rt - realTimeOffset + serverTimeOffset
-- The 0.2 is baked into srvPhase — it shifts the cycle start 0.2s earlier

-- Replicate GetRealTime() - 0.2: in the mock, realTimeOffset = time() - GetTime()
local realTimeOff = time() - GetTime()
local clickRealTime = GetTime() + realTimeOff - 0.2
-- Replicate BroadcastSync's conversion: absRT = rt - realTimeOffset + serverTimeOffset
local serverTimeOff = GetServerTime() - GetTime()
local clickAbsRT = clickRealTime - realTimeOff + serverTimeOff
local clickSrvPhase = clickAbsRT % cycleTime

local clickMsg = Wire.EncodeSync("aldor", clickSrvPhase, "ClickSender", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", clickSrvPhase)

MockAPI.ReceiveAddonMessage("ALDORTAX", clickMsg, "CHANNEL", "ClickSender")

-- The receiver should see phase ≈ 0.2 (the 0.2s reaction time means the click
-- happened 0.2s AFTER the true phase transition, so the cycle is 0.2s ahead)
-- NOT phase ≈ 0.4 (which would mean double-counting)
local clickRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
local clickElapsed = (GetTime() + (time() - GetTime())) - clickRT
local clickPhase = clickElapsed % cycleTime
assert_near(clickPhase, 0.2, 0.15, "CLICK_REACTION_TIME should appear once, not twice")


-- ─── Test 7: Receive guard accepts v3/v5/v6, rejects v7 ─────────────────────
-- v0.9.1 bumped MSG_VERSION 5 → 6 with no wire-format change. The receive
-- guard must accept all known versions (v3..v6 share the parse path) and
-- reject anything outside that set.

section("Test 7: Receive guard known-version coverage")

MockAPI.SetLatency(0, 0)

-- Clear any prior soft-block state by switching to a fresh sender realm
-- (BadPlayer-TestRealm is soft-blocked from Test 5).

-- Acceptance signal: lastSyncSource.name is updated on every accepted sync.
-- Using the stored sender name avoids false-negatives when two consecutive
-- messages compute identical lastSyncRealTime (same phase + clock).

-- v3 message — implicit aldor, no liftID, no origin, no srvPhase. Hand-built:
-- Wire.EncodeSync only emits the current version, so legacy formats are
-- constructed directly to exercise the parser's backward-compat path.
local v3Phase = GetServerTime() % cycleTime
local v3Msg = string.format("S|3|%.3f|V3Sender|TestRealm|6.500|4.700|7.800|6.000", v3Phase)

MockAPI.ReceiveAddonMessage("ALDORTAX", v3Msg, "CHANNEL", "V3Sender")
assert_true(AldorTaxDB.lifts.aldor.lastSyncSource
    and AldorTaxDB.lifts.aldor.lastSyncSource.name == "V3Sender",
    "v3 sync accepted")

-- v6 message — the current version emitted by the codec.
local v6Phase = GetServerTime() % cycleTime
local v6Msg = Wire.EncodeSync("aldor", v6Phase, "V6Sender", "TestRealm",
    6.5, 4.7, 7.8, 6.0, "C", v6Phase)

MockAPI.ReceiveAddonMessage("ALDORTAX", v6Msg, "CHANNEL", "V6Sender")
assert_true(AldorTaxDB.lifts.aldor.lastSyncSource
    and AldorTaxDB.lifts.aldor.lastSyncSource.name == "V6Sender",
    "v6 sync accepted")

-- v7 message — must be rejected by the receive guard. Hand-built (above the
-- codec's version). After this call lastSyncSource.name should still be
-- "V6Sender" from the previous accept.
local v7Phase = GetServerTime() % cycleTime
local v7Msg = string.format("S|7|aldor|%.3f|V7Sender|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    v7Phase, v7Phase)

MockAPI.ReceiveAddonMessage("ALDORTAX", v7Msg, "CHANNEL", "V7Sender")
assert_true(AldorTaxDB.lifts.aldor.lastSyncSource
    and AldorTaxDB.lifts.aldor.lastSyncSource.name == "V6Sender",
    "v7 sync rejected (lastSyncSource unchanged from prior v6 accept)")


-- ─── Results ────────────────────────────────────────────────────────────────

H.results()
