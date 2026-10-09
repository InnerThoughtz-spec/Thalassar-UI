-- Neutral UI showcase. Load Library.lua first, or run the standalone Demo.lua.
local Library = assert(_G.ThalassarUI, "Load Thalassar UI before running the demo")
local state = {callbackCount = 0, lastAction = "Ready", closed = false, Controls = {}}
local Window
local summary, activity

local function refresh()
    if state.closed or not summary then return end
    local styles = {"Soft", "Balanced", "Bright"}
    summary:SetValue(string.format("Preview: %s · %d items · %s",
        Window:GetValue("enabled") and "on" or "off",
        Window:GetValue("amount"), styles[Window:GetValue("style") + 1]))
    state.Controls.amount:SetDisabled(not Window:GetValue("enabled"))
end

local function report(message)
    state.callbackCount = state.callbackCount + 1
    state.lastAction = message
    if activity then activity:SetValue("Last action: " .. message) end
    refresh()
end

Window = Library:CreateWindow({
    Title = "Thalassar UI · Demo",
    Footer = "THALASSAR UI",
    Visible = true,
    Appearance = {Opacity = 0.75},
    Background = {Effect = "Snow", Intensity = 0.22, Speed = 0.28, Opacity = 0.42},
    OnError = function(message)
        state.lastError = message
        print("Thalassar UI demo: " .. message)
    end,
    OnClose = function(reason)
        state.closed = true
        state.closeReason = reason
        if _G.ThalassarDemo == Window then _G.ThalassarDemo = nil end
    end,
})

local General = Window:Tab("General")
local Controls = General:Section("Controls")
Controls:Heading("Try the controls")
Controls:Label("Adjust values, open the color picker, or try a shortcut.")
summary = Controls:Label("demo_summary", "Preview: on · 50 items · Soft")
activity = Controls:Label("demo_activity", "Last action: Ready")

state.Controls.enabled = Controls:Toggle("enabled", "Enable preview", true, function(value)
    report(value and "Preview enabled" or "Preview paused")
end):Tip("Pausing the preview disables its amount slider.")

state.Controls.amount = Controls:SliderInt("amount", "Amount", 0, 100, 50, function(value)
    report("Amount set to " .. value)
end)

state.Controls.opacity = Controls:SliderFloat("opacity", "Window opacity", 0.2, 1, 0.75, "%.2f", function(value)
    Window:ImportConfig({Version = 1, Appearance = {Opacity = value}})
    report(string.format("Window opacity %.2f", value))
end)

state.Controls.style = Controls:Dropdown("style", "Glass style", {"Soft", "Balanced", "Bright"}, 0, function(index)
    local bodyOpacity = {0.10, 0.18, 0.24}
    Window:ImportConfig({Version = 1, Appearance = {BodyOpacity = bodyOpacity[index + 1]}})
    report("Glass style changed")
end)

state.Controls.accent = Controls:ColorPicker({
    Id = "accent", Title = "Accent color", Default = {147, 171, 182, 255},
    Callback = function(color, opacity)
        local bytes = {color.R * 255, color.G * 255, color.B * 255, opacity * 255}
        Window:ImportConfig({Version = 1, Appearance = {Accent = bytes}})
        report("Accent color changed")
    end,
})

state.Controls.name = Controls:InputText({
    Id = "preview_name", Title = "Preview name", Default = "My preview",
    Callback = function(value) report("Name: " .. value) end,
})

state.Controls.shortcut = Controls:Keybind({
    Id = "shortcut", Title = "Preview shortcut", Default = 0x4B, Mode = "toggle",
    Callback = function(active, keyCode)
        report(string.format("Shortcut %s (key %d)", active and "on" or "off", keyCode))
    end,
}):Tip("Default: K. Try it while the menu is hidden with P.")

state.Controls.action = Controls:Button("run_preview", "Run preview action", function()
    report("Preview action complete")
end)

-- Enough rows to test smooth content scrolling immediately after opening.
Controls:Heading("Scrollable options")
for index = 1, 12 do
    Controls:Toggle("example_" .. index, "Example option " .. index, index % 2 == 0, function(value)
        report("Option " .. index .. (value and " enabled" or " disabled"))
    end)
end

local Workflow = Window:Tab("Workflow")
local Profiles = Workflow:Section("Profiles")
Profiles:Heading("Settings for this session")
Profiles:Label("Remember values, change them, then restore your snapshot.")
local savedConfig, initialConfig
state.Controls.export = Profiles:Button("export", "Remember settings", function()
    savedConfig = Window:ExportConfig()
    report("Settings remembered")
end)
state.Controls.restore = Profiles:Button("restore", "Restore remembered settings", function()
    if savedConfig then
        Window:ImportConfig(savedConfig, false)
        report("Settings restored")
    else
        report("Remember settings first")
    end
end)
state.Controls.reset = Profiles:Button("reset_demo", "Restore demo defaults", function()
    if initialConfig then Window:ImportConfig(initialConfig, false) end
    report("Demo defaults restored")
end)
Profiles:Label("Snapshots stay in memory. Your application owns file storage.")

local Navigation = Workflow:Section("Navigation")
Navigation:Heading("Window and navigation")
state.Controls.background = Navigation:Button("open_background", "Open background effects", function()
    report("Background settings opened")
    Window:SelectSection("Background")
end)
state.Controls.appearance = Navigation:Button("open_appearance", "Open appearance settings", function()
    report("Appearance settings opened")
    Window:SelectSection("Appearance")
end)
state.Controls.minimize = Navigation:Button("minimize_demo", "Minimize demo", function()
    report("Demo minimized; press P to reopen")
    Window:Hide()
end)
Navigation:Label("The title-bar dash minimizes. X releases this demo's resources.")

local About = General:Section("About")
About:Heading("Thalassar UI")
About:Label("Glass panels, animated controls, and a collapsible sidebar.")
About:Label("Settings contains fonts, colors, sizing, and motion options.")
About:Label("Background effects include rain, snow, bubbles, and more.")
About:Label("This demo only changes its own interface.")
About:Label("Source, examples, and the API reference are in the public repository.")

initialConfig = Window:ExportConfig()
Window:SelectSection("Controls")
refresh()
Window:Show()

-- Handles for host integration, diagnostics, and deterministic demo cleanup.
_G.ThalassarDemo = Window
_G.ThalassarDemoState = state
print("Thalassar UI demo ready. Explore General, Workflow, and Settings.")
