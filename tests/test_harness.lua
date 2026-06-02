-- Shared test harness for AldorTax test suites

local H = {}

local passed, failed, errors = 0, 0, {}

function H.assert_near(actual, expected, tolerance, label)
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

function H.assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("FAIL: %s — expected true, got %s", label, tostring(value))
        table.insert(errors, msg)
        print(msg)
    end
end

function H.assert_false(value, label)
    if not value then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("FAIL: %s — expected false/nil, got %s", label, tostring(value))
        table.insert(errors, msg)
        print(msg)
    end
end

function H.assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        local msg = string.format("FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual))
        table.insert(errors, msg)
        print(msg)
    end
end

function H.section(name)
    print(string.format("\n-- %s --", name))
end

-- Load the addon's Lua files in TOC order, sharing one namespace table —
-- mirrors how WoW passes (addonName, NS) varargs to each file. Returns NS so
-- tests can reach NS.Wire, NS.SyncBus, etc. Run from the addon root.
function H.LoadAddon()
    local NS = {}
    local files = {
        "Wire.lua", "SyncBus.lua", "TransportCycle.lua",
        "WidgetRouter.lua", "AldorTax.lua",
        "LiftBar.lua", "LightCountdown.lua", "TramUI.lua",
        "DualLiftBar.lua",
    }
    for _, file in ipairs(files) do
        assert(loadfile(file))("AldorTax", NS)
    end
    return NS
end

function H.results()
    print(string.format("\n-- Results: %d passed, %d failed --", passed, failed))
    if #errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(errors) do print("  " .. e) end
    end
    os.exit(failed > 0 and 1 or 0)
end

return H
