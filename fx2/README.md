# FX2LP bridge for Tang Nano 1K MK-61

Этот каталог содержит полный стек для внешнего USB-контроллера `EZ-USB FX2LP CY7C68013A`,
который управляет FPGA-ядром MK-61 на `Tang Nano 1K`.

## Архитектура

```
PC (Python)
  -> USB control transfers
FX2LP firmware (CY7C68013A)
  -> формирует clk/rst/k1/k2/mode
  -> выполняет step-движок и queue кнопок
  -> собирает display frame (dcycle/sync/segment)
Tang Nano 1K (mk61_top_1k_fx2)
```

## Поддерживаемый профиль FPGA

- top: `mk61_top_1k_fx2`
- cst: `fpga/tangnano1k/tangnano1k_fx2_mk61_top_1k_fx2.cst`
- сборка:

```bash
./synth_tangnano1k.sh --util-only --fx2
./build_tangnano1k.sh --fx2 --flash
```

## Распиновка FX2 <-> Tang Nano 1K

FX2 output -> FPGA input:

- `PA0` -> `clk` (pin 47)
- `PA1` -> `rst` (pin 40)
- `PA2` -> `k1` (pin 41)
- `PA3` -> `k2` (pin 38)
- `PA4` -> `mode[0]` (pin 39)
- `PA5` -> `mode[1]` (pin 42)

FPGA output -> FX2 input:

- `dcycle[0]` (pin 15) -> `PB0`
- `dcycle[1]` (pin 16) -> `PB1`
- `dcycle[2]` (pin 17) -> `PB2`
- `dcycle[3]` (pin 18) -> `PB3`
- `syncout` (pin 19) -> `PB4`
- `scan_active` (pin 44) -> `PB5`
- `segment[0..7]` (pins 20,22,23,24,27,28,29,30) -> `PD0..PD7`

Обязательно:

- общий `GND` между FX2 и Tang
- уровни `3.3V` (не 5V)
- короткие провода для `clk`/`sync` линий

## Сборка прошивки FX2

```bash
./fx2/firmware/build_fx2_fw.sh
```

Артефакт:

- `fx2/firmware/build/mk61_fx2_fw.ihx`

## Зависимости host-части

```bash
brew install libusb
python3 -m pip install pyusb
```

## Загрузка прошивки в FX2

```bash
./fx2/fx2_loader.py --ihx fx2/firmware/build/mk61_fx2_fw.ihx
```

По умолчанию:

- boot VID:PID = `04b4:8613`
- runtime VID:PID = `04b4:1004`

## Запуск калькулятора через FX2

```bash
./fx2/fx2_virtual_calculator.py --preset calc_12_enter_3_plus --mode rad
./fx2/fx2_virtual_calculator.py --expr "PI"
./fx2/fx2_virtual_calculator.py --list-presets
./fx2/fx2_virtual_calculator.py --list-keys
```

Опции для отладки таймингов:

- `--hold` (длительность удержания строки кнопки)
- `--gap-cycles` (пауза между кнопками)
- `--step-chunk` (размер USB step блока)
- `--no-scan-gate` (отключить `scan_active`-гейт)
- `--no-auto-k2` (отключить авто-импульс `k2`)

## Протокол vendor-команд FX2

- `0xB0` IN: `GET_INFO`
- `0xB1` OUT: `SET_CONTROL`
- `0xB2` IN: `STEP` (`wValue = cycles`)
- `0xB3` OUT: `QUEUE_BUTTON` (`wValue.low=row`, `wValue.high=col`)
- `0xB4` IN: `GET_STATE`
- `0xB5` OUT: `SET_HOLD`
- `0xB6` OUT: `CLEAR_FRAME`

Состояние (ответ `GET_INFO/GET_STATE/STEP`) содержит:

- флаги/режим
- `dcycle`, `segment`, `frame_counter`
- pending/active key state
- полный виртуальный дисплей `12 x segment`
