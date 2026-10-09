# Thalassar UI

A standalone Lua UI library for the Matcha Drawing runtime. Thalassar UI provides a rounded glass-style window, tab groups, sections, common controls, scrolling, configuration export/import, and optional ambient effects.

The public entry point is [`Library.lua`](Library.lua). The library is independent of any game-specific scripts.

![Thalassar UI preview](docs/preview.png)

Offline preview rendered from the library's Drawing output.

## Runtime

The primary supported target is Matcha with the Drawing API and its input/render APIs. Rounded panels use Matcha's `Drawing` `Square.Corner` support. The glass appearance is drawn with translucent layers, borders, and highlights; it does not perform true background blur or refraction.

Use `Drawing`, an available render-step signal, and readable mouse/keyboard input. HTTP loading also requires `game:HttpGet` and `loadstring` in the host environment. Compatibility with other Drawing implementations depends on their API support and has not been universally verified.

## Load

Matcha may discard a loaded chunk's return value. Load the file first, then retrieve the published global:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/InnerThoughtz-spec/Thalassar-UI/main/Library.lua"
))()

local Library = assert(_G.ThalassarUI, "Thalassar UI did not load")
```

Hosts that retain chunk return values can use the conventional form:

```lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/InnerThoughtz-spec/Thalassar-UI/main/Library.lua"
))()
```

## Quick start

```lua
local Window = Library:CreateWindow({
    Title = "Thalassar UI",
})

local General = Window:Tab("General")
local Controls = General:Section("Controls")

Controls:Toggle("enabled", "Enable preview", true, function(enabled)
    print("Preview:", enabled)
end)

Controls:SliderInt("amount", "Amount", 0, 100, 50, function(value)
    print("Amount:", value)
end)

Controls:Dropdown("style", "Style", {"Soft", "Balanced", "Bright"}, 0, function(index)
    print("Selected index:", index)
end)
```

Dropdown and combo selection indexes start at **0**. Control IDs identify values within a window; give each control a unique ID.

See [`examples/demo.lua`](examples/demo.lua) for a complete generic demo and [`docs/API.md`](docs/API.md) for the API reference.

## Window behavior

- Tab names become navigation groups, with sections beneath each group.
- A built-in Settings group exposes appearance and ambient effect controls.
- Content scrolls when a section exceeds the visible area.
- The library updates on `RenderStepped` by default. Set `ManualUpdate = true` and call `Window:Step(dt)` when your host owns the update loop.
- Creating a window destroys the previous Thalassar UI window by default. Set `Singleton = false` for independent windows with separately managed input/update loops.
- Call `Window:Destroy()` when you finish with a window to release its drawings and connections.

The included effects are Rain, Snow, Fireflies, Bubbles, and Ripples. Configure them in the built-in Background section.

## Mouse wheel in Matcha

The library accepts `Window:Scroll(delta, x, y)` and an optional `ConsumeWheel` callback. The Roblox input adapter uses native wheel input where `UserInputService.InputChanged` is available. Matcha does not expose a native wheel event to the library. An optional Windows companion is supplied in [`adapters/matcha`](adapters/matcha): `wheel_helper.py` and `Start-WheelHelper.ps1`.

The companion is separate from `Library.lua`; loading the UI does not install or start a Windows helper. See the adapter instructions for setup and input routing. You can also call `Scroll` from your own host adapter.

## Configuration

```lua
local saved = Window:ExportConfig()

-- Restore values quietly. Pass true as the second argument to notify callbacks.
Window:ImportConfig(saved)

-- Programmatic value changes are quiet.
Window:SetValue("amount", 75)
print(Window:GetValue("amount"))
```

Configuration export returns a Lua table with `Version`, `Appearance`, `Values`, and `Background` fields. Store or encode it through your own host's persistence facilities.

## Development checks

The offline suite compiles the distribution and exercises controls, scrolling, configuration, callbacks, adapters, and cleanup with a mock Drawing runtime. It also runs the public demo body.

With Python 3 and the official Luau CLI available:

```sh
python tests/run_tests.py --luau-dir "path/to/luau-cli"
```

These checks validate the library offline. Rendering and input should also be checked in the target runtime.

## License

MIT. See [`LICENSE`](LICENSE).
