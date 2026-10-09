-- Run the complete single-file HTTP artifact, without a prior library load.
local checks = 0
local function check(value, message)
    assert(value, message)
    checks += 1
end
local function advance(count)
    for _ = 1, count or 30 do
        Runtime.time += 1 / 60
        Runtime.render:Fire(1 / 60)
    end
end
local function click(handle, offset)
    local b = assert(handle.bounds, "control has no rendered bounds")
    Runtime.mouse.X, Runtime.mouse.Y = b.x + (offset or b.w / 2), b.y + 20
    Runtime.keys[1] = false; advance(1)
    Runtime.keys[1] = true; advance(1)
    Runtime.keys[1] = false; advance(1)
end

check(_G.ThalassarUI == nil, "standalone demo begins without an installed library")
runStandaloneDemo()
local first = assert(_G.ThalassarDemo)
local state = assert(_G.ThalassarDemoState)
advance()
check(first:Status().alive and first:Status().visible and not first:Status().error,
    "single-file demo loads and renders automatically")
check(first:Status().section == "Controls" and first:GetValue("amount") == 50 and first:GetValue("style") == 0,
    "demo opens its initialized controls")
check(Runtime.visibleText("Thalassar UI · Demo") ~= nil and Runtime.visibleCount() > 0,
    "standalone title and interface render")

click(state.Controls.enabled)
check(first:GetValue("enabled") == false and state.lastAction == "Preview paused" and state.callbackCount == 1,
    "rendered demo toggle fires its feedback callback")
local before = state.callbackCount
click(state.Controls.amount)
check(first:GetValue("amount") == 50 and state.callbackCount == before,
    "paused preview disables its slider")
click(state.Controls.enabled)
local slider = state.Controls.amount.bounds
Runtime.mouse.X, Runtime.mouse.Y = slider.x + 14 + (slider.w - 28) * .8, slider.y + 40
Runtime.keys[1] = false; advance(1)
Runtime.keys[1] = true; advance(1)
Runtime.keys[1] = false; advance(1)
check(first:GetValue("amount") == 80 and state.lastAction == "Amount set to 80",
    "rendered slider changes the live preview")

check(first:SelectSection("Profiles"), "demo profile section is reachable")
advance()
click(state.Controls.export)
first:SetValue("amount", 12)
click(state.Controls.restore)
check(first:GetValue("amount") == 80 and state.lastAction == "Settings restored",
    "demo snapshot buttons preserve and restore actual controls")
click(state.Controls.reset)
check(first:GetValue("amount") == 50 and first:GetValue("enabled") == true,
    "demo restores its original snapshot")

first:SelectSection("Navigation"); advance()
click(state.Controls.background); advance()
check(first:Status().section == "Background", "demo button opens built-in background settings")
first:SelectSection("Controls"); advance()
local page = first:ScrollRegions().page
check(page.max > 0, "demo includes overflowing content")
check(first:Scroll(-3, page.x + page.w / 2, page.y + page.h / 2), "demo routes scroll input to its content")
advance()
check(first:ScrollRegions().page.current > 0, "demo scroll moves the rendered page")

first:Hide(); advance()
Runtime.keys[0x4B] = true; advance(1)
Runtime.keys[0x4B] = false; advance(1)
check(first:GetValue("shortcut") == true and state.lastAction:find("Shortcut on", 1, true),
    "demo shortcut runs while the window is hidden")

-- Re-executing the exact artifact replaces its prior window and bindings.
runStandaloneDemo()
local second = assert(_G.ThalassarDemo)
advance()
check(second ~= first and not first:Status().alive and state.closed,
    "running the standalone demo twice cleans up its previous window")
check(Runtime.connectedCount() == 1 and second:Status().alive and not second:Status().error,
    "rerun leaves only one active render connection")
second:Destroy()
check(_G.ThalassarDemo == nil and _G.ThalassarDemoState.closed,
    "demo cleanup clears its current public window handle")
check(Runtime.removed == Runtime.made and Runtime.connectedCount() == 0,
    "standalone demo releases every drawing and connection")
print("THALASSAR STANDALONE DEMO TOTAL", checks)
