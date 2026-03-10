# MK-61 Emulator Variant for ZX Spectrum (Z80)

Этот модуль добавляет вариант эмулятора МК-61 для ZX Spectrum:

- `mk61_zx_host.cpp` — рабочая host-версия с ZX key aliases.
- `mk61_z80_stub.asm` — Z80 asm-заготовка для запуска на Spectrum (практичный RPN-профиль).
- `build_host.sh` — сборка host-версии.
- `build_z80_stub.sh` — сборка Z80 asm stub через `sjasmplus`.

## 1) Host запуск

```bash
./zxspectrum/build_host.sh
./zxspectrum/build/mk61_zx_host
```

Smoke-тест:

```bash
printf '/zx 1 2 ENT P 3 P\n/quit\n' | ./zxspectrum/build/mk61_zx_host
```

Ожидаемый результат: `compact: 15`.

## 2) Команды host-версии

- `/help`
- `/display`
- `/mode rad|deg|grd`
- `/reset`
- `/step N`
- `/preset NAME`
- `/presets`
- `/zx KEYS...`
- `/zx-help`
- `/quit`

Без `/...` можно вводить обычные MK-61 токены напрямую (`PI`, `SIN`, `1 2 V + 3 +`).

## 3) ZX aliases

- цифры: `0..9`
- операции: `P -> +`, `M -> -`, `X -> *`, `D -> /`, `N -> /-/`
- очистка: `C|CLR|CLEAR -> CX`
- ввод: `ENT|ENTER|CAPS|SYMB -> V`
- модификаторы: `F -> F`, `K -> K`
- функции: `PI SIN COS TAN/TG SQRT X2 INVX POW`
- матрица: `Krc` (пример: `K30=1`, `K66=ENTER`, `K50=P/+`)

## 4) Z80 asm stub

Сборка (если установлен `sjasmplus`):

```bash
sjasmplus --syntax=abfw zxspectrum/mk61_z80_stub.asm
# или
./zxspectrum/build_z80_stub.sh
```

Результат:

- `zxspectrum/mk61_z80_stub.bin`

Важно: `mk61_z80_stub.asm` — это практичный ZX-профиль (RPN-ядро с основными клавишами), а не бит-точный порт полного RTL/HLS ядра МК-61.
