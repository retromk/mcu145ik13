#!/usr/bin/env python3
"""Firmware loader for EZ-USB FX2LP (CY7C68013A) via vendor request 0xA0."""

from __future__ import annotations

import argparse
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple

import usb.core
import usb.util

BOOT_VID = 0x04B4
BOOT_PID = 0x8613
RUNTIME_VID = 0x04B4
RUNTIME_PID = 0x1004

CPUCS_ADDR = 0xE600
VR_RAM = 0xA0


class LoaderError(RuntimeError):
    pass


@dataclass(frozen=True)
class HexChunk:
    addr: int
    data: bytes


def _parse_ihx(path: Path) -> List[HexChunk]:
    upper = 0
    records: List[Tuple[int, bytes]] = []

    for lineno, raw in enumerate(path.read_text(encoding="ascii").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        if not line.startswith(":"):
            raise LoaderError(f"{path}:{lineno}: invalid ihx line")

        try:
            b = bytes.fromhex(line[1:])
        except ValueError as exc:
            raise LoaderError(f"{path}:{lineno}: bad hex") from exc

        if len(b) < 5:
            raise LoaderError(f"{path}:{lineno}: too short")

        size = b[0]
        off = (b[1] << 8) | b[2]
        rtype = b[3]
        payload = b[4 : 4 + size]

        if len(payload) != size:
            raise LoaderError(f"{path}:{lineno}: truncated payload")

        # Optional checksum validation.
        checksum = b[4 + size]
        total = (sum(b[: 4 + size]) + checksum) & 0xFF
        if total != 0:
            raise LoaderError(f"{path}:{lineno}: checksum mismatch")

        if rtype == 0x00:
            records.append((upper + off, payload))
        elif rtype == 0x01:
            break
        elif rtype == 0x02:
            if size != 2:
                raise LoaderError(f"{path}:{lineno}: bad ext-segment record")
            upper = ((payload[0] << 8) | payload[1]) << 4
        elif rtype == 0x04:
            if size != 2:
                raise LoaderError(f"{path}:{lineno}: bad ext-linear record")
            upper = ((payload[0] << 8) | payload[1]) << 16
        else:
            # Ignore unsupported record types for now.
            continue

    if not records:
        raise LoaderError(f"No data records in {path}")

    records.sort(key=lambda x: x[0])

    merged: List[HexChunk] = []
    cur_addr = records[0][0]
    cur_data = bytearray(records[0][1])

    for addr, data in records[1:]:
        if addr == cur_addr + len(cur_data):
            cur_data.extend(data)
        else:
            merged.append(HexChunk(cur_addr, bytes(cur_data)))
            cur_addr = addr
            cur_data = bytearray(data)

    merged.append(HexChunk(cur_addr, bytes(cur_data)))
    return merged


def _find_device(vid: int, pid: int):
    try:
        dev = usb.core.find(idVendor=vid, idProduct=pid)
    except usb.core.NoBackendError as exc:
        raise LoaderError(
            "PyUSB backend not found. Install libusb (e.g. 'brew install libusb') "
            "and ensure pyusb can load it."
        ) from exc
    return dev


def _ctrl_write(dev, addr: int, data: bytes, timeout_ms: int = 2000) -> None:
    written = dev.ctrl_transfer(0x40, VR_RAM, addr & 0xFFFF, 0, data, timeout=timeout_ms)
    if written != len(data):
        raise LoaderError(f"Short write at 0x{addr:04X}: {written}/{len(data)}")


def _set_cpu_reset(dev, hold: bool) -> None:
    _ctrl_write(dev, CPUCS_ADDR, bytes([0x01 if hold else 0x00]))


def _chunks(data: bytes, size: int) -> Iterable[bytes]:
    for i in range(0, len(data), size):
        yield data[i : i + size]


def _wait_device(vid: int, pid: int, timeout_s: float):
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        dev = _find_device(vid, pid)
        if dev is not None:
            return dev
        time.sleep(0.05)
    return None


def load_firmware(
    *,
    ihx_path: Path,
    boot_vid: int = BOOT_VID,
    boot_pid: int = BOOT_PID,
    runtime_vid: int = RUNTIME_VID,
    runtime_pid: int = RUNTIME_PID,
    timeout_s: float = 5.0,
    force: bool = False,
) -> Tuple[int, int]:
    ihx_path = ihx_path.resolve()
    if not ihx_path.exists():
        raise LoaderError(f"Firmware not found: {ihx_path}")

    runtime_dev = _find_device(runtime_vid, runtime_pid)
    if (runtime_dev is not None) and (not force):
        return runtime_vid, runtime_pid

    boot_dev = _find_device(boot_vid, boot_pid)
    if boot_dev is None:
        if runtime_dev is not None:
            return runtime_vid, runtime_pid
        raise LoaderError(
            f"FX2 boot device not found ({boot_vid:04x}:{boot_pid:04x}) and runtime not present"
        )

    try:
        if boot_dev.is_kernel_driver_active(0):
            boot_dev.detach_kernel_driver(0)
    except Exception:
        pass

    try:
        boot_dev.set_configuration()
    except Exception:
        pass

    segments = _parse_ihx(ihx_path)

    _set_cpu_reset(boot_dev, True)

    for seg in segments:
        addr = seg.addr
        for part in _chunks(seg.data, 1024):
            _ctrl_write(boot_dev, addr, part)
            addr += len(part)

    _set_cpu_reset(boot_dev, False)

    runtime_dev = _wait_device(runtime_vid, runtime_pid, timeout_s=timeout_s)
    if runtime_dev is None:
        # Firmware may run without renumeration on some boards/ROM variants.
        runtime_dev = _find_device(boot_vid, boot_pid)
        if runtime_dev is None:
            raise LoaderError(
                f"Runtime device not found after upload ({runtime_vid:04x}:{runtime_pid:04x})"
            )
        return boot_vid, boot_pid

    return runtime_vid, runtime_pid


def _parse_hex_u16(text: str) -> int:
    t = text.strip().lower()
    base = 16 if t.startswith("0x") else 10
    return int(t, base)


def main(argv: Sequence[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Load FX2LP firmware (.ihx) via vendor request 0xA0")
    p.add_argument("--ihx", required=True, help="Path to firmware .ihx")
    p.add_argument("--boot-vid", default=f"0x{BOOT_VID:04x}")
    p.add_argument("--boot-pid", default=f"0x{BOOT_PID:04x}")
    p.add_argument("--runtime-vid", default=f"0x{RUNTIME_VID:04x}")
    p.add_argument("--runtime-pid", default=f"0x{RUNTIME_PID:04x}")
    p.add_argument("--timeout", type=float, default=5.0, help="Seconds to wait for runtime re-enumeration")
    p.add_argument("--force", action="store_true", help="Force reload even if runtime device already present")
    args = p.parse_args(argv)

    try:
        vid, pid = load_firmware(
            ihx_path=Path(args.ihx),
            boot_vid=_parse_hex_u16(args.boot_vid),
            boot_pid=_parse_hex_u16(args.boot_pid),
            runtime_vid=_parse_hex_u16(args.runtime_vid),
            runtime_pid=_parse_hex_u16(args.runtime_pid),
            timeout_s=args.timeout,
            force=bool(args.force),
        )
        print(f"[OK] FX2 firmware active on {vid:04x}:{pid:04x}")
        return 0
    except (ValueError, LoaderError, usb.core.USBError) as exc:
        print(f"[ERR] {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
