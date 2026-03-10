# Инструкция: виртуальный калькулятор MK-61 (RTL + emu145 keymap)

## 1. Назначение
`virtual_calculator.py` запускает RTL-модель калькулятора через testbench и позволяет:
- нажимать клавиши матрицы (как в `emu145`);
- подавать семантические команды (`1`, `SIN`, `ENTER`, `+` и т.д.);
- смотреть итоговые кадры виртуального дисплея;
- строить отчёт «какая кнопка что изменила на дисплее».

Скрипт поддерживает движки `verilog|vhdl|hls` (`--engine`, по умолчанию `verilog`) и пишет артефакты в `logs/` и `rtl_trace.csv`.

## 2. Требования
Минимум:
- `python3`
- `iverilog`
- `vvp` (обычно ставится вместе с `iverilog`)

Проверка окружения:
```bash
./build_and_check.sh
```

## 3. Быстрый старт
Запустить одиночную проверку клавиши после инициализации:
```bash
./virtual_calculator.py --preset boot_probe --mode rad --cycles 260000 --start 100000 --gap 12000
```

Запуск того же сценария на разных ядрах:
```bash
./virtual_calculator.py --engine verilog --preset calc_12_enter_3_plus --preset-timing on
./virtual_calculator.py --engine hls --preset calc_12_enter_3_plus --preset-timing on
./virtual_calculator.py --engine vhdl --preset calc_12_enter_3_plus --preset-timing on
```

Посмотреть доступные пресеты и алиасы:
```bash
./virtual_calculator.py --list-presets
./virtual_calculator.py --list-keys
```

Запустить графический интерфейс (рекомендуется для повседневного использования):
```bash
./virtual_calculator_gui.py
```

## 3.1 Ежедневное использование через GUI
Окна и элементы:
- верхний экран: текущее состояние виртуального дисплея;
- `Текущая последовательность`: набранные токены;
- `Клавиатура`: цифровые и функциональные кнопки;
- `Сценарии и команды`: запуск пресетов и произвольных токенов;
- `Лог`: последние команды и результаты запуска.

Рекомендуемый рабочий цикл:
1. Запустите `./virtual_calculator_gui.py`.
2. Наберите последовательность кнопками (например: `1`, `ENTER`, `2`, `+`).
3. Если включён `Auto-run after key press`, пересчёт выполняется автоматически.
4. Иначе нажмите `Запустить`.
5. Смотрите итог на дисплее и в строке `last sync cycle`.

Полезно:
- `⌫ Backspace` удаляет последний токен.
- `Очистить` очищает текущую последовательность и экран.
- `Запустить preset` — готовые сценарии (`boot_probe`, `scan_all`, и т.д.).
- поле `Токены (через пробел)` позволяет ввести последовательность вручную.

Параметры в GUI:
- `Mode`: `rad/deg/grd`
- `Cycles`: длина симуляции
- `Start`: цикл начала ввода
- `Gap`: интервал между кнопками
- `Frames`: количество последних кадров в выводе
- `Skip rebuild after first success`: ускоряет повторные прогоны через `--no-build`

## 4. Основные режимы ввода

### 4.1 Клавиши матрицы (`--keys`, режим buttons)
Форматы токенов:
- `B_1_2` (канонический)
- `R1D2`
- `1:2`
- `KEY_1_2`
- `POS00`, `K00` ... `POS29`, `K29`

Пример:
```bash
./virtual_calculator.py --keys "B_1_3 B_2_9 B_1_4 B_2_2" --cycles 420000 --start 100000 --gap 15000
```

### 4.2 Семантические токены (`--expr`)
Токены автоматически разворачиваются в физические клавиши по `emu145` keymap.

Примеры:
```bash
# RPN: 1 ENTER 2 +
./virtual_calculator.py --expr "1 ENTER 2 +" --cycles 420000 --start 100000 --gap 15000

# Функция SIN: разворачивается в F + соответствующая кнопка
./virtual_calculator.py --expr "1 SIN" --cycles 420000 --start 100000 --gap 15000
```

### 4.3 Низкоуровневый режим линий K1/K2 (`--keys`, режим keys)
Поддерживаемые токены:
- `K1`, `K2`, `K12`, `NONE` (`_`, `PAUSE` как синонимы паузы)

Пример:
```bash
./virtual_calculator.py --keys "K1 K2 K12 NONE" --hold 20 --gap 300 --cycles 220000
```

## 5. Приоритет источника входа
Скрипт выбирает источник в таком порядке:
1. `--expr`
2. `--keys`
3. `--preset`
4. если ничего не передано — `boot_probe`

## 6. Полезные параметры
- `--cycles` — длительность симуляции (по умолчанию `320000`)
- `--start` — цикл первого события (по умолчанию `100000`)
- `--gap` — интервал между нажатиями (по умолчанию `12000`)
- `--hold` — длительность удержания (только low-level режим)
- `--mode rad|deg|grd` — угловой режим
- `--engine verilog|vhdl|hls` — выбор ядра RTL
- `--frames N` — сколько последних sync-кадров печатать
- `--report-events` — печать эффекта каждой кнопки на дисплей
- `--no-build` — не запускать `iverilog` перед `vvp`

Рекомендация для матрицы кнопок:
- обычно используйте `--start 100000` и `--gap 12000..20000`.

## 7. Пресеты
Текущий набор:
- `boot_probe`
- `scan_row1`
- `scan_all`
- `calc_1_2_plus_3_eq`
- `calc_1_enter_2_plus`
- `calc_12_enter_3_plus`
- `func_sin_1`

Запуск:
```bash
./virtual_calculator.py --preset scan_all --cycles 900000 --start 100000 --gap 20000 --report-events
```

## 8. Переопределение алиасов

### 8.1 Через CLI (`--alias`)
```bash
./virtual_calculator.py --expr "1 SIN" --alias SIN=F+B_1_9
```

### 8.2 Через файл (`--aliases-file`)
Пример файла: `mk61_aliases.example.txt`

Запуск:
```bash
./virtual_calculator.py --expr "1 ENTER 2 +" --aliases-file mk61_aliases.example.txt
```

Поддерживаются макро-алиасы:
- `NAME=B_row_dnum`
- `NAME=B_row_dnum+B_row_dnum`
- `NAME=TOKEN1 TOKEN2`

## 9. Что смотреть в выводе
После запуска скрипт печатает:
- источник ввода (`Input source`);
- режим (`Input mode`);
- исходные и развёрнутые токены;
- путь к файлу событий;
- путь к логу `vvp`;
- последние кадры дисплея.

При `--report-events` дополнительно:
- для каждой кнопки: базовый кадр и первый изменённый кадр.

## 10. Артефакты
- `logs/virtual_buttons.txt` — события матрицы
- `logs/virtual_keys.txt` — low-level события
- `logs/virtual_vvp.log` — stdout/stderr симулятора
- `rtl_trace.csv` — пошаговый trace RTL
- `tb_mk61.vcd` — waveform dump testbench

## 11. Типовые проблемы

### Проблема: «кнопки не реагируют»
Проверьте:
- слишком ранний старт (`--start` слишком мал) — поставьте `100000`;
- слишком маленький `--gap` — увеличьте до `12000..20000`;
- недостаёт `--cycles` — увеличьте общее число циклов.

### Проблема: неверный токен
Скрипт вернёт `Unsupported key token(s)` или `Invalid button token`.
Проверьте формат токенов через:
```bash
./virtual_calculator.py --list-keys
```

### Проблема: ошибка команды `iverilog`/`vvp`
Смотрите:
- `logs/virtual_vvp.log`
- `logs/iverilog.log` (если запускали общий пайплайн)

## 12. Сверка с эталоном emu145
Для побитовой/покадровой сверки поведения:
```bash
./tools/build_emu145_ref.sh
./tools/compare_rtl_emu145.py --skip-build
```

Итоговая сводка:
- `logs/compare/summary.md`
