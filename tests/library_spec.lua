-- Public library tests. No integrated application or gameplay source is used.
local checks = 0
local function check(value, message)
    assert(value, message)
    checks += 1
end
local function near(a, b, epsilon)
    return type(a) == "number" and math.abs(a - b) <= (epsilon or .001)
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = clone(child) end
    return copy
end
local function options(extra)
    local values = {
        Title = "Public library fixture", ManualUpdate = true, InputAdapter = "none",
        Mouse = Runtime.mouse, Viewport = function() return 1920, 1080 end,
        IsKeyPressed = iskeypressed, IsMousePressed = ismouse1pressed,
        Focused = function() return Runtime.focused end,
        Typing = function() return Runtime.typing end,
    }
    for key, value in pairs(extra or {}) do values[key] = value end
    return values
end
local function frame(window) Runtime.time += 1 / 60; window:Step(1 / 60) end
local function settle(window, count)
    for _ = 1, count or 28 do frame(window) end
end
local function click(window, x, y)
    Runtime.mouse.X, Runtime.mouse.Y = x, y
    Runtime.keys[1] = false; frame(window)
    Runtime.keys[1] = true; frame(window)
    Runtime.keys[1] = false; frame(window)
end
local function center(row)
    local bounds = row.bounds
    assert(bounds, "expected a rendered control")
    return bounds.x + bounds.w / 2, bounds.y + bounds.h / 2
end
local function textContains(value)
    for _, record in ipairs(Runtime.drawings) do
        local p = record.properties
        if not record.dead and record.kind == "Text" and p.Visible
            and tostring(p.Text):lower():find(value:lower(), 1, true) then return p end
    end
    return nil
end

check(type(Library) == "table" and type(Library.CreateWindow) == "function", "library returns its public API")
check(_G.ThalassarUI == Library, "Matcha global export matches the return value")
local callbacks, colorCallback, wheelCalls, wheelPacket, errorCalls = 0, nil, 0, nil, 0
local window = Library:CreateWindow(options({
    OnError = function(message) check(type(message) == "string", "OnError receives a message"); errorCalls += 1 end,
    ConsumeWheel = function()
        wheelCalls += 1
        local packet = wheelPacket; wheelPacket = nil
        if packet then return packet[1], packet[2], packet[3] end
        return 0
    end,
}))
local tab = window:Tab("General")
local section = tab:Section("Controls")
local toggle = section:Toggle("enabled", "Enabled", true, function() callbacks += 1 end)
local integer = section:SliderInt("integer", "Distance", 0, 4000, 3200, function() callbacks += 1 end)
local floating = section:SliderFloat("floating", "Opacity", 0, 1, .5, "%.2f", function() callbacks += 1 end)
local dropdown = section:Dropdown("choice", "Choice", {"First", "Second", "Third"}, 0, function() callbacks += 1 end)
local color = section:ColorPicker("color", .2, .4, .6, .5, function(c, a) colorCallback = {c, a}; callbacks += 1 end)
local input = section:InputText("name", "Name", "default", function() callbacks += 1 end)
local bind = section:Keybind("key", 0x75, "toggle")
local button = section:Button("apply", "Apply", function() callbacks += 1 end)
section:Heading("Information")
section:Label("help", "Standalone native Drawing library")
local custom = window:Tab("Utilities"):Section("Tools")
custom:Toggle("utility", "Utility enabled", false)
settle(window)
check(Runtime.visibleText("Public library fixture") ~= nil, "custom title renders")
check(textContains("General") ~= nil and textContains("Utilities") ~= nil and textContains("Settings") ~= nil,
    "custom tab groups and built-in Settings are reachable in the sidebar")
check(window:Status().section == "Controls", "first user section is active")
check(window:GetValue("enabled") == true and window:GetValue("integer") == 3200 and window:GetValue("floating") == .5,
    "control defaults preserve their public argument order")
check(dropdown:GetText() == "First", "dropdown uses zero-based option indices")
local r, g, b, a = window:GetValue("color")
check(r == 51 and g == 102 and b == 153 and a == 127.5, "normalized constructor colors become RGBA bytes")

window:SetValue("enabled", false)
toggle:SetValue(true)
window:SetValue("integer", 99999)
window:SetValue("floating", -5)
window:SetValue("choice", 99)
check(callbacks == 0, "programmatic value changes are quiet")
check(window:GetValue("integer") == 4000 and window:GetValue("floating") == 0 and window:GetValue("choice") == 2,
    "numeric and dropdown values clamp to their declared bounds")
color:SetValue(Color3.fromRGB(10, 20, 30), .4)
r, g, b, a = window:GetValue("color")
check(near(r, 10) and near(g, 20) and near(b, 30) and near(a, 102), "Color3 with normalized alpha is accepted")
color:SetValue({1, 1, 1, 1})
r, g, b, a = window:GetValue("color")
check(r == 1 and g == 1 and b == 1 and a == 1, "RGBA byte arrays preserve near-black channels")
dropdown:Clear():Add("One"):Add("Two"):SetValue(1)
input:SetText("current")
check(dropdown:GetText() == "Two" and input:GetText() == "current", "dynamic dropdown and text handles remain usable")

settle(window)
click(window, center(toggle))
check(window:GetValue("enabled") == false and callbacks == 1, "a real rendered toggle click fires once")
local bounds = integer.bounds
click(window, bounds.x + 14 + (bounds.w - 28) * .25, bounds.y + 40)
check(window:GetValue("integer") == 1000 and callbacks > 1, "slider pointer position updates its range and callback")
local comboBounds = dropdown.bounds
click(window, comboBounds.x + comboBounds.w - 100, comboBounds.y + 20)
check(Runtime.visibleText("One") ~= nil, "dropdown opens through its rendered hit area")
click(window, comboBounds.x + comboBounds.w - 120, comboBounds.y + 7 + 29 + 4 + 6 + 16)
check(window:GetValue("choice") == 0, "dropdown click selects an option")
settle(window)
local colorBounds = color.bounds
click(window, colorBounds.x + colorBounds.w - 35, colorBounds.y + 20)
local red = Runtime.visibleText("Red")
check(red ~= nil, "color editor opens through its rendered swatch")
click(window, red.Position.X + 68 + (285 - 144) * .5, red.Position.Y + 8)
check(colorCallback and type(colorCallback[1].R) == "number" and colorCallback[2] >= 0 and colorCallback[2] <= 1,
    "color callback receives Color3 and normalized alpha")
click(window, 5, 5)
settle(window)
local inputBounds = input.bounds
click(window, inputBounds.x + inputBounds.w - 100, inputBounds.y + 20)
Runtime.keys[65] = true; frame(window)
Runtime.keys[65] = false; frame(window)
Runtime.keys[13] = true; frame(window)
Runtime.keys[13] = false; frame(window)
check(input:GetText() == "currenta", "text input commits keyboard edits through the rendered field")
window:Hide()
Runtime.keys[0x75] = true; frame(window)
Runtime.keys[0x75] = false; frame(window)
check(bind:IsEnabled() and window:GetValue("key") == true, "toggle keybind reports its active boolean while the menu is hidden")
local hold = section:Keybind("hold_key", 0x74, "hold")
Runtime.keys[0x74] = true; frame(window)
check(hold:IsEnabled(), "hold keybind follows injected key state")
Runtime.focused = false; frame(window)
check(not hold:IsEnabled(), "losing focus releases held keybinds")
Runtime.focused = true
Runtime.keys[0x74] = false
window:Show()
settle(window)

local beforeBlockedClick = window:GetValue("enabled")
Runtime.typing = true
click(window, center(toggle))
check(window:GetValue("enabled") == beforeBlockedClick, "typing focus blocks pointer input")
Runtime.typing = false
Runtime.focused = false
click(window, center(toggle))
check(window:GetValue("enabled") == beforeBlockedClick, "lost application focus blocks pointer input")
Runtime.focused = true
frame(window)

local saved = window:ExportConfig()
check(type(saved) == "table", "config export returns a table")
check(saved.Values.key == 0x75, "config stores the keybind VK independently of its active boolean")
check(not window:ImportConfig({Version = 999, Values = {integer = 7}}) and window:GetValue("integer") == 1000,
    "unknown config versions are rejected without changing values")
window:SetValue("integer", 2400)
local callsBeforeImport = callbacks
window:ImportConfig(saved)
check(window:GetValue("integer") == 1000 and callbacks == callsBeforeImport, "config imports restore values quietly by default")
window:SetValue("integer", 1600)
window:ImportConfig(clone(saved), true)
check(window:GetValue("integer") == 1000 and callbacks > callsBeforeImport, "explicit config notifications invoke control callbacks")
-- Reading exported config must never expose live control value references.
local secondExport = window:ExportConfig()
local function vandalize(t)
    for key, value in pairs(t) do
        if type(value) == "table" then vandalize(value)
        elseif type(value) == "number" then t[key] = 999999 end
    end
end
vandalize(secondExport)
r, g, b, a = window:GetValue("color")
check(r ~= 999999 and a ~= 999999, "config exports own their nested color tables")

local wheelSection = window:Tab("Scrolling"):Section("Long page")
local items = {}
for i = 1, 12 do items[i] = "Item " .. tostring(i) end
local longDropdown = wheelSection:Dropdown("long_choice", "Long dropdown", items, 0)
for i = 1, 24 do wheelSection:Toggle("long_toggle_" .. i, "Control " .. i, false) end
window:SelectSection("Long page")
settle(window)
local page = window:ScrollRegions().page
check(page and page.max > 0 and page.target == 0, "long page exposes initial overflowing scroll geometry")
local px, py = page.x + page.w / 2, page.y + page.h / 2
local accepted, scope = window:Scroll(-2, px, py)
check(accepted and scope == "page" and window:ScrollRegions().page.target == 68, "wheel detents route to the hovered page")
frame(window)
local moving = window:ScrollRegions().page
check(moving.current > 0 and moving.current < moving.target, "page wheel motion interpolates")
settle(window)
check(near(window:ScrollRegions().page.current, 68, .1), "page scroll settles at the requested offset")
local priorTarget = window:ScrollRegions().page.target
check(not window:Scroll(-1, 5, 5) and window:ScrollRegions().page.target == priorTarget, "wheel outside the interface is ignored")
Runtime.focused = false
check(not window:Scroll(-1, px, py), "wheel is ignored when application focus is lost")
Runtime.focused = true
local priorWheelCalls = wheelCalls
wheelPacket = {-1, px, py}
frame(window)
check(wheelCalls == priorWheelCalls + 1 and window:ScrollRegions().page.target == 102, "custom wheel consumer is called exactly once per frame")
frame(window)
check(window:ScrollRegions().page.target == 102, "consumed wheel input is not replayed")
window:Scroll(24, px, py)
settle(window)
local longBounds = longDropdown.bounds
click(window, longBounds.x + longBounds.w - 100, longBounds.y + 20)
settle(window)
local modal = window:ScrollRegions().dropdown
check(modal and modal.max == 4, "overflowing dropdown publishes its own scroll region")
local priorPage = window:ScrollRegions().page.target
accepted, scope = window:Scroll(-2, modal.x + modal.w / 2, modal.y + modal.h / 2)
check(accepted and scope == "dropdown", "open dropdown receives wheel priority")
frame(window)
check(window:ScrollRegions().page.target == priorPage, "dropdown wheel input does not move the page underneath")
check(not window:Scroll(-1, px, py), "open dropdown blocks wheel routing outside its bounds")
click(window, 5, 5)
settle(window)

local largeGroup = window:Tab("Sidebar overflow")
for i = 1, 32 do largeGroup:Section("Navigation " .. i) end
window:SelectSection("Navigation 1")
settle(window)
local sidebar = window:ScrollRegions().sidebar
check(sidebar and sidebar.max > 0, "large custom group produces sidebar overflow")
accepted, scope = window:Scroll(-3, sidebar.x + sidebar.w / 2, sidebar.y + sidebar.h / 2)
check(accepted and scope == "sidebar", "sidebar routes wheel input independently")
settle(window)
check(near(window:ScrollRegions().sidebar.current, 102, .1), "sidebar scroll reaches its own target")

window:SelectSection("Controls")
settle(window)
local plateau = Runtime.made
for _ = 1, 120 do frame(window) end
check(Runtime.made == plateau, "stable frames reuse native Drawing objects")
window:Hide()
settle(window)
check(Runtime.visibleCount() == 0, "hidden window hides all owned drawings after its transition")
window:Show()
settle(window)
check(Runtime.visibleCount() > 0, "show restores the window")
window:Toggle()
settle(window)
check(Runtime.visibleCount() == 0, "visibility toggle closes the window")
window:Show()
settle(window)
Runtime.keys[0x50] = true; frame(window)
Runtime.keys[0x50] = false; frame(window)
settle(window)
check(Runtime.visibleCount() == 0, "injected key state drives the default menu key")
window:Show()
settle(window)

local faults = window:Tab("Runtime"):Section("Errors")
local faultButton = faults:Button("fault", "Report callback error", function() error("fixture callback failure") end)
window:SelectSection("Errors")
settle(window)
click(window, center(faultButton))
check(errorCalls == 1, "callback failure is reported through OnError exactly once")
window:SelectSection("Controls")
settle(window)
check(Runtime.visibleCount() > 0, "callback failure leaves the drawing interface usable")

local destroySection = window:Tab("Lifecycle"):Section("Cleanup")
local destroyButton = destroySection:Button("destroy", "Destroy window", function() window:Destroy() end)
window:SelectSection("Cleanup")
settle(window)
click(window, center(destroyButton))
check(Runtime.removed == Runtime.made, "destruction inside a callback removes every drawing without later writes")
window:Destroy()
frame(window)
check(Runtime.removed == Runtime.made, "Destroy and Step are safe after cleanup")

local one = Library:CreateWindow(options({Title = "One", Singleton = false}))
local two = Library:CreateWindow(options({Title = "Two", Singleton = false}))
one:Tab("General"):Section("Shared name"):Toggle("shared_id", "First value", true)
two:Tab("General"):Section("Shared name"):Toggle("shared_id", "Second value", false)
settle(one); settle(two)
one:SetValue("shared_id", false)
two:SetValue("shared_id", true)
check(one:GetValue("shared_id") == false and two:GetValue("shared_id") == true, "windows own their control IDs and values")
one:Destroy()
check(Runtime.removed < Runtime.made, "destroying one window preserves another window's drawings")
frame(two)
check(two:GetValue("shared_id") == true and Runtime.visibleCount() > 0, "surviving window remains usable")
two:Destroy()
check(Runtime.removed == Runtime.made, "multiple windows clean up independently")

local closeCalls = 0
local closing = Library:CreateWindow(options({OnClose = function() closeCalls += 1 end}))
settle(closing)
local geometry = closing:ScrollRegions().window
click(closing, geometry.x + geometry.w - 66, geometry.y + 30)
settle(closing)
check(Runtime.visibleCount() == 0 and closeCalls == 0, "header minimize hides without calling OnClose")
closing:Show()
settle(closing)
geometry = closing:ScrollRegions().window
click(closing, geometry.x + geometry.w - 30, geometry.y + 30)
check(closeCalls == 1 and Runtime.removed == Runtime.made, "header close invokes OnClose once and removes drawings")
closing:Destroy()
check(closeCalls == 1, "repeated Destroy does not repeat OnClose")

local old = Library:CreateWindow(options())
settle(old)
local replacement = Library:CreateWindow(options())
check(not old:Status().alive, "singleton creation cleans up the previous window")
replacement:Destroy()

local inert = Library:CreateWindow({ManualUpdate = true, InputAdapter = "none", Mouse = Runtime.mouse})
settle(inert)
Runtime.keys[0x50] = true; frame(inert)
Runtime.keys[0x50] = false; frame(inert)
check(inert:Status().visible and inert:Status().inputAdapter == "none", "none adapter ignores ambient key bindings")
inert:Destroy()

local automatic = Library:CreateWindow(options({ManualUpdate = false}))
check(automatic:Status().automaticUpdate and Runtime.connectedCount() == 1, "automatic mode connects the frame signal")
Runtime.render:Fire(1 / 60)
check(automatic:Status().drawings > 0, "frame signal actually renders automatic windows")
automatic:Destroy()
check(Runtime.connectedCount() == 0, "automatic window disconnects its frame subscription")

local native = Library:CreateWindow({ManualUpdate = true, InputAdapter = "roblox", Viewport = function() return 1920, 1080 end})
local nativePage = native:Tab("Native input"):Section("Native controls")
local nativeToggle = nativePage:Toggle("native_toggle", "Native toggle", false)
for i = 1, 24 do nativePage:Label("native_label_" .. i, "Row " .. i) end
settle(native)
check(native:Status().inputAdapter == "roblox" and native:Status().wheelSource == "native", "Roblox adapter installs native wheel events")
local nx, ny = center(nativeToggle)
click(native, nx + Runtime.inset.X, ny + Runtime.inset.Y)
check(native:GetValue("native_toggle") == true, "Roblox pointer adapter applies the GUI inset")
local nativeRegion = native:ScrollRegions().page
Runtime.mouse.X, Runtime.mouse.Y = nativeRegion.x + nativeRegion.w / 2, nativeRegion.y + nativeRegion.h / 2 + Runtime.inset.Y
Runtime.inputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, -2)})
frame(native)
check(native:ScrollRegions().page.target == 68, "native wheel event moves the hovered page")
frame(native)
check(native:ScrollRegions().page.target == 68, "native wheel accumulation is consumed once")
Runtime.keys[0x50] = true; frame(native)
Runtime.keys[0x50] = false; frame(native)
check(not native:Status().visible, "Roblox key adapter maps Windows VK menu keys")
native:Show(); settle(native)
Runtime.typing = true
click(native, nx, ny + Runtime.inset.Y)
check(native:GetValue("native_toggle") == true, "Roblox focused text box blocks control interaction")
Runtime.typing = false
native:Destroy()
check(Runtime.connectedCount() == 0, "native adapter disconnects its input subscription")
Runtime.inputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, -4)})

local matcha = Library:CreateWindow(options({InputAdapter = "auto", MatchaWheel = false}))
check(matcha:Status().inputAdapter == "matcha" and matcha:Status().wheelSource == "manual", "auto adapter selects Matcha bindings without a companion when disabled")
matcha:Destroy()
local companion = Library:CreateWindow(options({InputAdapter = "matcha", WheelFilePrefix = "public-test"}))
local companionPage = companion:Tab("Companion"):Section("Wheel input")
for i = 1, 24 do companionPage:Label("companion_row_" .. i, "Row " .. i) end
settle(companion)
local relay = companion:Status().wheel
check(companion:Status().wheelSource == "matcha companion" and relay and Runtime.files["public-test.wheel-lease.txt"] ~= nil,
    "Matcha companion publishes a scoped input lease")
local companionRegion = companion:ScrollRegions().page
local cx, cy = companionRegion.x + companionRegion.w / 2, companionRegion.y + companionRegion.h / 2
local function stamp()
    local expiry = tonumber(Runtime.files["public-test.wheel-lease.txt"]:match("([^|]+)$"))
    assert(expiry, "companion lease contains its timestamp")
    return expiry - 10
end
Runtime.files["public-test.wheel.txt"] = table.concat({"2", relay.session, "helper-A", "1", "-2", cx, cy, stamp()}, "|")
Runtime.time += .05; frame(companion)
check(companion:ScrollRegions().page.target == 68, "scoped companion packet drives real page wheel input")
Runtime.time += .05; frame(companion)
check(companion:ScrollRegions().page.target == 68, "companion accumulated packet is not replayed")
Runtime.files["public-test.wheel.txt"] = table.concat({"2", "another-session", "helper-A", "2", "-8", cx, cy, stamp()}, "|")
Runtime.time += .05; frame(companion)
check(companion:ScrollRegions().page.target == 68, "companion packets for another window session are ignored")
Runtime.files["public-test.wheel.txt"] = table.concat({"2", relay.session, "helper-A", "2", "-8", cx, cy, stamp() - 5}, "|")
Runtime.time += .05; frame(companion)
check(companion:ScrollRegions().page.target == 68, "stale companion packets are ignored")
companion:Destroy()
check(Runtime.files["public-test.wheel-lease.txt"] == "stop|" .. relay.session, "Destroy stops the companion lease")
check(Runtime.removed == Runtime.made and Runtime.connectedCount() == 0, "every adapter cleans up all native resources")

local customDraws, injectDrawingFailure, renderErrors, renderCloseReason = 0, false, 0, nil
local customDrawing = {new = function(kind)
    if injectDrawingFailure then error("fixture native drawing failure") end
    customDraws += 1
    return Drawing.new(kind)
end}
local fragile = Library:CreateWindow(options({
    Drawing = customDrawing,
    OnError = function(message)
        check(message:find("fixture native drawing failure", 1, true) ~= nil, "render error reports the original binding failure")
        renderErrors += 1
    end,
    OnClose = function(reason) renderCloseReason = reason end,
}))
fragile:Tab("Custom backend"):Section("Initial"):Label("initial", "First view")
settle(fragile)
check(customDraws > 0 and fragile:Status().drawings == customDraws, "custom Drawing backend owns every native allocation")
local failingSection = fragile:Tab("Custom backend"):Section("Failing view")
failingSection:Toggle("new_drawing", "New drawing", false)
fragile:SelectSection("Failing view")
injectDrawingFailure = true
check(not fragile:Step(1 / 60) and not fragile:Status().alive, "unrecoverable Drawing errors close the window")
check(renderErrors == 1 and renderCloseReason == "render error", "render failure is reported once with its cleanup reason")
check(Runtime.removed == Runtime.made, "render failure removes all previously allocated objects")
fragile:Destroy()
check(renderErrors == 1 and Runtime.removed == Runtime.made, "cleanup after render failure stays idempotent")

print("Thalassar public library: " .. checks .. " checks passed; " .. Runtime.made .. " drawings cleaned up")
