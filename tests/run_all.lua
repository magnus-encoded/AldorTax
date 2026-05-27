-- Run all test suites as subprocesses. Exit 1 if any fail.
-- Usage: lua tests/run_all.lua   (from addon root)

local suites = {
    "tests/test_features.lua",
    "tests/test_sync.lua",
    "tests/test_timing.lua",
    "tests/test_rebroadcast_bug.lua",
}

local failed = false
for _, f in ipairs(suites) do
    local code = os.execute("lua " .. f)
    -- Lua 5.1 returns numeric exit, 5.2+ returns true/false + "exit" + code
    local ok = (code == 0) or (code == true)
    if not ok then failed = true end
end

os.exit(failed and 1 or 0)
