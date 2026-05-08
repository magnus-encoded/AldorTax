-- Regression: BroadcastSync's srvPhase must reflect the original cycle-start,
-- not the current absolute time, even when called without a realTime argument.
--
-- Bug history: line 888-889 used `realTime and (...)  or GetAbsoluteTime()`.
-- When `realTime` was nil (auto-rebroadcast every 45s, zone-out, /atax sync),
-- srvPhase fell through to GetAbsoluteTime() % cycle = "now mod cycle". A
-- receiver of that message computed elapsedInCycle ≈ 0 — i.e. the cycle had
-- "just started" — even when the sender's actual cycle was mid-flight.
--
-- The fix derives absRT from `rt` (which holds either the explicit realTime,
-- the saved lastSyncRealTime, or GetRealTime() as a final fallback), so all
-- three paths produce a srvPhase tied to the original cycle-start.

package.path = package.path .. ";tests/?.lua"
local MockAPI = require("wow_api_mock")
local H       = require("test_harness")
local section, assert_near, assert_true = H.section, H.assert_near, H.assert_true

MockAPI.SetClock(1775168000, 10000.0, 1775168000)
MockAPI.SetZone("Shattrath City", "Aldor Rise")
dofile("AldorTax.lua")
MockAPI.InitAddon()

-- Wire up an outgoing-message capture (the addon prefers ChatThrottleLib if
-- present; we are not loading CTL, so SendAddonMessage is the path).
local sentMessages = {}
local origSend = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function(prefix, msg, chatType, target)
    table.insert(sentMessages, msg)
    return origSend(prefix, msg, chatType, target)
end

local cycleTime = 25.0  -- aldor

-- Establish activeLiftID by firing zone events (the addon sets it during
-- proximity detection on zone change).
MockAPI.FireEvent("ZONE_CHANGED")
MockAPI.FireOnUpdate(0.016)

section("Step 1: receive a clean v5 sync claiming cycle started 5s ago")
-- The sender's cycle started 5s ago in absolute server time.
local trueCycleStartAbs = GetServerTime() - 5
local cleanSrvPhase     = trueCycleStartAbs % cycleTime
local cleanMsg = string.format(
    "S|5|aldor|%.3f|FreshSender|TestRealm|6.500|4.700|7.800|6.000|C|%.3f",
    cleanSrvPhase, cleanSrvPhase)
MockAPI.SetLatency(0, 0)
MockAPI.ReceiveAddonMessage("ALDORTAX", cleanMsg, "CHANNEL", "FreshSender")

-- Sanity: receiver should now think we're 5s into the cycle.
local stReceive = AldorTaxDB.lifts.aldor
assert_true(stReceive ~= nil and stReceive.lastSyncRealTime ~= nil,
    "fresh sync stored")

section("Step 2: advance 30s and trigger an auto-rebroadcast via /atax sync")
sentMessages = {}
-- Advance GetTime by 30s (server time and wall time also advance) so the
-- cycle is now (5+30)%25 = 10s into a fresh cycle.
MockAPI.AdvanceTime(30)

-- /atax sync calls BroadcastSync(activeLiftID) — the buggy/relay path.
SlashCmdList["ALDORTAX"]("sync")
assert_true(#sentMessages > 0, "rebroadcast sent at least one message")

-- Find the S| message (we may also get other prefixes if anything else fires).
local syncOut
for _, m in ipairs(sentMessages) do
    if m:sub(1, 2) == "S|" then syncOut = m; break end
end
assert_true(syncOut ~= nil, "rebroadcast included an S| sync message")

-- Parse the outgoing message: S|ver|liftID|phase|name|realm|fall|bot|rise|top|origin|srvPhase
local parts = {}
for p in syncOut:gmatch("[^|]+") do parts[#parts + 1] = p end
local outSrvPhase = tonumber(parts[12])

-- After the fix, outSrvPhase should be the cycle-start time mod cycle, not
-- the current absolute time mod cycle. The cycle-start is unchanged at
-- trueCycleStartAbs.
local expectedSrvPhase = trueCycleStartAbs % cycleTime
local buggyWouldBe     = GetServerTime() % cycleTime  -- what GetAbsoluteTime() % cycle yields now

print(string.format("  expected srvPhase (cycle-start) = %.3f", expectedSrvPhase))
print(string.format("  pre-fix would emit (now)        = %.3f", buggyWouldBe))
print(string.format("  actual emitted srvPhase         = %.3f", outSrvPhase))

assert_near(outSrvPhase, expectedSrvPhase, 0.05,
    "rebroadcast srvPhase matches original cycle-start, not now")

section("Step 3: a third client receiving the rebroadcast computes correct phase")
-- Pretend a fresh receiver applies our buggy rebroadcast. We simulate by
-- re-feeding the message into the addon and looking at the resulting
-- elapsedInCycle. Reset state first by clearing the stored sync.
AldorTaxDB.lifts.aldor.lastSyncRealTime = nil
AldorTaxDB.lifts.aldor.lastSyncSource   = nil

MockAPI.ReceiveAddonMessage("ALDORTAX", syncOut, "CHANNEL", "OurselvesActingAsThirdParty")

-- The third client should now think the cycle is 10s in (5s original + 30s passed).
local thirdStored   = AldorTaxDB.lifts.aldor.lastSyncRealTime
local realNow       = GetTime() + (time() - GetTime())
local thirdElapsed  = (realNow - thirdStored) % cycleTime

print(string.format("  third client's elapsedInCycle = %.3f (true: 10.000)", thirdElapsed))
assert_near(thirdElapsed, 10.0, 0.1,
    "third client computes correct elapsedInCycle from rebroadcast")

H.results()
