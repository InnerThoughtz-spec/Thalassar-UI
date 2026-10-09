"""Capture physical Roblox wheel events only while a Thalassar menu lease is valid."""
from __future__ import annotations

import argparse
import ctypes
import math
import os
from pathlib import Path
import sys
import time
import re

FILE_PREFIX = "Thalassar-UI"
from dataclasses import dataclass


@dataclass(frozen=True)
class Lease:
    session: str
    opened: bool
    left: float
    top: float
    width: float
    height: float
    expires: float

    @classmethod
    def parse(cls, text: str) -> "Lease | None":
        parts = text.strip().split("|")
        if len(parts) != 8 or parts[0] != "run" or not parts[1] or parts[2] not in ("0", "1"):
            return None
        try:
            values = tuple(float(value) for value in parts[3:])
        except ValueError:
            return None
        if not all(math.isfinite(value) for value in values) or values[2] <= 0 or values[3] <= 0:
            return None
        return cls(parts[1], parts[2] == "1", *values)

    def accepts(self, now: float, x: float, y: float, roblox: bool, injected: bool) -> bool:
        return (self.opened and now <= self.expires and roblox and not injected
                and self.left <= x < self.left + self.width
                and self.top <= y < self.top + self.height)


class Bridge:
    def __init__(self, workspace: Path, clock=time.time):
        self.workspace = workspace
        self.lease_path = workspace / f"{FILE_PREFIX}.wheel-lease.txt"
        self.output_path = workspace / f"{FILE_PREFIX}.wheel.txt"
        self.status_path = workspace / f"{FILE_PREFIX}.wheel-status.txt"
        self.clock = clock
        self.started = clock()
        self.generation = f"{os.getpid()}-{time.time_ns()}"
        self.lease: Lease | None = None
        self.seq = 0
        self.total = 0.0
        self.x = self.y = 0.0
        self.event_epoch = self.started
        self.dirty = False
        self.stopped = False

    def update_lease(self, text: str) -> None:
        parts = text.strip().split("|")
        if len(parts) == 2 and parts[0] == "stop":
            if self.lease and parts[1] == self.lease.session:
                self.stopped = True
            return
        candidate = Lease.parse(text)
        if candidate is None or candidate.expires < self.clock():
            return
        if not self.lease or candidate.session != self.lease.session:
            self.seq, self.total, self.x, self.y = 0, 0.0, 0.0, 0.0
            self.event_epoch = self.clock()
            self.dirty = True
        self.lease = candidate

    def refresh(self) -> None:
        try:
            self.update_lease(self.lease_path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError):
            pass

    def expired(self) -> bool:
        now = self.clock()
        return (self.stopped or (self.lease is None and now - self.started >= 20)
                or (self.lease is not None and now > self.lease.expires + 10))

    def wheel(self, delta: int, x: float, y: float, roblox: bool, injected: bool) -> bool:
        now = self.clock()
        if self.stopped or not self.lease or not self.lease.accepts(now, x, y, roblox, injected) or delta == 0:
            return False
        self.seq += 1
        self.total += delta / 120.0
        self.x, self.y, self.event_epoch = x, y, now
        self.dirty = True
        return True

    def write(self) -> None:
        if not self.dirty or not self.lease:
            return
        line = f"2|{self.lease.session}|{self.generation}|{self.seq}|{self.total:.9g}|{self.x:.9g}|{self.y:.9g}|{self.event_epoch:.6f}"
        temporary = self.output_path.with_suffix(f".tmp-{os.getpid()}")
        try:
            temporary.write_text(line, encoding="utf-8")
            os.replace(temporary, self.output_path)
            self.dirty = False
        except OSError:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass

    def status(self, state: str) -> None:
        try:
            session = self.lease.session if self.lease else "waiting"
            self.status_path.write_text(f"{state}|{session}|{os.getpid()}", encoding="utf-8")
        except OSError:
            pass


def run_windows(bridge: Bridge) -> int:
    from ctypes import wintypes

    user = ctypes.WinDLL("user32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    lresult = ctypes.c_ssize_t
    wparam = ctypes.c_size_t
    lparam = ctypes.c_ssize_t
    hook_proc_type = ctypes.WINFUNCTYPE(lresult, ctypes.c_int, wparam, lparam)

    class MouseInfo(ctypes.Structure):
        _fields_ = [("pt", wintypes.POINT), ("mouseData", wintypes.DWORD),
                    ("flags", wintypes.DWORD), ("time", wintypes.DWORD),
                    ("extra", ctypes.c_size_t)]

    kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    kernel.GetModuleHandleW.argtypes = [wintypes.LPCWSTR]
    kernel.GetModuleHandleW.restype = wintypes.HMODULE
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD,
                                                wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    kernel.QueryFullProcessImageNameW.restype = wintypes.BOOL
    user.SetWindowsHookExW.argtypes = [ctypes.c_int, hook_proc_type, wintypes.HINSTANCE, wintypes.DWORD]
    user.SetWindowsHookExW.restype = ctypes.c_void_p
    user.CallNextHookEx.argtypes = [ctypes.c_void_p, ctypes.c_int, wparam, lparam]
    user.CallNextHookEx.restype = lresult
    user.UnhookWindowsHookEx.argtypes = [ctypes.c_void_p]
    user.UnhookWindowsHookEx.restype = wintypes.BOOL
    user.GetForegroundWindow.argtypes = []
    user.GetForegroundWindow.restype = wintypes.HWND
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.GetWindowThreadProcessId.restype = wintypes.DWORD
    user.ScreenToClient.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.POINT)]
    user.ScreenToClient.restype = wintypes.BOOL
    user.SetTimer.argtypes = [wintypes.HWND, ctypes.c_size_t, wintypes.UINT, ctypes.c_void_p]
    user.SetTimer.restype = ctypes.c_size_t
    user.KillTimer.argtypes = [wintypes.HWND, ctypes.c_size_t]
    user.KillTimer.restype = wintypes.BOOL
    user.GetMessageW.argtypes = [ctypes.POINTER(wintypes.MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT]
    user.GetMessageW.restype = wintypes.BOOL
    user.TranslateMessage.argtypes = [ctypes.POINTER(wintypes.MSG)]
    user.TranslateMessage.restype = wintypes.BOOL
    user.DispatchMessageW.argtypes = [ctypes.POINTER(wintypes.MSG)]
    user.DispatchMessageW.restype = lresult

    mutex = kernel.CreateMutexW(None, False, "Local\\ThalassarUIWheelBridge-" + FILE_PREFIX)
    if not mutex:
        raise ctypes.WinError(ctypes.get_last_error())
    if ctypes.get_last_error() == 183:
        kernel.CloseHandle(mutex)
        return 10  # Another active reader owns the hook; the watcher backs off.

    hook = None
    timer = 0
    process_cache: dict[int, tuple[float, bool]] = {}

    def foreground_roblox():
        window = user.GetForegroundWindow()
        if not window:
            return None
        pid = wintypes.DWORD()
        user.GetWindowThreadProcessId(window, ctypes.byref(pid))
        now = time.monotonic()
        cached = process_cache.get(pid.value)
        if cached is None or now - cached[0] > 2:
            handle = kernel.OpenProcess(0x1000, False, pid.value)
            result = False
            if handle:
                try:
                    buffer = ctypes.create_unicode_buffer(32768)
                    length = wintypes.DWORD(len(buffer))
                    if kernel.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(length)):
                        result = Path(buffer.value).name.lower() == "robloxplayerbeta.exe"
                finally:
                    kernel.CloseHandle(handle)
            process_cache.clear()
            process_cache[pid.value] = now, result
            cached = now, result
        return window if cached[1] else None

    def callback(code, message, pointer):
        try:
            if code >= 0 and message == 0x020A and not bridge.expired():
                data = ctypes.cast(pointer, ctypes.POINTER(MouseInfo)).contents
                # Discard injected events. Only the native mouse wheel is captured.
                if not (data.flags & 0x03):
                    window = foreground_roblox()
                    if window:
                        point = wintypes.POINT(data.pt.x, data.pt.y)
                        if user.ScreenToClient(window, ctypes.byref(point)):
                            delta = ctypes.c_short((data.mouseData >> 16) & 0xFFFF).value
                            if bridge.wheel(delta, point.x, point.y, True, False):
                                return 1  # Prevent camera zoom only over the leased menu.
        except Exception:
            # A callback exception must never skip the downstream hook chain.
            pass
        return user.CallNextHookEx(hook, code, message, pointer)

    callback_ref = hook_proc_type(callback)
    try:
        if hasattr(user, "SetProcessDpiAwarenessContext"):
            user.SetProcessDpiAwarenessContext.argtypes = [ctypes.c_void_p]
            user.SetProcessDpiAwarenessContext.restype = wintypes.BOOL
            user.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
        bridge.refresh()
        hook = user.SetWindowsHookExW(14, callback_ref, kernel.GetModuleHandleW(None), 0)
        if not hook:
            raise ctypes.WinError(ctypes.get_last_error())
        timer = user.SetTimer(None, 0, 25, None)
        if not timer:
            raise ctypes.WinError(ctypes.get_last_error())
        bridge.status("ready")
        bridge.write()
        next_lease_refresh = time.monotonic() + .1
        message = wintypes.MSG()
        while not bridge.expired():
            result = user.GetMessageW(ctypes.byref(message), None, 0, 0)
            if result == -1:
                raise ctypes.WinError(ctypes.get_last_error())
            if result == 0:
                break
            if message.message == 0x0113:
                now = time.monotonic()
                if now >= next_lease_refresh:
                    previous_session = bridge.lease.session if bridge.lease else None
                    bridge.refresh()
                    next_lease_refresh = now + .1
                    current_session = bridge.lease.session if bridge.lease else None
                    if current_session != previous_session:
                        bridge.status("ready")
                bridge.write()
            else:
                user.TranslateMessage(ctypes.byref(message))
                user.DispatchMessageW(ctypes.byref(message))
        bridge.status("stopped")
        return 0
    finally:
        if timer:
            user.KillTimer(None, timer)
        if hook:
            user.UnhookWindowsHookEx(hook)
        kernel.CloseHandle(mutex)


def fresh_lease(workspace: Path, now: float) -> Lease | None:
    try:
        lease = Lease.parse((workspace / f"{FILE_PREFIX}.wheel-lease.txt").read_text(encoding="utf-8-sig"))
        return lease if lease and lease.expires >= now else None
    except (OSError, UnicodeError):
        return None


def watch_windows(workspace: Path) -> int:
    """Wait without an input hook; attach when ordinary Lua execution opens a lease."""
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    mutex = kernel.CreateMutexW(None, False, "Local\\ThalassarUIWheelWatcher-" + FILE_PREFIX)
    if not mutex:
        raise ctypes.WinError(ctypes.get_last_error())
    if ctypes.get_last_error() == 183:
        kernel.CloseHandle(mutex)
        return 0
    idle = False
    try:
        while True:
            if fresh_lease(workspace, time.time()) is None:
                if not idle:
                    Bridge(workspace).status("idle")
                    idle = True
                time.sleep(.3)
                continue
            idle = False
            try:
                run_windows(Bridge(workspace))
                time.sleep(.3)
            except Exception as error:
                try:
                    (workspace / f"{FILE_PREFIX}.wheel-status.txt").write_text(
                        f"error|{type(error).__name__}|{error}", encoding="utf-8")
                except OSError:
                    pass
                time.sleep(2)
    finally:
        kernel.CloseHandle(mutex)


def self_test() -> None:
    import tempfile
    clock_value = [100.0]
    with tempfile.TemporaryDirectory() as temporary:
        bridge = Bridge(Path(temporary), clock=lambda: clock_value[0])
        assert Lease.parse("bad") is None
        assert Lease.parse("run|test|1|nan|0|100|100|105") is None
        bridge.update_lease("run|one|1|10|20|100|80|105")
        assert bridge.wheel(60, 20, 30, True, False)
        assert bridge.wheel(-120, 20, 30, True, False)
        assert (bridge.seq, bridge.total) == (2, -.5)
        for x, y, roblox, injected in [(9, 30, True, False), (110, 30, True, False),
                                      (20, 100, True, False), (20, 30, False, False),
                                      (20, 30, True, True)]:
            assert not bridge.wheel(120, x, y, roblox, injected)
        bridge.write()
        assert bridge.output_path.read_text().startswith(f"2|one|{bridge.generation}|2|-0.5|20|30|")
        assert not list(Path(temporary).glob("*.tmp-*"))
        bridge.update_lease("run|one|0|10|20|100|80|105")
        assert not bridge.wheel(120, 20, 30, True, False)
        bridge.update_lease("run|two|1|10|20|100|80|105")
        assert (bridge.seq, bridge.total) == (0, 0)
        bridge.update_lease("stop|one")
        assert not bridge.stopped
        clock_value[0] = 106
        assert not bridge.wheel(120, 20, 30, True, False)
        assert not bridge.expired()
        clock_value[0] = 116
        assert bridge.expired()
        bridge.update_lease("run|two|1|10|20|100|80|120")
        bridge.update_lease("stop|two")
        assert bridge.expired()
        fresh = Bridge(Path(temporary), clock=lambda: clock_value[0])
        clock_value[0] += 20
        assert fresh.expired()
        workspace = Path(temporary)
        assert fresh_lease(workspace, clock_value[0]) is None
        bridge.lease_path.write_text("run|auto|1|0|0|500|500|200", encoding="utf-8")
        assert fresh_lease(workspace, 199).session == "auto"
        assert fresh_lease(workspace, 201) is None
        bridge.lease_path.write_text("stop|auto", encoding="utf-8")
        assert fresh_lease(workspace, 199) is None
    print("Wheel bridge filtering, fractional accumulation, session, atomic output and shutdown checks passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, default=Path(r"C:\matcha\workspace"))
    parser.add_argument("--prefix", default="Thalassar-UI", help="Match the Lua WheelFilePrefix option")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--watch", action="store_true", help="Reconnect automatically after Lua reloads; idle without a hook between runs")
    arguments = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", arguments.prefix):
        parser.error("Prefix must contain only letters, digits, underscores or dashes")
    FILE_PREFIX = arguments.prefix
    if arguments.self_test:
        self_test()
    elif os.name != "nt":
        parser.error("The input helper requires Windows")
    else:
        try:
            workspace = arguments.workspace.resolve()
            sys.exit(watch_windows(workspace) if arguments.watch else run_windows(Bridge(workspace)))
        except Exception as error:
            try:
                (arguments.workspace / f"{FILE_PREFIX}.wheel-status.txt").write_text(
                    f"error|{type(error).__name__}|{error}", encoding="utf-8")
            except OSError:
                pass
            raise
