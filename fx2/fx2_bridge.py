#!/usr/bin/env python3
"""Python bridge for MK61 FX2 firmware protocol."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

import usb.core
import usb.util

try:
    from .fx2_loader import BOOT_PID, BOOT_VID, LoaderError, RUNTIME_PID, RUNTIME_VID, load_firmware
except ImportError:
    from fx2_loader import BOOT_PID, BOOT_VID, LoaderError, RUNTIME_PID, RUNTIME_VID, load_firmware

VR_GET_INFO = 0xB0
VR_SET_CONTROL = 0xB1
VR_STEP = 0xB2
VR_QUEUE_BUTTON = 0xB3
VR_GET_STATE = 0xB4
VR_SET_HOLD = 0xB5
VR_CLEAR_FRAME = 0xB6

CTRL_RST = 1 << 0
CTRL_MODE0 = 1 << 1
CTRL_MODE1 = 1 << 2
CTRL_DIRECT_MODE = 1 << 3
CTRL_DIRECT_K1 = 1 << 4
CTRL_DIRECT_K2 = 1 << 5
CTRL_USE_SCAN_GATE = 1 << 6
CTRL_AUTO_K2 = 1 << 7

MODE_MAP = {"rad": 0, "deg": 1, "grd": 2}
EMU_SEGMENTS = "0123456789-LCrE "


class BridgeError(RuntimeError):
    pass


@dataclass
class FX2State:
    protocol: int
    fw_major: int
    flags: int
    ctrl_bits: int
    hold_cycles: int
    dcycle: int
    segment: int
    frame_counter: int
    pending_row: int
    pending_col: int
    active_row: int
    active_hold: int
    scan_active: int
    display: List[int]

    @property
    def pending(self) -> bool:
        return bool((self.flags & 0x01) or (self.active_hold != 0))

    @property
    def sync(self) -> int:
        return 1 if (self.flags & (1 << 5)) else 0


def decode_segment(seg: int) -> str:
    idx = seg & 0x0F
    ch = EMU_SEGMENTS[idx] if 0 <= idx < len(EMU_SEGMENTS) else "?"
    return f"{ch}." if (seg & 0x80) else ch


def render_display_emu145(display: List[int]) -> str:
    out: List[str] = []
    for i in range(9):
        out.append(decode_segment(display[8 - i]))
    for i in range(3):
        out.append(decode_segment(display[11 - i]))
    return " ".join(out)


class FX2MK61Bridge:
    def __init__(
        self,
        *,
        runtime_vid: int = RUNTIME_VID,
        runtime_pid: int = RUNTIME_PID,
        timeout_ms: int = 3000,
    ) -> None:
        self.runtime_vid = runtime_vid
        self.runtime_pid = runtime_pid
        self.timeout_ms = timeout_ms
        self.dev = None
        self.ctrl_bits = CTRL_RST | CTRL_USE_SCAN_GATE | CTRL_AUTO_K2

    def connect(self) -> None:
        try:
            dev = usb.core.find(idVendor=self.runtime_vid, idProduct=self.runtime_pid)
        except usb.core.NoBackendError as exc:
            raise BridgeError(
                "PyUSB backend not found. Install libusb (e.g. 'brew install libusb') "
                "and ensure pyusb can load it."
            ) from exc
        if dev is None:
            raise BridgeError(f"Runtime device not found: {self.runtime_vid:04x}:{self.runtime_pid:04x}")

        try:
            if dev.is_kernel_driver_active(0):
                dev.detach_kernel_driver(0)
        except Exception:
            pass

        try:
            dev.set_configuration()
        except Exception:
            pass

        self.dev = dev

    def close(self) -> None:
        if self.dev is not None:
            try:
                usb.util.dispose_resources(self.dev)
            except Exception:
                pass
            self.dev = None

    def ensure_runtime(self, *, ihx_path: Path, force_reload: bool = False, timeout_s: float = 5.0) -> None:
        try:
            vid, pid = load_firmware(
                ihx_path=ihx_path,
                boot_vid=BOOT_VID,
                boot_pid=BOOT_PID,
                runtime_vid=self.runtime_vid,
                runtime_pid=self.runtime_pid,
                timeout_s=timeout_s,
                force=force_reload,
            )
        except LoaderError as exc:
            raise BridgeError(str(exc)) from exc

        self.runtime_vid = vid
        self.runtime_pid = pid
        self.connect()

    def _require_dev(self):
        if self.dev is None:
            raise BridgeError("Device is not connected")
        return self.dev

    def _ctrl_out(self, req: int, *, value: int = 0, index: int = 0) -> None:
        dev = self._require_dev()
        try:
            dev.ctrl_transfer(0x40, req, value & 0xFFFF, index & 0xFFFF, b"", timeout=self.timeout_ms)
        except usb.core.USBError as exc:
            raise BridgeError(f"USB OUT request 0x{req:02X} failed: {exc}") from exc

    def _ctrl_in(self, req: int, *, value: int = 0, index: int = 0, length: int = 64) -> bytes:
        dev = self._require_dev()
        try:
            data = dev.ctrl_transfer(0xC0, req, value & 0xFFFF, index & 0xFFFF, length, timeout=self.timeout_ms)
        except usb.core.USBError as exc:
            raise BridgeError(f"USB IN request 0x{req:02X} failed: {exc}") from exc
        return bytes(data)

    @staticmethod
    def _parse_state(data: bytes) -> FX2State:
        if len(data) < 26:
            raise BridgeError(f"Short state packet: {len(data)} bytes")

        return FX2State(
            protocol=data[0],
            fw_major=data[1],
            flags=data[2],
            ctrl_bits=data[3],
            hold_cycles=data[4],
            dcycle=data[5],
            segment=data[6],
            frame_counter=data[7] | (data[8] << 8),
            pending_row=data[9],
            pending_col=data[10],
            active_row=data[11],
            active_hold=data[12],
            scan_active=data[13],
            display=list(data[14:26]),
        )

    def get_state(self) -> FX2State:
        data = self._ctrl_in(VR_GET_STATE, length=32)
        st = self._parse_state(data)
        self.ctrl_bits = st.ctrl_bits
        return st

    def get_info(self) -> FX2State:
        data = self._ctrl_in(VR_GET_INFO, length=32)
        st = self._parse_state(data)
        self.ctrl_bits = st.ctrl_bits
        return st

    def set_hold_cycles(self, hold_cycles: int) -> None:
        hold = max(1, min(int(hold_cycles), 255))
        self._ctrl_out(VR_SET_HOLD, value=hold)

    def set_control_bits(self, bits: int) -> None:
        self.ctrl_bits = bits & 0xFF
        self._ctrl_out(VR_SET_CONTROL, value=self.ctrl_bits)

    def set_mode(
        self,
        mode: str,
        *,
        rst: bool = False,
        use_scan_gate: bool = True,
        auto_k2: bool = True,
    ) -> None:
        mode_l = mode.strip().lower()
        if mode_l not in MODE_MAP:
            raise BridgeError(f"Unsupported mode '{mode}', expected rad/deg/grd")

        mode_id = MODE_MAP[mode_l]
        bits = 0
        if rst:
            bits |= CTRL_RST
        bits |= (mode_id << 1) & (CTRL_MODE0 | CTRL_MODE1)
        if use_scan_gate:
            bits |= CTRL_USE_SCAN_GATE
        if auto_k2:
            bits |= CTRL_AUTO_K2

        self.set_control_bits(bits)

    def queue_button(self, row: int, col: int) -> None:
        if not (1 <= row <= 3):
            raise BridgeError(f"row must be 1..3, got {row}")
        if not (0 <= col <= 9):
            raise BridgeError(f"col must be 0..9, got {col}")
        value = ((col & 0xFF) << 8) | (row & 0xFF)
        self._ctrl_out(VR_QUEUE_BUTTON, value=value)

    def clear_button(self) -> None:
        self._ctrl_out(VR_QUEUE_BUTTON, value=0)

    def clear_frame_counter(self) -> None:
        self._ctrl_out(VR_CLEAR_FRAME)

    def step(self, cycles: int) -> FX2State:
        remaining = max(1, int(cycles))
        last: Optional[FX2State] = None
        while remaining > 0:
            chunk = min(remaining, 0xFFFF)
            data = self._ctrl_in(VR_STEP, value=chunk, length=32)
            last = self._parse_state(data)
            self.ctrl_bits = last.ctrl_bits
            remaining -= chunk

        if last is None:
            raise BridgeError("step() internal error")
        return last

    @staticmethod
    def _frame_delta(cur: int, base: int) -> int:
        return (cur - base) & 0xFFFF

    def wait_frames(self, frames: int, *, step_chunk: int = 4000, max_cycles: int = 2_000_000) -> FX2State:
        target_frames = max(0, int(frames))
        if target_frames == 0:
            return self.get_state()

        st = self.get_state()
        base = st.frame_counter
        used = 0

        while used < max_cycles:
            if self._frame_delta(st.frame_counter, base) >= target_frames:
                return st
            chunk = min(step_chunk, max_cycles - used)
            st = self.step(chunk)
            used += chunk

        raise BridgeError(
            f"Timeout waiting for {target_frames} frame(s): got {self._frame_delta(st.frame_counter, base)}"
        )

    def press_button(
        self,
        row: int,
        col: int,
        *,
        step_chunk: int = 2000,
        timeout_cycles: int = 250_000,
        settle_cycles: int = 4000,
    ) -> FX2State:
        self.queue_button(row, col)
        used = 0

        while used < timeout_cycles:
            chunk = min(step_chunk, timeout_cycles - used)
            st = self.step(chunk)
            used += chunk
            if not st.pending:
                if settle_cycles > 0:
                    st = self.step(settle_cycles)
                return st

        raise BridgeError(f"Button row={row} col={col} timeout after {timeout_cycles} cycles")


__all__ = [
    "BOOT_VID",
    "BOOT_PID",
    "RUNTIME_VID",
    "RUNTIME_PID",
    "BridgeError",
    "FX2State",
    "FX2MK61Bridge",
    "render_display_emu145",
]
