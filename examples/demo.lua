-- Generic standalone Thalassar UI demo for the Matcha Drawing runtime.
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/InnerThoughtz-spec/Thalassar-UI/main/Library.lua"
))()

local Library = assert(_G.ThalassarUI, "Thalassar UI did not load")
local Window = Library:CreateWindow({Title = "Thalassar UI · Demo"})

local General = Window:Tab("General")
local Controls = General:Section("Controls")

Controls:Heading("Preview controls")
Controls:Label("A generic demo of values, callbacks, and scrolling.")

Controls:Toggle("enabled", "Enable preview", true, function(value)
    print("Preview enabled:", value)
end)

Controls:SliderInt("amount", "Amount", 0, 100, 50, function(value)
    print("Amount:", value)
end)

Controls:SliderFloat("opacity", "Opacity", 0, 1, 0.75, "%.2f", function(value)
    print("Opacity:", value)
end)

Controls:Dropdown("style", "Style", {"Soft", "Balanced", "Bright"}, 0, function(index)
    print("Style index:", index) -- Zero-based: Soft = 0.
end)

Controls:ColorPicker({
    Id = "accent",
    Title = "Accent color",
    Default = {90, 170, 255, 255},
    Callback = function(color, opacity)
        print("Accent:", color, "Opacity:", opacity)
    end,
})

Controls:InputText({
    Id = "preview_name",
    Title = "Preview name",
    Default = "My preview",
    Callback = function(value)
        print("Preview name:", value)
    end,
})

Controls:Keybind({
    Id = "shortcut",
    Title = "Preview shortcut",
    Default = 0x4B, -- Windows VK_K.
    Mode = "toggle",
    Callback = function(active, keyCode)
        print("Shortcut active:", active, "Key code:", keyCode)
    end,
})

local savedConfig
Controls:Button({
    Id = "export",
    Title = "Remember settings",
    Callback = function()
        savedConfig = Window:ExportConfig()
        print("Settings remembered for this demo session.")
    end,
})

Controls:Button({
    Id = "restore",
    Title = "Restore remembered settings",
    Callback = function()
        if savedConfig then
            Window:ImportConfig(savedConfig, false)
            print("Settings restored quietly.")
        end
    end,
})

-- Extra rows make content overflow so the section can be scrolled.
for index = 1, 12 do
    Controls:Toggle("example_" .. index, "Example option " .. index, index % 2 == 0)
end

local About = General:Section("About")
About:Heading("Thalassar UI")
About:Label("Use Settings to customize the window and ambient effects.")
About:Label("Call Window:Destroy() when this demo is no longer needed.")

-- Keep a handle for cleanup or host integration.
_G.ThalassarDemo = Window
