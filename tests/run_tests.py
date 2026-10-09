#!/usr/bin/env python3
"""Compile and exercise the built public library with offline native mocks.

Requires the official Luau CLI. Set LUAU_BIN and LUAU_COMPILE_BIN or pass
--luau-dir. The suite never imports integrated application or gameplay code.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def executable(name: str, directory: Path | None) -> str:
    override = os.environ.get("LUAU_COMPILE_BIN" if name == "luau-compile" else "LUAU_BIN")
    candidates = ([Path(override)] if override else [])
    if directory:
        candidates += [directory / name, directory / f"{name}.exe"]
    found = shutil.which(name)
    if found:
        candidates.append(Path(found))
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate.resolve())
    raise SystemExit(f"Missing {name}; pass --luau-dir or set the corresponding executable environment variable.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau-dir", type=Path, help="Directory containing luau and luau-compile")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    library = root / "Library.lua"
    if not library.is_file():
        raise SystemExit("Library.lua is missing; build the public library first.")
    luau = executable("luau", args.luau_dir)
    compiler = executable("luau-compile", args.luau_dir)
    # The wrapper gives the distribution lexical access to the offline bindings.
    # It also works on Matcha-style runtimes that discard loadstring return values.
    mock = (root / "tests" / "mock_runtime.lua").read_text(encoding="utf-8")
    spec = (root / "tests" / "library_spec.lua").read_text(encoding="utf-8")
    prefix = mock + "\nlocal Library = (function()\n" + library.read_text(encoding="utf-8") + "\nend)()\n"
    harness = prefix + spec
    with tempfile.TemporaryDirectory(prefix="thalassar-tests-") as scratch:
        composed = Path(scratch) / "library_tests.lua"
        composed.write_text(harness, encoding="utf-8")
        for label, path in (("distribution", library), ("test harness", composed)):
            result = subprocess.run([compiler, "--null", "-O0", str(path)], capture_output=True, text=True)
            if result.returncode:
                raise SystemExit(result.stderr or result.stdout)
            print(f"PASS: {label} compiles", flush=True)
        subprocess.run([luau, str(composed)], check=True)
        # Exercise the real public demo body; bypass only its remote HTTP loader.
        demo = (root / "examples" / "demo.lua").read_text(encoding="utf-8")
        marker = "local Library = assert(_G.ThalassarUI"
        if marker not in demo:
            raise SystemExit("The demo loader boundary changed; update the offline smoke harness.")
        demo = demo[demo.index(marker):]
        smoke = Path(scratch) / "demo_smoke.lua"
        smoke.write_text(prefix + demo + r'''
local demo = assert(_G.ThalassarDemo, "demo did not expose its cleanup handle")
for _ = 1, 24 do Runtime.time += 1 / 60; Runtime.render:Fire(1 / 60) end
assert(not demo:Status().error, demo:Status().error)
assert(demo:Status().section == "Controls", "demo did not select its user controls")
assert(demo:GetValue("amount") == 50 and demo:GetValue("style") == 0, "demo controls did not initialize")
assert(demo:ScrollRegions().page.max > 0, "demo did not render its scrolling fixture")
demo:Destroy()
assert(Runtime.removed == Runtime.made and Runtime.connectedCount() == 0, "demo resources were not cleaned up")
print("PASS: public demo renders and cleans up offline")
''', encoding="utf-8")
        subprocess.run([luau, str(smoke)], check=True)


if __name__ == "__main__":
    main()
