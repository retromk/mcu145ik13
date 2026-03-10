# MK-61 Emulator Variant for dsPIC30F6014A (ASM)

Этот модуль добавляет вариант эмулятора МК-61 для Microchip dsPIC30F6014A.

Состав:

- `mk61_dspic30_host.cpp` — рабочая host-версия с dsPIC alias-командами.
- `mk61_dspic30f6014a_stub.s` — ASM30/XC16 практичный RPN-stub под dsPIC30F6014A.
- `build_host.sh` — сборка host-версии.
- `build_asm_stub.sh` — сборка ASM stub (`xc16-as`/`pic30-as`).

## 1) Host запуск

```bash
./dspic30f6014a/build_host.sh
./dspic30f6014a/build/mk61_dspic30_host
```

Smoke-тест:

```bash
printf '/dspic KEY1 KEY2 ENTER KP_ADD KEY3 KP_ADD\n/quit\n' | ./dspic30f6014a/build/mk61_dspic30_host
```

Ожидаемый результат: `compact: 15`.

Проверка PI:

```bash
printf '/dspic PI\n/quit\n' | ./dspic30f6014a/build/mk61_dspic30_host
```

Ожидаемый результат: `compact: 3.1415926`.

## 2) Команды host-версии

- `/help`
- `/display`
- `/mode rad|deg|grd`
- `/reset`
- `/step N`
- `/preset NAME`
- `/presets`
- `/dspic KEYS...`
- `/dspic-help`
- `/quit`

Без `/...` можно вводить обычные MK-61 токены напрямую (`PI`, `SIN`, `1 2 V + 3 +`).

## 3) dsPIC aliases

- цифры: `0..9`, `KEY0..KEY9`
- операции: `+ - * / .`, `KP_ADD/KP_SUB/KP_MUL/KP_DIV/KP_DOT`
- ввод: `ENTER|ENT|EXE|RUN|EVAL -> V`
- очистка: `CLR|CLEAR|AC|DEL|BKSP -> CX`
- знак: `NEG|CHS|SIGN -> /-/`
- модификаторы: `SHIFT -> F`, `ALPHA -> K`
- функции: `PI SIN COS TAN/TG SQRT X2 INVX POW`

## 4) Сборка ASM stub

```bash
./dspic30f6014a/build_asm_stub.sh
```

Результат:

- `dspic30f6014a/build/mk61_dspic30f6014a_stub.o`

Примечание: `mk61_dspic30f6014a_stub.s` реализует практичный RPN-профиль (целочисленный X/Y/Z/T + UART токены), а не бит-точный порт микропрограммы МК-61.
