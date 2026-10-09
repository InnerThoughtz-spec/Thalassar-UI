# API reference

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

## Navigation

```lua
local Tab = Window:Tab("General")
local Section = Tab:Section("Controls")
```

Tab names are used to build navigation groups dynamically. Sections contain controls in insertion order. The built-in sections are exposed as `Window.BackgroundSection` and `Window.SettingsSection`.

## Controls

Controls accept unique IDs. IDs are used by `GetValue`, `SetValue`, and configuration import/export. User interactions call the supplied callback; programmatic `SetValue` calls are quiet. Avoid the `thalassar_` prefix, which is used by built-in controls.

### Toggle

```lua
Section:Toggle(id, title, default, callback)
Section:Toggle({Id = id, Title = title, Default = default, Callback = callback})
```

`default` and the callback value are booleans.

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

### Dropdown and Combo

```lua
Section:Dropdown(id, title, items, defaultIndex, callback)
Section:Combo(id, title, items, defaultIndex, callback)
```

`items` is an array of labels. Both methods use **zero-based** selection indexes: the first item is `0`. The callback receives the selected index.

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

### Button

```lua
Section:Button({Id = "action", Title = "Run action", Callback = function() end})
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
```

Key codes are Windows virtual-key values. Toggle bindings switch their active state on a key press; hold bindings follow whether the key is held. The callback receives the active state and current key code when the active state changes or a key is rebound. User bindings activate while the UI is hidden, so editing the menu does not trigger them.

### InputText

```lua
Section:InputText({
    Id = "name",
    Title = "Name",
    Default = "Preview",
    Callback = function(value) end,
})
```

Click the field to edit. Enter commits the value, Escape cancels the edit, and Backspace removes a character. Text entry uses basic Windows virtual-key characters with a 120-character limit.

### Heading and Label

```lua
Section:Heading("Group heading")
Section:Label("Informational text")
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

`Section:Tip(text)` attaches a tooltip to the most recently added control. Table-form controls also accept `Hidden`, `Enabled`, and `Tooltip` options.

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
