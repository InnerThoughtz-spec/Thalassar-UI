# API reference

This reference describes the reusable public `Library.lua`. To open the complete generic demo instead, run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/InnerThoughtz-spec/Thalassar-UI/main/Demo.lua"))()
```

To create your own interface:

```lua
local loaded = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/InnerThoughtz-spec/Thalassar-UI/main/Library.lua"
))()
local Library = assert(loaded or _G.ThalassarUI, "Thalassar UI did not load")
```

Contents: [CreateWindow](#createwindow), [navigation](#navigation), [controls](#controls), [window methods](#window-methods), [appearance](#appearance), [ambient effects](#ambient-effects), [configuration](#configuration-shape), [host integration](#host-integration), [lifecycle and diagnostics](#lifecycle-and-diagnostics).

The entry point returns the library table where the host preserves chunk results. It also publishes the same table as `_G.ThalassarUI` for Matcha. `Library.Version` contains the library version, and `Library:DestroyAll()` destroys its active windows. Reloading the library destroys windows created by the previous Thalassar UI library instance.

```lua
local Window = Library:CreateWindow(options)
```

## CreateWindow

| Option | Meaning |
| --- | --- |
| `Title` | Window title; defaults to `"Thalassar UI"`. |
| `Footer` | Footer text; defaults to `"THALASSAR UI"`. |
| `Visible` | Initial visibility; defaults to `true`. |
| `ManualUpdate` | When `true`, the caller must call `Window:Step(dt)`. Automatic render-step updates are the default. |
| `Singleton` | Defaults to `true`: destroys the previous Thalassar UI window when creating a new one. Set to `false` for independent windows. |
| `Appearance` | Appearance overrides. |
| `Background` | Initial ambient effect configuration. |
| `InputAdapter` | `"auto"`, `"matcha"`, `"roblox"`, or `"none"`. |
| `Drawing` | Optional Drawing backend; defaults to the global `Drawing`. Must implement `new`. |
| `Fonts` | Optional backend font IDs keyed by `System`, `Bold`, `Clean`, `SoftBold`, and `Monospace`. |
| `RunService` | Optional render-step source; defaults to `game:GetService("RunService")`. |
| `Mouse` | Mouse object exposing numeric `X` and `Y` coordinates. |
| `Viewport` | Callback returning viewport width and height. |
| `IsKeyPressed` | Callback accepting a Windows virtual-key code and returning whether it is pressed. |
| `IsMousePressed` | Callback returning whether the primary mouse button is pressed. |
| `Focused` | Callback returning whether the host window is focused. |
| `Typing` | Callback returning whether an external text field is active; UI interaction pauses while it returns `true`. |
| `ConsumeWheel` | Callback returning `delta, x, y` for wheel input. |
| `MatchaWheel` | Set to `false` to disable the file bridge for the optional Matcha companion. |
| `WheelFilePrefix` | File bridge prefix; defaults to `"Thalassar-UI"`. Only letters, digits, underscores, and dashes are allowed. |
| `OnVisibility` | Callback receiving the visible boolean when visibility changes. |
| `OnAppearanceChanged` | Callback receiving the current appearance table when appearance changes. |
| `OnClose` | Cleanup callback receiving a reason such as `"close"`, `"destroy"`, or `"render error"`. |
| `OnError` | Callback receiving an error string. |

```lua
local Window = Library:CreateWindow({
    Title = "Thalassar UI",
    Visible = true,
    ManualUpdate = false,
    InputAdapter = "auto",
})
```

`"auto"` chooses Matcha when both `iskeypressed` and `ismouse1pressed` are available; otherwise it chooses the Roblox input adapter. Matcha is the primary supported target. The Roblox adapter maps supported Windows VK codes to `Enum.KeyCode` and reads mouse/textbox state through `UserInputService`; compatibility still depends on the host's Drawing API. Use `InputAdapter = "none"` with your own input callbacks for custom integration.

The Drawing backend must provide `Square`, `Line`, `Circle`, and `Text` objects with their usual position, size, color, opacity, visibility, and removal properties. Rounded panels use `Square.Corner`. The host must also provide `Color3`, `Vector2`, and Luau's `math.clamp`. An ordinary Roblox LocalScript does not supply the Drawing API or this HTTP loadstring environment.

Event callbacks run as follows:

| Callback | When it runs |
| --- | --- |
| `OnVisibility(visible)` | Once during window construction, when showing/hiding, and during cleanup. |
| `OnAppearanceChanged(appearance)` | When a built-in appearance setting changes or is imported. Initial overrides can trigger it during construction. |
| `OnClose(reason)` | Once when a window is destroyed, closed by X, or stopped by a fatal construction/render failure. |
| `OnError(message)` | When a user callback or rendering operation fails. A callback failure is recorded; a fatal render failure also closes the window. |

Callbacks can run before `CreateWindow` returns. Keep construction-time callbacks independent of the window variable until it has been assigned.

## Navigation

```lua
local Tab = Window:Tab("General")
local Section = Tab:Section("Controls")
```

Tab names are used to build navigation groups dynamically. Sections contain controls in insertion order. The built-in sections are exposed as `Window.BackgroundSection` and `Window.SettingsSection`.

`Window:Tab(name, builder)` optionally calls `builder(tab)` immediately:

```lua
Window:Tab("General", function(tab)
    local Section = tab:Section("Controls")
    Section:Toggle("enabled", "Enabled", true, function(value)
        print(value)
    end)
end)
```

`Tab:Section(title, {Group = "Other group"})` can override the section's sidebar group. Section titles identify the target of `Window:SelectSection(title)`; distinct titles make programmatic selection unambiguous. The `Interface` section option is reserved for the library's built-in settings.

## Controls

Controls accept unique IDs. IDs are used by `GetValue`, `SetValue`, and configuration import/export. User interactions call the supplied callback; programmatic `SetValue` calls are quiet. Avoid the `thalassar_` prefix, which is used by built-in controls.

Constructing a user control does not call its callback. Initialize your application state from the default values, or explicitly restore values with `Window:ImportConfig(config, true)` when you want notification. Built-in appearance/effect controls apply their internal callbacks even for programmatic changes.

Table-form controls share these options:

| Option | Meaning |
| --- | --- |
| `Id` | Unique string used for lookup and configuration. |
| `Title` | Visible control label. |
| `Default` | Initial value, according to the control type. |
| `Callback` | Function receiving the value or the documented specialized arguments. |
| `Hidden` | `true` to omit the row initially. |
| `Enabled` | `false` to disable interaction initially. |
| `Tooltip` | Text shown on hover. |

Use colon syntax for window, tab, section, and control methods. The examples below show the normal positional signatures and the table form where extra options are useful.

### Toggle

```lua
Section:Toggle(id, title, default, callback)
Section:Toggle({Id = id, Title = title, Default = default, Callback = callback})
```

`default` and the callback value are booleans.

### Slider

```lua
Section:Slider(id, title, minimum, maximum, default, callback, step)

Section:Slider({
    Id = "volume",
    Title = "Volume",
    Min = 0,
    Max = 1,
    Default = 0.5,
    Step = 0.01,
    Callback = function(value) end,
})
```

Values clamp to the declared range and round to a positive `step`; `step = 0` disables rounding. The default step is `1`. `maximum` must be greater than or equal to `minimum`.

### SliderInt

```lua
Section:SliderInt(id, title, minimum, maximum, default, callback)
```

The callback receives the selected integer.

### SliderFloat

```lua
Section:SliderFloat(id, title, minimum, maximum, default, format, callback)
```

The callback receives the selected number. `format` controls the displayed value, for example `"%.2f"`.

The positional `SliderFloat` step is `0.01`. For a different step or common table-form options, use `Section:Slider({...})` with an explicit `Step`. A returned slider handle's `format` can be set to a `string.format` number pattern when custom formatting is needed.

### Dropdown and Combo

```lua
Section:Dropdown(id, title, items, defaultIndex, callback)
Section:Combo(id, title, items, defaultIndex, callback)
```

`items` is an array of labels. Both methods use **zero-based** selection indexes: the first item is `0`. The callback receives the selected index.

The table form accepts `Options` or `Items`:

```lua
Section:Dropdown({
    Id = "style", Title = "Style",
    Options = {"Soft", "Balanced", "Bright"},
    Default = 0,
    Callback = function(index) end,
})
```

### ColorPicker

```lua
Section:ColorPicker({
    Id = "accent",
    Title = "Accent color",
    Default = {90, 170, 255, 255},
    Callback = function(color3, opacity)
        -- color3 is a Color3; opacity is the alpha value as a 0–1 fraction.
    end,
})
```

The default is a four-byte `{red, green, blue, alpha}` array, with each component from `0` to `255`.

The positional signature is `Section:ColorPicker(id, r, g, b, alpha, callback, title)`. Table-form defaults can also use `Color = Color3.fromRGB(...)` with `Alpha = 0.75`. A returned handle accepts `Color:SetValue({r, g, b, a})` or `Color:SetValue(color3, opacity)`; its getter returns four byte channels.

### Button

```lua
Section:Button({Id = "action", Title = "Run action", Callback = function() end})
Section:Button(id, title, callback)
```

### Keybind

```lua
Section:Keybind({
    Id = "shortcut",
    Title = "Shortcut",
    Default = 0x4B, -- Windows VK_K
    Mode = "toggle", -- "toggle" or "hold"
    Callback = function(active, keyCode) end,
})
Section:Keybind(id, title, keyCode, callback, mode)
```

Key codes are Windows virtual-key values. Toggle bindings switch their active state on a key press; hold bindings follow whether the key is held. The callback receives the active state and current key code when the active state changes or a key is rebound. User bindings activate while the UI is hidden, so editing the menu does not trigger them.

`0` means unbound. Click the displayed key to rebind it. `GetValue()` and `IsEnabled()` report the active boolean; `SetValue(keyCode)` changes the binding, and exported configuration stores that numeric binding. Application focus and external text-entry focus are respected. The built-in show/hide key is **P** (`0x50`) by default.

### InputText

```lua
Section:InputText({
    Id = "name",
    Title = "Name",
    Default = "Preview",
    Callback = function(value) end,
})
Section:InputText(id, title, default, callback)
```

Click the field to edit. Enter commits the value, Escape cancels the edit, and Backspace removes a character. Text entry uses basic Windows virtual-key characters with a 120-character limit.

### Heading and Label

```lua
Section:Heading("Group heading")
Section:Label("Informational text")
Section:Label({Id = "status", Title = "Ready"})
```

### Control handles

Control constructors return a handle. Common methods are:

| Method | Behavior |
| --- | --- |
| `Control:SetValue(value)` | Updates the value quietly for user controls. |
| `Control:GetValue()` | Returns the current value; colors return `r, g, b, a` byte channels, and keybinds return the active boolean. |
| `Control:GetText()` | Returns the dropdown's selected label or a text representation of the value. |
| `Control:SetText(text)` | Updates text. |
| `Control:SetTitle(title)` | Changes the display title. |
| `Control:SetVisible(visible)` | Shows/hides the control. |
| `Control:SetDisabled(disabled)` | Enables/disables interaction. |
| `Control:Tip(text)` | Sets tooltip text. |
| `Control:Clear()` | Clears a dropdown's items. |
| `Control:Add(label)` | Appends a dropdown item. |
| `Control:IsEnabled()` | Returns the keybind's active state, or whether another control is enabled. |
| `Control:AddToHotkey(label, toggleId)` | Stores compatibility metadata on the handle. The renderer does not use it to link controls; implement linked behavior through your callback. |

`Section:Tip(text)` attaches a tooltip to the most recently added control. Table-form controls also accept `Hidden`, `Enabled`, and `Tooltip` options.

The setters above return the control handle, so methods such as `Dropdown:Clear():Add("One"):Add("Two"):SetValue(1)` can be chained. `SetText` is useful for text inputs and labels. Use numeric `SetValue` for a dropdown selection. Keybind titles, tooltips, visibility, and interaction state can be changed like those of other controls.

## Window methods

| Method | Behavior |
| --- | --- |
| `Window:SetValue(id, value)` | Changes a control value quietly. |
| `Window:GetValue(id)` | Returns the current value; colors return `r, g, b, a`, and keybinds return the active boolean. |
| `Window:RemoveTab(name)` | Removes a tab and its sections. |
| `Window:SelectSection(name)` | Selects a section by its title. |
| `Window:Show()` | Shows the window. |
| `Window:Hide()` | Hides the window. |
| `Window:Toggle()` | Toggles window visibility. |
| `Window:Step(dt)` | Runs one update. Required when `ManualUpdate = true`. |
| `Window:Scroll(delta, x, y)` | Routes a wheel delta at a mouse position. |
| `Window:ScrollRegions()` | Returns current scroll-region geometry. |
| `Window:ExportConfig()` | Returns a Lua configuration table. |
| `Window:ImportConfig(config, notify)` | Restores values; `notify` defaults to `false`. |
| `Window:ResetAppearance()` | Restores default appearance settings. |
| `Window:Status()` | Returns diagnostic state. |
| `Window:Destroy()` | Releases the window's drawings and connections. |

`SetValue` returns the matching handle or `nil`; `GetValue` returns `nil` for an unknown ID. Color values can use the same additional arguments as the color handle's setter. `Show`, `Hide`, and `Toggle` return the window for chaining. `SelectSection` returns whether it found a section. `Step` returns whether the window remains usable after that update. `ImportConfig` returns `false` for a closed window, a non-table, or an unsupported configuration version.

`Scroll` accepts wheel detents: positive scrolls upward, negative downward. Optional `x`/`y` default to the current pointer position. It returns whether the event was handled, followed by the region name when handled. `ScrollRegions` returns a table of regions such as `window`, `sidebar`, `page`, and an open `dropdown`, with geometry in `x`, `y`, `w`, and `h`, plus scroll state where applicable.

```lua
local saved = Window:ExportConfig()
Window:ImportConfig(saved, false)
Window:Hide()
Window:Show()
```

## Appearance

Pass an `Appearance` table to `CreateWindow`, or restore it through `ImportConfig`. The available theme keys are:

| Keys | Values |
| --- | --- |
| `Tint`, `Accent`, `Text` | RGBA byte arrays. |
| `Scale`, `Opacity`, `BodyOpacity`, `Rounding`, `FontSize`, `Font`, `Spacing` | Numeric appearance settings. |
| `Grain`, `Glow`, `Particles`, `Vignette`, `ReducedMotion` | Boolean options. |
| `GrainStrength`, `GlowStrength`, `ParticleAmount`, `ParticleSpeed`, `VignetteStrength`, `Specular`, `Bevel`, `AnimationSpeed` | Numeric effect/animation settings. |
| `MenuKey` | Windows virtual-key code for showing/hiding the window. |
| `Window` | Optional `{x, y, width, height}` placement and size array. |

The Settings section exposes these options interactively. Reduced motion stops ambient movement and makes transitions immediate.

Defaults and accepted ranges are listed below. Numeric appearance settings clamp to their UI ranges during import.

| Setting | Default | Range or meaning |
| --- | --- | --- |
| `Tint` | `{29, 32, 35, 255}` | Glass RGBA bytes. |
| `Accent` | `{147, 171, 182, 255}` | Selection and interaction RGBA bytes. |
| `Text` | `{237, 239, 240, 255}` | Text RGBA bytes. |
| `Opacity` | `0.64` | `0.35–1`, window opacity. |
| `BodyOpacity` | `0.12` | `0.05–0.95`, content-panel opacity. |
| `Rounding` | `24` | `0–28`, corner radius. |
| `Specular` | `0.42` | `0–1`, glass reflection. |
| `Bevel` | `0.24` | `0–1`, glass edge depth. |
| `Scale` | `1` | `0.75–1.5`, interface scale. |
| `FontSize` | `14` | `11–18`, text size. |
| `Font` | System backend ID, normally `1` | One of the backend IDs mapped by `Fonts`. |
| `Spacing` | `3` | `0–12`, row spacing. |
| `Grain` / `GrainStrength` | `true` / `0.12` | Grain toggle and `0–0.5` intensity. |
| `Glow` / `GlowStrength` | `true` / `0.16` | Edge glow toggle and `0–1` intensity. |
| `Vignette` / `VignetteStrength` | `false` / `0.10` | Inner shading toggle and `0–0.4` intensity. |
| `Particles` / `ParticleAmount` | `false` / `8` | Drifting speck toggle and `1–24` count. |
| `ParticleSpeed` | `0.18` | `0–1`, speck movement speed. |
| `ReducedMotion` | `false` | Freeze ambient movement and make transitions immediate. |
| `AnimationSpeed` | `1` | `0.5–2`, interaction animation speed. |
| `MenuKey` | `0x50` | Windows VK code; P by default. |
| `Window` | Initially centered, `900 × 650` | `{x, y, width, height}`; imported size clamps to `700–1400 × 480–1000`, then adapts to the viewport. |

The built-in palette choices are Graphite, Warm charcoal, Deep slate, and Soft stone. The font choices are System, Clean UI, Soft bold, and Monospace. Default backend IDs are System `1`, Bold `2`, Clean `0`, SoftBold `11`, and Monospace `5`; pass `Fonts` when your backend uses different IDs. `Appearance.Font` is the numeric backend ID, not a dropdown index or a font name.

## Ambient effects

The built-in Background section provides Rain, Snow, Fireflies, Bubbles, and Ripples, plus `"None"` to disable the effect. These are decorative Drawing effects. The rounded glass appearance depends on `Square.Corner`; true background blur and refraction are not provided.

```lua
local Window = Library:CreateWindow({
    Background = {
        Version = 1,
        Effect = "Snow",
        Intensity = 0.32,
        Speed = 0.35,
        Wind = 0.12,
        Opacity = 0.56,
        Color = {236, 240, 243, 255},
    },
})
```

`Intensity`, `Speed`, and `Opacity` use `0–1` fractions. `Wind` uses `-1–1`. `Color` is an RGBA byte array. Exported effects use their names as strings.

Default ambient configuration is Snow, intensity `0.32`, speed `0.35`, wind `0.12`, opacity `0.56`, and color `{236, 240, 243, 255}`. You can change effects independently of user control values:

```lua
Window.Effects.import({Effect = "Rain", Intensity = 0.4})
local background = Window.Effects.export()
Window.Effects.reset()
```

These module functions use dot syntax. Partial imports retain omitted values, synchronize the Background controls, and accept effect names case-insensitively. `reset()` restores the ambient defaults. `Window:ResetAppearance()` restores the glass/theme defaults separately.

## Configuration shape

```lua
{
    Version = 1,
    Appearance = {...},
    Values = {enabled = true, amount = 50, style = 0},
    Background = {...},
}
```

`ExportConfig` returns a table; encoding and persistence belong to the host. `ImportConfig(config)` restores user controls quietly. Pass `true` as the second argument to run their callbacks during restoration. Keybind configuration stores the bound key code.

Exported values include user controls and built-in setting controls; headings, labels, and buttons are omitted. Exported tables own their nested color arrays, so editing a saved configuration does not immediately alter the window. Recreate the same control IDs before importing. Unknown value IDs are ignored. Configuration version `1` is required for `Window:ImportConfig`.

For a host with JSON and file APIs, persistence can be added outside the library:

```lua
local HttpService = game:GetService("HttpService")
writefile("my-ui.json", HttpService:JSONEncode(Window:ExportConfig()))

local saved = HttpService:JSONDecode(readfile("my-ui.json"))
Window:ImportConfig(saved, false)
```

That example requires the host's `writefile` and `readfile`; the library does not automatically save files or contact a settings service.

## Host integration

The automatic update loop uses the host's render-step signal. A manual integration owns the scheduling:

```lua
local Window = Library:CreateWindow({ManualUpdate = true})

-- From your host's frame loop:
Window:Step(deltaTime)

-- From your host's mouse-wheel event:
Window:Scroll(wheelDelta, mouseX, mouseY)
```

The Roblox adapter uses native wheel input where `UserInputService.InputChanged` is available. Matcha wheel support requires an optional companion or another input source. The file bridge is enabled when Matcha has `readfile`, `writefile`, and `isfile`, unless `MatchaWheel = false`, `Singleton = false`, or a custom `ConsumeWheel` is supplied. Enabling the bridge writes coordination files; it does not start the companion. See [`adapters/matcha`](../adapters/matcha) for the separate Windows helper.

For a custom Drawing host, supply `Mouse`, input state readers, a viewport callback, and either a wheel consumer or direct `Scroll` calls:

```lua
local pendingWheel = 0
local pointer = {X = 0, Y = 0}

local Window = Library:CreateWindow({
    InputAdapter = "none",
    ManualUpdate = true,
    Drawing = MyDrawingBackend,
    Mouse = pointer,
    Viewport = function() return width, height end,
    IsKeyPressed = function(vk) return pressedKeys[vk] == true end,
    IsMousePressed = function() return primaryButtonDown end,
    Focused = function() return hostFocused end,
    Typing = function() return externalTextFieldActive end,
    ConsumeWheel = function()
        local delta = pendingWheel
        pendingWheel = 0
        return delta, pointer.X, pointer.Y
    end,
})

-- Update pointer and key/button states before the host's frame call.
Window:Step(deltaTime)
```

`MyDrawingBackend`, dimensions, key states, and focus variables are supplied by your host. Coordinates must use the same client-space origin as the Drawing backend. The Roblox adapter subtracts `GuiService:GetGuiInset()` from its pointer coordinates. Call `Scroll` after the first rendered frame, when scroll-region geometry is available. Scrolling pauses while the window is hidden, opening, unfocused, or external text entry is active.

## Lifecycle and diagnostics

Loading `Library.lua` creates no window by itself. Creating a singleton window destroys the previous window from this library. Reloading the library destroys windows created by the previous marked Thalassar UI instance. `Singleton = false` lets you manage several windows, but your host must coordinate their focus/input routing; the automatic Matcha file bridge is disabled for that mode.

Minimizing or calling `Hide()` keeps the window available and animates its visibility. Calling `Show()` or the configured show/hide key restores it. Clicking X or calling `Destroy()` removes drawings, disconnects render/input events, closes the optional bridge, and invokes `OnClose` once. A destroyed window is not reopened with `Show()`; create a new one. `Library:DestroyAll()` cleans up all windows belonging to the current library instance.

```lua
local state = Window:Status()
print(state.alive, state.visible, state.section, state.error)
print(state.inputAdapter, state.wheelSource, state.automaticUpdate)
```

`Status()` includes `name`, `alive`, `visible`, `minimized`, `section`, `drawings`, `error`, `width`, `height`, `opacity`, `animating`, `font`, `version`, `inputAdapter`, `wheelSource`, and `automaticUpdate`. `backdropBlur` is always `false`: the glass is a translucent Drawing composition. When the optional Matcha bridge is active, `state.wheel` contains the bridge session and received-event counters; those counters do not establish that a Windows helper is currently running.

`Window.UI` exposes the lower-level renderer and `Window.Effects` the ambient effect module. Prefer the window methods documented above for normal integration. `Window.SettingsSection` and `Window.BackgroundSection` can receive additional controls, using your own non-reserved IDs.
