-- Integration test: sync pipeline end-to-end
-- Run with: lua tests/test_sync.lua (from the addon root)
--
-- Exercises the full path:
--   calibration click → BroadcastSync → network → HandleAddonMessage → ApplyRemoteSync
-- Verifies that the receiver's computed phase matches the sender's within tolerance.

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")

-- ─── Test harness ───────────────────────────────────────────────────────────

local passed, failed, errors = 0, 0, {}

local function assert_near(actual, expected, tolerance, label)
    local diff = math.abs(actual - expected)
    if diff <= tolerance then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("FAIL: %s — expected %.4f ±%.4f, got %.4f (off by %.4f)",
            label, expected, tolerance, actual, diff)
        table.insert(errors, msg)
        print(msg)
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("FAIL: %s — expected true, got %s", label, tostring(value))
        table.insert(errors, msg)
        print(msg)
    end
end

local function section(name)
    print(string.format("\n-- %s --", name))
end

-- ─── Load the addon ─────────────────────────────────────────────────────────

-- Set clock: server time = 1775168000, GetTime() = 10000.0
MockAPI.SetClock(1775168000, 10000.0, 1775168000)
MockAPI.SetZone("Shattrath City", "Aldor Rise")

dofile("AldorTax.lua")

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

-- Construct the sync message as BroadcastSync would for a FALL click at "now"
-- We need to trigger the slash command or directly invoke the event path.
-- Since we can't call locals, we'll build the v5 message manually.
local cycleTime = 25.0 -- aldor cycle
-- Sender clicked FALL (phase 0) at this instant, so the cycle started now.
-- srvPhase = absoluteTime % cycleTime at the click moment
local srvPhase = GetServerTime() % cycleTime

local syncMsg = string.format("S|5|aldor|%.3f|SenderPlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    srvPhase, srvPhase) -- phase and srvPhase are the same when sent at the click moment

MockAPI.ReceiveAddonMessage("ALDORTAX", syncMsg, "CHANNEL", "SenderPlayer")

-- Check: AldorTaxDB should now have a sync for aldor
assert_true(AldorTaxDB.lifts.aldor ~= nil, "aldor sync saved")
assert_true(AldorTaxDB.lifts.aldor.lastSyncRealTime ~= nil, "aldor lastSyncRealTime saved")

-- Verify the stored sync implies the cycle just started (phase ≈ 0)
local expectedRealTime = GetTime() + (time() - GetTime()) -- GetRealTime()
local syncDrift = math.abs(AldorTaxDB.lifts.aldor.lastSyncRealTime - expectedRealTime)
assert_near(syncDrift, 0, 0.1, "self-sync drift should be ~0")


-- ─── Test 2: Sync with network latency ──────────────────────────────────────
-- Sender clicks at T=0. Message arrives 200ms later. With latency compensation,
-- the receiver should still compute phase ≈ 0.2 (200ms of progress since click).

section("Test 2: Sync with 200ms world latency")

MockAPI.SetLatency(50, 200)

-- Sender clicked FALL at current server time
local sendTime = GetServerTime()
local sendSrvPhase = sendTime % cycleTime

local delayedMsg = string.format("S|5|aldor|%.3f|DelayedSender|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    sendSrvPhase, sendSrvPhase)

-- Advance time by 200ms to simulate network transit
MockAPI.AdvanceTime(0)      -- server time only ticks in integers
_G._testGameTimeAdd = 0.200 -- we need sub-second advance
-- Manually advance just GetTime
local savedGetTime = GetTime
local addedDelay = 0.200
GetTime = function() return savedGetTime() + addedDelay end

MockAPI.ReceiveAddonMessage("ALDORTAX", delayedMsg, "CHANNEL", "DelayedSender")

-- The receiver calls GetAbsoluteTime() - netDelay, where netDelay = 200/1000 = 0.2
-- So it effectively computes as if the message arrived 200ms ago, which is when it was sent.
-- elapsedInCycle should be ~0 (the 200ms transit is compensated by the 200ms latency subtraction)
-- But there's 200ms of real elapsed time, so without compensation phase would be 0.2
-- With compensation it should be ≈ 0.0

-- Check stored sync: lastSyncRealTime should be close to the SEND time (not receive time)
local receiverRealTime = AldorTaxDB.lifts.aldor.lastSyncRealTime
-- The send-time real time would be expectedRealTime (before our 200ms advance)
-- With latency compensation, the stored time should reflect the sender's moment
-- Drift from the sender's actual cycle start:
local senderCycleStart = expectedRealTime -- the real time when sender clicked
local compensatedDrift = math.abs(receiverRealTime - senderCycleStart)
assert_near(compensatedDrift, 0, 0.25, "latency-compensated drift should be small")

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

local wrapMsg = string.format("S|5|aldor|%.3f|WrapSender|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    wrapSrvPhase, wrapSrvPhase)

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
local goodMsg = string.format("S|5|aldor|%.3f|BadPlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    badPhase, badPhase)
MockAPI.ReceiveAddonMessage("ALDORTAX", goodMsg, "CHANNEL", "BadPlayer")

-- Send 3 death reports (SOFT_BLOCK_THRESHOLD = 3)
for _ = 1, 3 do
    local deathMsg = string.format("D|5|aldor|%.3f|BadPlayer|TestRealm|C", badPhase)
    MockAPI.ReceiveAddonMessage("ALDORTAX", deathMsg, "CHANNEL", "BadPlayer")
end

-- Record the state after death reports invalidated the sync
local postDeathRT = AldorTaxDB.lifts.aldor.lastSyncRealTime

-- Now try another sync from BadPlayer — should be ignored (soft-blocked)
local badMsg2 = string.format("S|5|aldor|%.3f|BadPlayer|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    badPhase + 5.0, badPhase + 5.0)
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

local clickMsg = string.format("S|5|aldor|%.3f|ClickSender|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    clickSrvPhase, clickSrvPhase)

MockAPI.ReceiveAddonMessage("ALDORTAX", clickMsg, "CHANNEL", "ClickSender")

-- The receiver should see phase ≈ 0.2 (the 0.2s reaction time means the click
-- happened 0.2s AFTER the true phase transition, so the cycle is 0.2s ahead)
-- NOT phase ≈ 0.4 (which would mean double-counting)
local clickRT = AldorTaxDB.lifts.aldor.lastSyncRealTime
local clickElapsed = (GetTime() + (time() - GetTime())) - clickRT
local clickPhase = clickElapsed % cycleTime
assert_near(clickPhase, 0.2, 0.15, "CLICK_REACTION_TIME should appear once, not twice")


-- ─── Results ────────────────────────────────────────────────────────────────

print(string.format("\n-- Results: %d passed, %d failed --", passed, failed))
if #errors > 0 then
    print("\nFailures:")
    for _, e in ipairs(errors) do print("  " .. e) end
end
os.exit(failed > 0 and 1 or 0)
