# MK-61 Emulator Variant for MK-90 (PDP-11 Compatible)

Этот модуль добавляет вариант эмулятора МК-61 в стиле монитора МК-90/RT-11.

Состав:

- `mk61_mk90_host.cpp` — рабочая host-версия с MK-90 monitor-командами.
- `mk61_engine_c_api.*` — C ABI для встраивания в PDP-11/C-проекты.
- `mk61_mk90_rt11_stub.c` — C-stub (RT-11 style) поверх C API.
- `build_host.sh` — сборка host-версии.
- `build_rt11_stub.sh` — сборка stub-версии для host smoke-test.

## 1) Host monitor

```bash
./mk90/build_host.sh
./mk90/build/mk61_mk90_host
```

Пример:

```bash
printf 'P 1 2 ENT + 3 +\nQ\n' | ./mk90/build/mk61_mk90_host
```

Ожидаемый результат: `DISPLAY=15`.

Команды:

- `H` — help
- `Q` — quit
- `D` — display
- `M RAD|DEG|GRD` — mode
- `R` — reset
- `S N` — step cycles
- `K TOKENS...` — MK-61 tokens
- `P KEYS...` — MK-90 aliases
- `B ROW DNUM` — matrix key
- `L PRESET` / `LS` — presets
- `KH` — aliases help

## 2) RT-11/PDP-11 style stub

```bash
./mk90/build_rt11_stub.sh
./mk90/build/mk61_mk90_rt11_stub_host
```

В stub доступны:

- `mk90_emulator_main()` — точка входа под target runtime.
- C API (`mk61_engine_c_api.h`) для управления ядром МК-61 из C-кода.

## 3) MK-90 aliases

- цифры: `0..9`
- операции: `+ - * / .` (`PLUS/MINUS/MUL/DIV/DOT`)
- ввод: `ENT|ENTER|EXE|RUN` -> `V`
- очистка: `CLR|CLEAR|CX` -> `CX`
- знак: `NEG|SIGN|CHS` -> `/-/`
- функции: `SIN COS TAN/TG PI SQRT SQR/X2 INV/INVX POW`
- модификаторы: `SHIFT -> F`, `ALPHA -> K`
