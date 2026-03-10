# MK-61 Emulator Variant for HP Prime

Этот модуль добавляет вариант эмулятора МК-61, адаптированный под сценарий использования на HP Prime.

Состав:

- `mk61_hpprime_host.cpp` — рабочая host-версия с keymap в стиле HP Prime.
- `mk61_hpprime_sdk_stub.cpp` — заготовка для интеграции с on-device SDK HP Prime.
- `build_host.sh` — сборка host-версии.

## 1) Быстрый запуск на ПК

```bash
./hpprime/build_host.sh
./hpprime/build/mk61_hpprime_host
```

Smoke-тест:

```bash
printf '/prime 1 2 EXE + 3 +\n/quit\n' | ./hpprime/build/mk61_hpprime_host
```

Ожидаемый результат: `compact: 15`.

## 2) Режимы ввода

1. MK-61 токены напрямую:
   `1 2 V + 3 +`, `PI`, `SIN`, `B_2_11`.
2. HP Prime key aliases через `/prime`:
   `/prime 1 2 EXE + 3 +`

Команды:

- `/help`
- `/display`
- `/mode rad|deg|grd`
- `/reset`
- `/step N`
- `/preset NAME`
- `/presets`
- `/prime KEYS...`
- `/prime-help`
- `/quit`

## 3) HP Prime aliases

Основные:

- `0..9`
- `+ - * / .` (`PLUS/MINUS/MUL/DIV/DOT`)
- `EXE|ENTER|EVAL|RUN` -> `V`
- `DEL|BACKSPACE|CLEAR|AC` -> `CX`
- `NEG|CHS|SIGN` -> `/-/`

Функции:

- `SIN`, `COS`, `TAN|TG`
- `PI`
- `SQRT`
- `SQ|X2`
- `INV|INVX`
- `POW`

Модификаторы:

- `SHIFT|LSHIFT` -> `F`
- `ALPHA` -> `K`

## 4) On-device integration

Файл `mk61_hpprime_sdk_stub.cpp` содержит entry point `mk61_hpprime_main()` и SDK-hook функции:

- `hpprime_clear_screen()`
- `hpprime_draw_text(int x, int y, const char* text)`
- `hpprime_poll_key()`
- `hpprime_sleep_ms(int ms)`

Подключите эти hooks к выбранному SDK/рантайму HP Prime и соберите вместе с:

- `../nspire/mk61_engine.cpp`
- `../hls/mk61_hls.cpp`
