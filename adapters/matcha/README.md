# Matcha mouse wheel adapter

Matcha exposes mouse buttons and keys but no Lua mouse wheel event. This optional Windows companion supplies physical wheel detents to the UI library through three small workspace files. It requires Python 3.10 or newer and Windows.

The [single-loadstring demo](../../Demo.lua) opens without this companion. You can drag the scrollbar or use Page Up/Page Down while the pointer is over the content/sidebar. For physical wheel input in Matcha, start the companion separately.

## Setup

Download the repository or clone it:

```powershell
git clone https://github.com/InnerThoughtz-spec/Thalassar-UI.git
Set-Location -LiteralPath .\Thalassar-UI
```

From a downloaded or cloned copy of this repository, run:

```powershell
.\adapters\matcha\Start-WheelHelper.ps1 -WorkspacePath 'C:\matcha\workspace'
```

If Python is not on PATH, also pass `-PythonPath 'C:\path\to\python.exe'`.

The default launcher watches for UI sessions and reconnects when the library window is recreated. It runs a hidden Python process and does not install a Startup entry or modify the game. Use `-Once` for a helper that exits after the current UI session ends. The launcher prints its process ID; stop it with `Stop-Process -Id <that-ID>` when no longer needed.

The helper attaches a mouse hook only for a fresh library lease. It accepts non-injected wheel events while Roblox is foreground and the pointer is inside the open UI window. It does not capture keyboard input. An expired or closed lease disables capture; an expired session removes the hook. While the menu is open, accepted wheel events are consumed to avoid camera zoom over the window.

The library uses this adapter automatically in Matcha when the file APIs are available and `Singleton` is enabled. Loading the library alone does not launch the companion. Set `MatchaWheel = false` to disable the file bridge, or provide `ConsumeWheel` for your own host adapter.

Files use the default prefix `Thalassar-UI`. This is independent of other programs' UI companions. If you set `WheelFilePrefix` in `CreateWindow`, pass the same value as `-Prefix` to this launcher. Multiple independently managed windows should use a custom `ConsumeWheel` adapter to route input to the window under the pointer.

Positive wheel deltas scroll upward. Coordinates use the same client-space convention as the UI's `Mouse` object.

## Custom prefix

The Lua window and the helper must share their prefix:

```lua
local Window = Library:CreateWindow({
    Title = "My interface",
    WheelFilePrefix = "My-Interface",
})
```

```powershell
.\adapters\matcha\Start-WheelHelper.ps1 -WorkspacePath 'C:\matcha\workspace' -Prefix 'My-Interface'
```

Prefix names may contain letters, digits, underscores, and dashes. The supplied demo uses the default `Thalassar-UI` prefix. Use one helper for a given prefix.

## Troubleshooting

1. Keep Roblox foreground, the UI open, and the pointer over its scrollable content or sidebar. Wheel events outside the window are left to Roblox.
2. Check that `-WorkspacePath` points to the same workspace used by Matcha's Lua `readfile`/`writefile` APIs. Check that `-Prefix` matches the Lua `WheelFilePrefix`.
3. Check the PID printed by the launcher with `Get-Process -Id <that-ID>`. Restart the launcher if that process has exited. Its `--watch` mode follows new UI sessions while it is running; it does not install a Windows service or a crash supervisor.
4. Inspect `Window:Status().wheel` in your own interface. A changing `sequence` means the Lua bridge has read new helper events. `wheelSource = "matcha companion"` describes the configured source and does not prove the helper is running.
5. If the Matcha Lua runtime stops updating, its lease expires and the helper stops accepting events. Restore the runtime and rerun the UI if needed; the companion cannot resume a halted Lua script.

The default files are `Thalassar-UI.wheel-lease.txt`, `Thalassar-UI.wheel.txt`, and `Thalassar-UI.wheel-status.txt`. The lease coordinates and expiry are written by the UI, wheel packets by the helper. The helper's status file is useful for identifying its session/PID; it is not a continuously refreshed heartbeat.

## Protocol checks

Run the portable filtering/protocol checks with:

```powershell
python .\adapters\matcha\wheel_helper.py --self-test
```

These portable checks exercise event filtering and protocol behavior. Verify actual mouse-wheel behavior in the target Windows/Matcha session as well.
