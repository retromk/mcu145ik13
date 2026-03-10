# MK-61 Emulator Variant for Nintendo Switch (Smile BASIC 4)

Этот модуль добавляет вариант эмулятора МК-61 для Nintendo Switch в среде Smile BASIC 4.

Состав:

- `mk61_switch_host.cpp` — рабочая host-версия с key aliases в стиле Switch/SB4.
- `mk61_smilebasic4.prg` — Smile BASIC 4 программа (виртуальная клавиатура + MK-61 style RPN).
- `build_host.sh` — сборка host-версии.

## 1) Host запуск

```bash
./switch_sb4/build_host.sh
./switch_sb4/build/mk61_switch_sb4_host
```

Smoke-тест:

```bash
printf '/sb4 1 2 A + 3 +\n/quit\n' | ./switch_sb4/build/mk61_switch_sb4_host
```

Ожидаемый результат: `compact: 15`.

## 2) Smile BASIC 4 on-device

Файл `mk61_smilebasic4.prg` загружается в Smile BASIC 4 как проектный код.

Вариант ввода:

- Левый стик / D-pad: перемещение курсора по 3x10 матрице клавиш МК-61.
- `A` (`#B_RRIGHT`): нажать выбранную клавишу.
- `B` (`#B_RDOWN`): `CX`.
- `X` (`#B_RUP`): `F`.
- `Y` (`#B_RLEFT`): `K`.
- `L` (`#B_L1`): смена `RAD/DEG/GRD`.
- `R` (`#B_R1`): `V`.

## 3) Команды host-версии

- `/help`
- `/display`
- `/mode rad|deg|grd`
- `/reset`
- `/step N`
- `/preset NAME`
- `/presets`
- `/sb4 KEYS...`
- `/sb4-help`
- `/quit`

## 4) Ограничение Smile BASIC версии

`mk61_smilebasic4.prg` реализует практичную MK-61 style RPN-модель и keymap под Switch.
Это не бит-точный RTL/HLS порт (который слишком тяжёл для чистого BASIC-скрипта).
