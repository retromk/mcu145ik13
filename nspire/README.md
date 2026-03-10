# MK-61 Emulator Variant for TI nSpire CX II

Этот модуль добавляет отдельный вариант эмулятора МК-61 для TI nSpire CX II.

Архитектура:

- `mk61_engine.*` — общее ядро (HLS-модель + стабильные тайминги нажатий).
- `mk61_nspire_ndless.cpp` — frontend для Ndless (устройство nSpire).
- `mk61_nspire_host.cpp` — host-frontend для отладки на ПК.

## 1) Быстрый smoke-test на ПК

```bash
./nspire/build_host.sh
printf '1 2 V + 3 +\n/quit\n' | ./nspire/build/mk61_nspire_host
```

Ожидаемый результат: `compact: 15`.

## 2) Сборка под TI nSpire CX II (Ndless)

Требования:

- установлен Ndless SDK;
- в `PATH` доступны `nspire-g++` и `maketns`;
- либо задайте `NDLESS_HOME` в `Makefile.ndless`.

Сборка:

```bash
cd nspire
make -f Makefile.ndless
```

Результат:

- `nspire/build_ndless/mk61_nspire.tns` — файл приложения для калькулятора.

## 3) Управление на nSpire

- `Left/Right/Up/Down` — выбор кнопки в матрице МК-61 (B_row_dnum).
- `Enter`/`Click` — нажать выбранную кнопку.
- `Esc` — выход.
- `Del` — reset (если клавиша поддерживается SDK-макросом).
- `Tab` — переключение RAD/DEG/GRD (если клавиша поддерживается SDK-макросом).

## 4) Тайминги (как в стабильных пресетах)

По умолчанию ядро использует профиль:

- `start=0`
- `gap=90000`
- `settle=6000`
- `post=220000`

Это нужно, чтобы результат успевал проявиться после микропрограммных команд (например `PI`, `12 V + 3 +`).
