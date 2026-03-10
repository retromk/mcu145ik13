#!/usr/bin/env python3
"""Tkinter GUI front-end for virtual_calculator.py (MK-61 RTL)."""

from __future__ import annotations

import queue
import re
import subprocess
import sys
import threading
from pathlib import Path
from typing import Dict, List, Sequence

try:
    import tkinter as tk
    from tkinter import messagebox, scrolledtext, ttk
except ModuleNotFoundError as exc:
    if exc.name == "_tkinter":
        py_ver = f"{sys.version_info.major}.{sys.version_info.minor}"
        print(
            "GUI requires tkinter, but module '_tkinter' is missing in current Python.\n"
            f"Install it for this version:\n"
            f"  brew install python-tk@{py_ver}\n"
            "Then restart your shell/venv and run:\n"
            "  ./virtual_calculator_gui.py\n",
            file=sys.stderr,
        )
        raise SystemExit(2)
    raise

ROOT = Path(__file__).resolve().parent
VC_SCRIPT = ROOT / "virtual_calculator.py"
TRACE_PATH = ROOT / "rtl_trace.csv"

EMU_SEGMENTS = "0123456789-LCrE "

DEFAULT_MODE = "rad"
DEFAULT_ENGINE = "verilog"
DEFAULT_CYCLES = 760000
DEFAULT_START = 100000
DEFAULT_GAP = 90000
DEFAULT_FRAMES = 6

PRESETS = (
    "boot_probe",
    "scan_row1",
    "scan_all",
    "calc_1_2_plus_3_eq",
    "calc_1_enter_2_plus",
    "calc_12_enter_3_plus",
    "func_sin_1",
)

PRESET_EXPECTED = {
    "boot_probe": "1",
    "scan_row1": None,
    "scan_all": None,
    "calc_1_2_plus_3_eq": "15",
    "calc_1_enter_2_plus": "3",
    "calc_12_enter_3_plus": "15",
    "func_sin_1": "0",
}

KEY_ROWS = (
    (("7", "7"), ("8", "8"), ("9", "9"), ("/", "/"), ("CX", "CX")),
    (("4", "4"), ("5", "5"), ("6", "6"), ("*", "*"), ("ENTER", "ENTER")),
    (("1", "1"), ("2", "2"), ("3", "3"), ("-", "-"), ("+", "+")),
    (("0", "0"), (".", "."), ("SIN", "SIN"), ("COS", "COS"), ("TG", "TG")),
    (("SQRT", "SQRT"), ("PI", "PI"), ("X^2", "X2"), ("1/X", "INVX"), ("POW", "POW")),
    (("SP", "SP"), ("VP", "VP"), ("F", "F"), ("K", "K"), ("PP", "PP")),
)


class VirtualCalculatorGUI(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("MK-61 Virtual Calculator (RTL)")
        self.minsize(980, 760)

        self.tokens: List[str] = []
        self.running = False
        self.built_once: Dict[str, bool] = {"verilog": False, "vhdl": False, "hls": False}
        self.pending_autorun = False
        self.result_queue: queue.Queue[tuple[List[str], int, str, str, str]] = queue.Queue()

        self.engine_var = tk.StringVar(value=DEFAULT_ENGINE)
        self.mode_var = tk.StringVar(value=DEFAULT_MODE)
        self.cycles_var = tk.IntVar(value=DEFAULT_CYCLES)
        self.start_var = tk.IntVar(value=DEFAULT_START)
        self.gap_var = tk.IntVar(value=DEFAULT_GAP)
        self.frames_var = tk.IntVar(value=DEFAULT_FRAMES)

        self.auto_run_var = tk.BooleanVar(value=False)
        self.skip_rebuild_var = tk.BooleanVar(value=True)

        self.sequence_var = tk.StringVar(value="(empty)")
        self.display_var = tk.StringVar(value="0")
        self.last_cycle_var = tk.StringVar(value="last sync cycle: -")
        self.status_var = tk.StringVar(value="status: idle")
        self.preset_check_var = tk.StringVar(value="preset check: n/a")

        self.preset_var = tk.StringVar(value=PRESETS[0])
        self.expr_var = tk.StringVar(value="")
        self.preset_rows: Dict[str, str] = {}

        self._build_ui()
        self.after(120, self._poll_results)

    def _build_ui(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(4, weight=1)

        display_frame = ttk.Frame(self, padding=(12, 10))
        display_frame.grid(row=0, column=0, sticky="ew")
        display_frame.columnconfigure(0, weight=1)

        display = tk.Label(
            display_frame,
            textvariable=self.display_var,
            font=("Courier New", 30, "bold"),
            anchor="e",
            bg="#111111",
            fg="#7CFF5B",
            padx=14,
            pady=10,
            relief="sunken",
            bd=3,
        )
        display.grid(row=0, column=0, sticky="ew")

        ttk.Label(display_frame, textvariable=self.last_cycle_var).grid(row=1, column=0, sticky="w", pady=(6, 0))
        ttk.Label(display_frame, textvariable=self.status_var).grid(row=2, column=0, sticky="w", pady=(2, 0))
        ttk.Label(display_frame, textvariable=self.preset_check_var).grid(row=3, column=0, sticky="w", pady=(2, 0))

        seq_frame = ttk.Frame(self, padding=(12, 0, 12, 10))
        seq_frame.grid(row=1, column=0, sticky="ew")
        seq_frame.columnconfigure(1, weight=1)

        ttk.Label(seq_frame, text="Текущая последовательность:").grid(row=0, column=0, sticky="w", padx=(0, 8))
        seq_entry = ttk.Entry(seq_frame, textvariable=self.sequence_var, state="readonly")
        seq_entry.grid(row=0, column=1, sticky="ew")

        controls = ttk.LabelFrame(self, text="Параметры запуска", padding=10)
        controls.grid(row=2, column=0, sticky="ew", padx=12, pady=(0, 10))
        for i in range(12):
            controls.columnconfigure(i, weight=(1 if i in (1, 3, 5, 7) else 0))

        ttk.Label(controls, text="Engine").grid(row=0, column=0, sticky="w")
        engine_box = ttk.Combobox(
            controls,
            textvariable=self.engine_var,
            values=("verilog", "vhdl", "hls"),
            state="readonly",
            width=9,
        )
        engine_box.grid(row=0, column=1, sticky="w", padx=(6, 14))

        ttk.Label(controls, text="Mode").grid(row=0, column=2, sticky="w")
        mode_box = ttk.Combobox(controls, textvariable=self.mode_var, values=("rad", "deg", "grd"), state="readonly", width=8)
        mode_box.grid(row=0, column=3, sticky="w", padx=(6, 14))

        ttk.Label(controls, text="Cycles").grid(row=0, column=4, sticky="w")
        ttk.Spinbox(controls, from_=1000, to=5000000, increment=1000, textvariable=self.cycles_var, width=10).grid(
            row=0, column=5, sticky="w", padx=(6, 14)
        )

        ttk.Label(controls, text="Start").grid(row=0, column=6, sticky="w")
        ttk.Spinbox(controls, from_=0, to=5000000, increment=1000, textvariable=self.start_var, width=10).grid(
            row=0, column=7, sticky="w", padx=(6, 14)
        )

        ttk.Label(controls, text="Gap").grid(row=0, column=8, sticky="w")
        ttk.Spinbox(controls, from_=1, to=500000, increment=1000, textvariable=self.gap_var, width=10).grid(
            row=0, column=9, sticky="w", padx=(6, 14)
        )

        ttk.Label(controls, text="Frames").grid(row=0, column=10, sticky="w")
        ttk.Spinbox(controls, from_=1, to=20, increment=1, textvariable=self.frames_var, width=6).grid(
            row=0, column=11, sticky="w", padx=(6, 0)
        )

        ttk.Checkbutton(controls, text="Auto-run after key press", variable=self.auto_run_var).grid(
            row=1, column=0, columnspan=5, sticky="w", pady=(8, 0)
        )
        ttk.Checkbutton(controls, text="Skip rebuild after first success (--no-build)", variable=self.skip_rebuild_var).grid(
            row=1, column=5, columnspan=7, sticky="w", pady=(8, 0)
        )

        middle = ttk.Frame(self, padding=(12, 0, 12, 10))
        middle.grid(row=3, column=0, sticky="nsew")
        middle.columnconfigure(0, weight=3)
        middle.columnconfigure(1, weight=2)

        keys_box = ttk.LabelFrame(middle, text="Клавиатура", padding=10)
        keys_box.grid(row=0, column=0, sticky="nsew", padx=(0, 10))
        for c in range(5):
            keys_box.columnconfigure(c, weight=1)

        for r, row in enumerate(KEY_ROWS):
            for c, (caption, token) in enumerate(row):
                ttk.Button(keys_box, text=caption, command=lambda t=token: self._on_key(t)).grid(
                    row=r, column=c, sticky="nsew", padx=2, pady=2, ipadx=8, ipady=10
                )

        action_row = len(KEY_ROWS)
        ttk.Button(keys_box, text="⌫ Backspace", command=self._backspace).grid(
            row=action_row, column=0, columnspan=2, sticky="nsew", padx=2, pady=(8, 2), ipady=8
        )
        ttk.Button(keys_box, text="Очистить", command=self._clear_tokens).grid(
            row=action_row, column=2, sticky="nsew", padx=2, pady=(8, 2), ipady=8
        )
        ttk.Button(keys_box, text="Запустить", command=self._run_sequence_now).grid(
            row=action_row, column=3, columnspan=2, sticky="nsew", padx=2, pady=(8, 2), ipady=8
        )

        side_box = ttk.LabelFrame(middle, text="Сценарии и команды", padding=10)
        side_box.grid(row=0, column=1, sticky="nsew")
        side_box.columnconfigure(0, weight=1)
        side_box.columnconfigure(1, weight=0)

        ttk.Label(side_box, text="Preset").grid(row=0, column=0, sticky="w")
        preset_box = ttk.Combobox(side_box, textvariable=self.preset_var, values=PRESETS, state="readonly")
        preset_box.grid(row=1, column=0, sticky="ew", pady=(4, 8))
        ttk.Button(side_box, text="Запустить preset", command=self._run_preset).grid(row=2, column=0, sticky="ew")
        ttk.Label(side_box, text="Ожидаемый результат preset").grid(row=3, column=0, sticky="w", pady=(10, 4))

        self.preset_table = ttk.Treeview(
            side_box,
            columns=("preset", "expected", "status"),
            show="headings",
            height=min(8, len(PRESETS)),
        )
        self.preset_table.heading("preset", text="Preset")
        self.preset_table.heading("expected", text="Expected")
        self.preset_table.heading("status", text="Status")
        self.preset_table.column("preset", width=165, anchor="w")
        self.preset_table.column("expected", width=70, anchor="center")
        self.preset_table.column("status", width=170, anchor="w")
        self.preset_table.tag_configure("status_pass", foreground="#1b7f3b")
        self.preset_table.tag_configure("status_fail", foreground="#b42318")
        self.preset_table.tag_configure("status_error", foreground="#b42318")
        self.preset_table.tag_configure("status_running", foreground="#9a6b16")
        self.preset_table.tag_configure("status_diag", foreground="#5f6368")
        self.preset_table.tag_configure("status_neutral", foreground="#1f2328")

        table_scroll = ttk.Scrollbar(side_box, orient="vertical", command=self.preset_table.yview)
        self.preset_table.configure(yscrollcommand=table_scroll.set)
        self.preset_table.grid(row=4, column=0, sticky="nsew")
        table_scroll.grid(row=4, column=1, sticky="ns")
        side_box.rowconfigure(4, weight=1)

        for preset in PRESETS:
            expected = PRESET_EXPECTED.get(preset)
            expected_text = expected if expected is not None else "diag"
            status_text = "diag" if expected is None else "n/a"
            iid = self.preset_table.insert(
                "",
                "end",
                values=(preset, expected_text, status_text),
                tags=(self._status_tag(status_text),),
            )
            self.preset_rows[preset] = iid

        ttk.Separator(side_box).grid(row=5, column=0, sticky="ew", pady=10)

        ttk.Label(side_box, text="Токены (через пробел)").grid(row=6, column=0, sticky="w")
        expr_entry = ttk.Entry(side_box, textvariable=self.expr_var)
        expr_entry.grid(row=7, column=0, sticky="ew", pady=(4, 8))

        ttk.Button(side_box, text="Заменить последовательность", command=self._load_from_expr).grid(row=8, column=0, sticky="ew")
        ttk.Button(side_box, text="Запустить токены из поля", command=self._run_expr_field).grid(
            row=9, column=0, sticky="ew", pady=(6, 0)
        )

        ttk.Button(side_box, text="Вставить пример: 1 ENTER 2 +", command=lambda: self.expr_var.set("1 ENTER 2 +")).grid(
            row=10, column=0, sticky="ew", pady=(10, 0)
        )
        ttk.Button(side_box, text="Вставить пример: 1 SIN", command=lambda: self.expr_var.set("1 SIN")).grid(
            row=11, column=0, sticky="ew", pady=(6, 0)
        )

        log_frame = ttk.LabelFrame(self, text="Лог", padding=10)
        log_frame.grid(row=4, column=0, sticky="nsew", padx=12, pady=(0, 12))
        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)

        self.log_text = scrolledtext.ScrolledText(log_frame, wrap="word", height=12, font=("Courier New", 10))
        self.log_text.grid(row=0, column=0, sticky="nsew")
        self.log_text.configure(state="disabled")

        self._log("GUI ready. Нажмите клавиши или запустите preset.")

    def _set_running(self, running: bool) -> None:
        self.running = running
        self.status_var.set("status: running..." if running else "status: idle")

    def _update_sequence_var(self) -> None:
        if self.tokens:
            self.sequence_var.set(" ".join(self.tokens))
        else:
            self.sequence_var.set("(empty)")

    def _log(self, msg: str) -> None:
        self.log_text.configure(state="normal")
        self.log_text.insert("end", msg + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _on_key(self, token: str) -> None:
        self.tokens.append(token)
        self._update_sequence_var()
        if self.auto_run_var.get():
            if self.running:
                self.pending_autorun = True
            else:
                self._run_sequence_now()

    def _backspace(self) -> None:
        if self.tokens:
            self.tokens.pop()
            self._update_sequence_var()
            if self.auto_run_var.get() and not self.running:
                self._run_sequence_now()

    def _clear_tokens(self) -> None:
        self.tokens.clear()
        self._update_sequence_var()
        self.display_var.set("0")
        self.last_cycle_var.set("last sync cycle: -")

    def _load_from_expr(self) -> None:
        raw = self.expr_var.get().strip()
        self.tokens = [t for t in raw.split() if t]
        self._update_sequence_var()

    def _run_expr_field(self) -> None:
        raw = self.expr_var.get().strip()
        if not raw:
            messagebox.showwarning("Пустой ввод", "Введите токены, например: 1 ENTER 2 +")
            return
        if self.running:
            self.pending_autorun = True
            return
        self._run_virtual(reason="expr field", extra=["--expr", raw])

    def _run_preset(self) -> None:
        preset = self.preset_var.get()
        if self.running:
            self.pending_autorun = True
            return
        self._set_preset_status(preset, "running...")
        self.preset_check_var.set(f"preset check: running {preset}...")
        self._run_virtual(
            reason=f"preset:{preset}",
            extra=["--preset", preset, "--preset-timing", "on"],
        )

    def _run_sequence_now(self) -> None:
        if self.running:
            self.pending_autorun = True
            return

        if not self.tokens:
            messagebox.showwarning("Пустая последовательность", "Нечего запускать. Добавьте хотя бы один токен.")
            return

        self._run_virtual(reason="sequence", extra=["--expr", " ".join(self.tokens)])

    def _run_virtual(self, *, reason: str, extra: Sequence[str]) -> None:
        if not VC_SCRIPT.exists():
            messagebox.showerror("Ошибка", f"Не найден {VC_SCRIPT}")
            return
        if not reason.startswith("preset:"):
            self.preset_check_var.set("preset check: n/a")

        cmd: List[str] = [
            sys.executable,
            str(VC_SCRIPT),
            *extra,
            "--mode",
            self.mode_var.get(),
            "--engine",
            self.engine_var.get(),
            "--cycles",
            str(self.cycles_var.get()),
            "--start",
            str(self.start_var.get()),
            "--gap",
            str(self.gap_var.get()),
            "--frames",
            str(self.frames_var.get()),
        ]

        engine = self.engine_var.get().strip().lower()
        if self.skip_rebuild_var.get() and self.built_once.get(engine, False):
            cmd.append("--no-build")

        self._set_running(True)
        self._log(f"[RUN:{reason}] {' '.join(cmd)}")

        thread = threading.Thread(target=self._worker, args=(cmd, reason), daemon=True)
        thread.start()

    def _worker(self, cmd: Sequence[str], reason: str) -> None:
        proc = subprocess.run(
            list(cmd),
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.result_queue.put((list(cmd), proc.returncode, proc.stdout, proc.stderr, reason))

    def _poll_results(self) -> None:
        try:
            while True:
                cmd, rc, out, err, reason = self.result_queue.get_nowait()
                self._handle_result(cmd, rc, out, err, reason)
        except queue.Empty:
            pass

        self.after(120, self._poll_results)

    def _handle_result(self, cmd: Sequence[str], rc: int, out: str, err: str, reason: str) -> None:
        self._set_running(False)
        preset = self._preset_from_reason(reason)

        if rc != 0:
            self._log(f"[FAIL:{reason}] rc={rc}")
            if out.strip():
                self._log(out.strip())
            if err.strip():
                self._log(err.strip())
            if preset is not None:
                self._set_preset_status(preset, f"error rc={rc}")
                self.preset_check_var.set(f"preset check: error {preset} rc={rc}")
            messagebox.showerror("Ошибка запуска", (err or out or f"rc={rc}").strip())
        else:
            if "--no-build" not in cmd:
                engine = self._engine_from_cmd(cmd)
                self.built_once[engine] = True
            self._parse_and_show_output(out)
            if preset is not None:
                self._evaluate_preset_result(preset)

        if self.pending_autorun and self.auto_run_var.get() and self.tokens:
            self.pending_autorun = False
            self._run_sequence_now()
        else:
            self.pending_autorun = False

    @staticmethod
    def _preset_from_reason(reason: str) -> str | None:
        if reason.startswith("preset:"):
            return reason.split(":", 1)[1].strip()
        return None

    @staticmethod
    def _engine_from_cmd(cmd: Sequence[str]) -> str:
        for i in range(len(cmd) - 1):
            if cmd[i] == "--engine":
                return cmd[i + 1].strip().lower()
        return "verilog"

    @staticmethod
    def _compact_display_text(text: str) -> str:
        compact = "".join(text.strip().split())
        while compact.endswith("."):
            compact = compact[:-1]
        return compact if compact else "0"

    @staticmethod
    def _status_tag(status: str) -> str:
        s = status.strip().lower()
        if s.startswith("pass"):
            return "status_pass"
        if s.startswith("fail"):
            return "status_fail"
        if s.startswith("error"):
            return "status_error"
        if s.startswith("running"):
            return "status_running"
        if s == "diag":
            return "status_diag"
        return "status_neutral"

    def _set_preset_status(self, preset: str, status: str) -> None:
        iid = self.preset_rows.get(preset)
        if not iid:
            return
        values = list(self.preset_table.item(iid, "values"))
        if len(values) < 3:
            return
        values[2] = status
        self.preset_table.item(iid, values=values, tags=(self._status_tag(status),))
        self.preset_table.see(iid)

    def _evaluate_preset_result(self, preset: str) -> None:
        engine = self.engine_var.get().strip().lower()
        if engine == "vhdl":
            self._set_preset_status(preset, "diag (vhdl)")
            self.preset_check_var.set(f"preset check: {preset}: diagnostic on vhdl")
            self._log(f"[CHECK:{preset}] diagnostic on vhdl engine")
            return

        expected = PRESET_EXPECTED.get(preset)
        if expected is None:
            self._set_preset_status(preset, "diag")
            self.preset_check_var.set(f"preset check: {preset}: diagnostic")
            self._log(f"[CHECK:{preset}] diagnostic preset (no fixed expected value)")
            return

        actual = self._compact_display_text(self.display_var.get())
        if actual == expected:
            self._set_preset_status(preset, f"PASS ({actual})")
            self.preset_check_var.set(f"preset check: PASS {preset} -> {actual}")
            self._log(f"[CHECK:{preset}] PASS expected={expected} actual={actual}")
        else:
            self._set_preset_status(preset, f"FAIL exp={expected} got={actual}")
            self.preset_check_var.set(f"preset check: FAIL {preset}: expected {expected}, got {actual}")
            self._log(f"[CHECK:{preset}] FAIL expected={expected} actual={actual}")

    def _parse_and_show_output(self, out: str) -> None:
        frame = self._last_frame_from_trace()
        if frame is not None:
            cyc, text = frame
            self.display_var.set(self._normalize_display_text(text))
            self.last_cycle_var.set(f"last sync cycle: {cyc}")
        else:
            self._parse_display_from_stdout(out)

        keep = []
        for line in out.splitlines():
            if (
                line.startswith("Input source:")
                or line.startswith("Input mode:")
                or line.startswith("Resolved tokens:")
                or line.startswith("Engine:")
            ):
                keep.append(line)
        if keep:
            self._log("[OK] " + " | ".join(keep))
        else:
            self._log("[OK] Simulation completed")

    def _parse_display_from_stdout(self, out: str) -> None:
        cycle = None
        text = None

        frame_re = re.compile(r"^\s*cycle=\s*(\d+)\s+(.*)$")
        for line in out.splitlines():
            m = frame_re.match(line)
            if m:
                cycle = int(m.group(1))
                text = m.group(2)

        if text is not None:
            self.display_var.set(self._normalize_display_text(text))
            self.last_cycle_var.set(f"last sync cycle: {cycle}")
        else:
            self.display_var.set("0")
            self.last_cycle_var.set("last sync cycle: not found")

    def _last_frame_from_trace(self) -> tuple[int, str] | None:
        if not TRACE_PATH.exists():
            return None

        try:
            import csv
        except Exception:
            return None

        try:
            csv.field_size_limit(sys.maxsize)
        except Exception:
            pass

        display = [0x0F] * 12
        display[7] = 0x80
        last_cycle = None

        try:
            with TRACE_PATH.open("r", encoding="ascii", newline="") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    dcycle = int(row["dcycle"])
                    sync = int(row["sync"])
                    seg_s = row["seg"].strip().lower()
                    seg = int(seg_s, 16) if seg_s.startswith("0x") else int(seg_s, 10)

                    if 2 <= dcycle <= 13:
                        display[dcycle - 2] = seg
                    if sync == 1:
                        last_cycle = int(row["cycle"])
        except Exception:
            return None

        if last_cycle is None:
            return None

        def decode(seg: int) -> str:
            idx = seg & 0x0F
            ch = EMU_SEGMENTS[idx] if 0 <= idx < len(EMU_SEGMENTS) else "?"
            return f"{ch}." if (seg & 0x80) else ch

        out = []
        for i in range(9):
            out.append(decode(display[8 - i]))
        for i in range(3):
            out.append(decode(display[11 - i]))

        return last_cycle, " ".join(out)

    @staticmethod
    def _normalize_display_text(text: str) -> str:
        # Raw frame text contains many blank segment slots; show a readable value.
        v = " ".join(text.strip().split())
        return v if v else "0"


def main() -> int:
    app = VirtualCalculatorGUI()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
