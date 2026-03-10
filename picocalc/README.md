# MK-61 emulator variant for PicoCalc

Этот вариант предназначен для устройств класса PicoCalc:

- лёгкий standalone binary;
- без `iverilog`, `tkinter`, `Qt`;
- backend: `hls/mk61_hls.cpp` (cycle-accurate model).

## Build

```bash
./picocalc/build_picocalc.sh
```

Бинарник:

- `picocalc/build/mk61_picocalc`

## Run

```bash
./picocalc/build/mk61_picocalc
```

Опции:

- `--mode rad|deg|grd`
- `--boot-cycles N`
- `--start-cycles N`
- `--gap-cycles N`
- `--settle-cycles N`
- `--press-timeout N`
- `--post-cycles N`

Пример:

```bash
./picocalc/build/mk61_picocalc --mode rad --boot-cycles 120000
```

Стабильный профиль по умолчанию:

- `start=0`
- `gap=90000`
- `settle=6000`
- `post=220000`

## Interactive usage

Обычный ввод трактуется как последовательность токенов клавиш:

```text
1 2 V + 3 +
PI
9 SQRT
```

Команды:

- `/help`
- `/display`
- `/mode rad|deg|grd`
- `/reset`
- `/step N`
- `/presets`
- `/preset CALC_12_ENTER_3_PLUS`
- `/quit`

## Supported tokens

Базовые:

- `0..9`
- `+ - * / .`
- `ENTER` (`=`)
- `CX` (`CLEAR`)
- `F`, `K`

Функции (макро, как на МК-61):

- `PI`, `SIN`, `COS`, `TG`
- `SQRT`, `X2`, `INVX`, `POW`

Также принимаются матричные формы:

- `B_1_2 .. B_3_11`
- `R1D2` / `1:2`

## Notes for PicoCalc

- Для быстрого старта можно уменьшить `--boot-cycles`.
- Если ввод ощущается «вязким», уменьшайте `--gap-cycles`.
- Это текстовый интерфейс: хорошо работает через serial/terminal на небольшом экране.
