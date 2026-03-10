#include "../nspire/mk61_engine.hpp"

#include <array>
#include <cstdint>
#include <string>

/*
 * HP Prime on-device porting stub.
 *
 * This file is intentionally SDK-agnostic and does not include HP Prime headers.
 * You can bind these hooks to your HP Prime SDK environment:
 *   - hpprime_draw_text()
 *   - hpprime_clear_screen()
 *   - hpprime_poll_key()
 *   - hpprime_sleep_ms()
 *
 * Then compile this module together with:
 *   ../nspire/mk61_engine.cpp
 *   ../hls/mk61_hls.cpp
 */

namespace {

enum class PrimeEventType : uint8_t {
  None = 0,
  Quit = 1,
  Reset = 2,
  ModeNext = 3,
  MatrixPress = 4,
};

struct PrimeEvent {
  PrimeEventType type = PrimeEventType::None;
  int row = 1;
  int dnum = 2;
};

void hpprime_clear_screen();
void hpprime_draw_text(int x, int y, const char* text);
PrimeEvent hpprime_poll_key();
void hpprime_sleep_ms(int ms);

class PrimeUiRunner {
 public:
  PrimeUiRunner() {
    aliases_ = mk61nspire::build_aliases();
    emu_.hard_reset(mk61nspire::kDefaultBootCycles);
  }

  void run() {
    draw("ready");
    while (true) {
      PrimeEvent ev = hpprime_poll_key();
      if (ev.type == PrimeEventType::None) {
        hpprime_sleep_ms(8);
        continue;
      }
      if (ev.type == PrimeEventType::Quit) {
        break;
      }
      if (ev.type == PrimeEventType::Reset) {
        emu_.hard_reset(mk61nspire::kDefaultBootCycles);
        draw("reset");
        continue;
      }
      if (ev.type == PrimeEventType::ModeNext) {
        mode_idx_ = (mode_idx_ + 1) % 3;
        if (mode_idx_ == 0) emu_.set_mode("RAD");
        if (mode_idx_ == 1) emu_.set_mode("DEG");
        if (mode_idx_ == 2) emu_.set_mode("GRD");
        draw("mode changed");
        continue;
      }
      if (ev.type == PrimeEventType::MatrixPress) {
        std::string err;
        const std::string token = mk61nspire::canonical_name(ev.row, ev.dnum);
        if (!emu_.execute_token(token, aliases_, cfg_, err)) {
          draw(err.c_str());
        } else {
          draw(token.c_str());
        }
      }
    }
  }

 private:
  void draw(const char* status) {
    hpprime_clear_screen();
    hpprime_draw_text(2, 2, "MK-61 for HP Prime");
    hpprime_draw_text(2, 18, ("Display: " + emu_.display_compact()).c_str());
    hpprime_draw_text(2, 34, ("Mode: " + emu_.mode_name()).c_str());
    hpprime_draw_text(2, 50, ("Status: " + std::string(status)).c_str());
  }

  mk61nspire::Mk61Engine emu_;
  mk61nspire::AliasMap aliases_;
  mk61nspire::PressConfig cfg_;
  int mode_idx_ = 0;
};

}  // namespace

/*
 * Entry point for HP Prime SDK integration.
 * Hook your platform startup to call this symbol.
 */
extern "C" int mk61_hpprime_main() {
  PrimeUiRunner runner;
  runner.run();
  return 0;
}

/*
 * Default empty hooks. Replace with HP Prime SDK bindings in your target build.
 */
namespace {
void hpprime_clear_screen() {}
void hpprime_draw_text(int, int, const char*) {}
PrimeEvent hpprime_poll_key() { return {}; }
void hpprime_sleep_ms(int) {}
}  // namespace
