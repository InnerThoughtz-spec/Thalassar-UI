# Matcha mouse wheel adapter

Matcha exposes mouse buttons and keys but no Lua mouse wheel event. This optional Windows companion supplies physical wheel detents to the UI library through three small workspace files. It requires Python 3.10 or newer and Windows.

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

Run the portable filtering/protocol checks with:

```powershell
python .\adapters\matcha\wheel_helper.py --self-test
```
