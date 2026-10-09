#!/usr/bin/env python3
"""Render the public library's native Drawing output on a neutral backdrop.

This is an offline illustration, not a screenshot from Matcha or Roblox.
Requires the official Luau CLI and Pillow. No application source is imported.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont


DEMO = r'''
local ui = Library:CreateWindow({Title = "Thalassar UI", ManualUpdate = true,
    InputAdapter = "none", Mouse = Runtime.mouse, Viewport = function() return 1440, 900 end,
    IsKeyPressed = iskeypressed, IsMousePressed = ismouse1pressed,
    Focused = function() return true end})
local controls = ui:Tab("General"):Section("Controls")
controls:Toggle("enabled", "Enable notifications", true)
controls:SliderInt("volume", "Volume", 0, 100, 65)
controls:SliderFloat("opacity", "Panel opacity", 0, 1, .64, "%.2f")
controls:Dropdown("quality", "Quality", {"Low", "Medium", "High"}, 2)
controls:ColorPicker({Id = "accent", Title = "Accent color", Default = {147, 171, 182, 255}})
controls:InputText("profile", "Profile name", "Default")
controls:Button("apply", "Apply settings", function() end)
local tools = ui:Tab("Utilities"):Section("Shortcuts")
tools:Keybind("shortcut", "Shortcut", 0x75)
tools:Label("hint", "Use the menu key to show or hide the window.")
ui:SelectSection("Controls")
for _ = 1, 40 do ui:Step(1 / 60) end
assert(not ui:Status().error, ui:Status().error)
local function quoted(value)
    return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
end
local function encode(value)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" or kind == "number" then return tostring(value) end
    if kind == "string" then return quoted(value) end
    if value.R and value.G and value.B then
        return "[" .. math.floor(value.R * 255 + .5) .. "," .. math.floor(value.G * 255 + .5) .. "," .. math.floor(value.B * 255 + .5) .. "]"
    end
    local fields = {}
    for key, child in pairs(value) do
        if type(child) ~= "function" then fields[#fields + 1] = quoted(key) .. ":" .. encode(child) end
    end
    return "{" .. table.concat(fields, ",") .. "}"
end
for _, record in ipairs(Runtime.drawings) do
    if not record.dead and record.properties.Visible then
        print("DRAWJSON " .. encode({kind = record.kind, props = record.properties}))
    end
end
ui:Destroy()
assert(Runtime.removed == Runtime.made, "preview drawings were not cleaned up")
'''


def point(value: dict) -> tuple[float, float]:
    return float(value.get("X", 0)), float(value.get("Y", 0))


def font(size: float, bold: bool) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    options = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in options:
        if Path(path).is_file():
            return ImageFont.truetype(path, max(8, round(size)))
    return ImageFont.load_default(size=max(8, round(size)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau-dir", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    luau = os.environ.get("LUAU_BIN") or shutil.which("luau")
    if args.luau_dir:
        for name in ("luau", "luau.exe"):
            candidate = args.luau_dir / name
            if candidate.is_file():
                luau = str(candidate.resolve())
                break
    if not luau:
        raise SystemExit("Missing Luau CLI; pass --luau-dir or set LUAU_BIN.")
    output = args.output or root / "docs" / "preview.png"
    mock = (root / "tests" / "mock_runtime.lua").read_text(encoding="utf-8")
    library = (root / "Library.lua").read_text(encoding="utf-8")
    fixture = mock + "\nlocal Library = (function()\n" + library + "\nend)()\n" + DEMO
    with tempfile.TemporaryDirectory(prefix="thalassar-preview-") as scratch:
        script = Path(scratch) / "preview.lua"
        script.write_text(fixture, encoding="utf-8")
        result = subprocess.run([luau, str(script)], capture_output=True, text=True, check=True)
    records = [json.loads(line[9:]) for line in result.stdout.splitlines() if line.startswith("DRAWJSON ")]
    image = Image.new("RGBA", (1440, 900), (43, 49, 53, 255))
    backdrop = ImageDraw.Draw(image)
    for x in range(0, 1440, 96):
        backdrop.line((x, 0, x, 900), fill=(53, 61, 65, 255))
    for y in range(0, 900, 96):
        backdrop.line((0, y, 1440, y), fill=(53, 61, 65, 255))
    backdrop.rounded_rectangle((65, 165, 420, 735), 40, fill=(62, 75, 79, 255))
    backdrop.rounded_rectangle((1080, 275, 1380, 755), 40, fill=(35, 43, 49, 255))
    font_cache = {}
    for record in sorted(records, key=lambda item: item["props"].get("ZIndex", 0)):
        properties, kind = record["props"], record["kind"]
        opacity = max(0, min(1, properties.get("Transparency", 1)))
        color = tuple(round(channel) for channel in properties.get("Color", [255, 255, 255])) + (round(opacity * 255),)
        layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        width = max(1, round(properties.get("Thickness", 1)))
        fill, outline = (color, None) if properties.get("Filled") else (None, color)
        if kind == "Square":
            x, y = point(properties["Position"])
            w, h = point(properties["Size"])
            radius = max(0, min(properties.get("Corner", 0), w / 2, h / 2))
            draw.rounded_rectangle((x, y, x + w, y + h), radius, fill=fill, outline=outline, width=width)
        elif kind == "Circle":
            x, y = point(properties["Position"])
            radius = properties["Radius"]
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill, outline=outline, width=width)
        elif kind == "Line":
            draw.line((*point(properties["From"]), *point(properties["To"])), fill=color, width=width)
        elif kind == "Triangle":
            draw.polygon([point(properties[key]) for key in ("PointA", "PointB", "PointC")], fill=color)
        elif kind == "Text":
            key = (properties.get("Size", 14), properties.get("Font") == 2)
            if key not in font_cache:
                font_cache[key] = font(*key)
            x, y = point(properties["Position"])
            draw.text((x, y - 2), properties.get("Text", ""), font=font_cache[key], fill=color)
        image = Image.alpha_composite(image, layer)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(output)
    print(f"Rendered {len(records)} native Drawing primitives to {output}")


if __name__ == "__main__":
    main()
