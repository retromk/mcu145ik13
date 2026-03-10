#include "mk61_engine.hpp"

#include <string>

#ifdef NSPIRE_NDLESS
extern "C" {
#include <libndls.h>
#include <libnio.h>
#include <os.h>
}

#if !defined(KEY_NSPIRE_LEFT) || !defined(KEY_NSPIRE_RIGHT) || !defined(KEY_NSPIRE_UP) || !defined(KEY_NSPIRE_DOWN) || !defined(KEY_NSPIRE_ESC)
#error "Required nSpire key constants are missing in this Ndless SDK."
#endif

namespace {

std::string selected_token(int row_idx, int col_idx) {
  const int row = row_idx + 1;
  const int dnum = col_idx + 2;
  return mk61nspire::canonical_name(row, dnum);
}

bool select_pressed() {
#if defined(KEY_NSPIRE_CLICK)
  if (isKeyPressed(KEY_NSPIRE_CLICK)) return true;
#endif
#if defined(KEY_NSPIRE_ENTER)
  if (isKeyPressed(KEY_NSPIRE_ENTER)) return true;
#elif defined(KEY_NSPIRE_RET)
  if (isKeyPressed(KEY_NSPIRE_RET)) return true;
#endif
  return false;
}

void wait_key_release() {
  while (any_key_pressed()) {
    idle();
  }
}

void draw_ui(nio_console* csl,
             const mk61nspire::Mk61Engine& emu,
             int row_idx,
             int col_idx,
             const std::string& status_line) {
  nio_clear(csl);
  nio_printf(csl, "MK-61 for TI nSpire CX II\n");
  nio_printf(csl, "Display: %s\n", emu.display_compact().c_str());
  nio_printf(csl, "Mode: %s\n", emu.mode_name().c_str());
  nio_printf(csl, "Sel: %s\n", selected_token(row_idx, col_idx).c_str());
  nio_printf(csl, "Cyc:%d Frm:%d\n", emu.cycles(), emu.frames());
  nio_printf(csl, "%s\n", status_line.c_str());
  nio_printf(csl, "Arrows=move  Enter=press\n");
  nio_printf(csl, "ESC=quit");
#if defined(KEY_NSPIRE_DEL)
  nio_printf(csl, "  DEL=reset");
#endif
#if defined(KEY_NSPIRE_TAB)
  nio_printf(csl, "  TAB=mode");
#endif
  nio_printf(csl, "\n");
}

}  // namespace

int main() {
  nio_console csl;
  nio_init(&csl, NIO_MAX_COLS, NIO_MAX_ROWS, 0, 0, 0, 0, "MK-61 nSpire");

  const mk61nspire::AliasMap aliases = mk61nspire::build_aliases();
  mk61nspire::PressConfig cfg;
  mk61nspire::Mk61Engine emu;
  emu.hard_reset(mk61nspire::kDefaultBootCycles);

  int row_idx = 0;  // 0..2
  int col_idx = 0;  // 0..9
  int mode_idx = 0; // RAD
  std::string status = "ready";

  draw_ui(&csl, emu, row_idx, col_idx, status);

  while (true) {
    if (isKeyPressed(KEY_NSPIRE_ESC)) {
      wait_key_release();
      break;
    }

    bool redraw = false;

    if (isKeyPressed(KEY_NSPIRE_LEFT)) {
      col_idx = (col_idx + 9) % 10;
      redraw = true;
      wait_key_release();
    } else if (isKeyPressed(KEY_NSPIRE_RIGHT)) {
      col_idx = (col_idx + 1) % 10;
      redraw = true;
      wait_key_release();
    } else if (isKeyPressed(KEY_NSPIRE_UP)) {
      row_idx = (row_idx + 2) % 3;
      redraw = true;
      wait_key_release();
    } else if (isKeyPressed(KEY_NSPIRE_DOWN)) {
      row_idx = (row_idx + 1) % 3;
      redraw = true;
      wait_key_release();
    } else if (select_pressed()) {
      std::string err;
      const std::string token = selected_token(row_idx, col_idx);
      if (!emu.execute_token(token, aliases, cfg, err)) {
        status = "err: " + err;
      } else {
        status = "pressed " + token;
      }
      redraw = true;
      wait_key_release();
    }

#if defined(KEY_NSPIRE_DEL)
    else if (isKeyPressed(KEY_NSPIRE_DEL)) {
      emu.hard_reset(mk61nspire::kDefaultBootCycles);
      status = "reset";
      redraw = true;
      wait_key_release();
    }
#endif

#if defined(KEY_NSPIRE_TAB)
    else if (isKeyPressed(KEY_NSPIRE_TAB)) {
      mode_idx = (mode_idx + 1) % 3;
      if (mode_idx == 0) emu.set_mode("RAD");
      if (mode_idx == 1) emu.set_mode("DEG");
      if (mode_idx == 2) emu.set_mode("GRD");
      status = "mode " + emu.mode_name();
      redraw = true;
      wait_key_release();
    }
#endif

    if (redraw) {
      draw_ui(&csl, emu, row_idx, col_idx, status);
    }

    idle();
  }

  nio_free(&csl);
  return 0;
}

#else

int main() {
  return 1;
}

#endif
