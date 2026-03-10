#pragma once

#include "../hls/mk61_hls.hpp"

#include <array>
#include <cstdint>
#include <deque>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace mk61nspire {

inline constexpr int kResetCycles = 8;
inline constexpr int kDefaultBootCycles = 120000;
inline constexpr int kDefaultStartCycles = 0;
inline constexpr int kDefaultGapCycles = 90000;
inline constexpr int kDefaultSettleCycles = 6000;
inline constexpr int kDefaultPressTimeoutCycles = 300000;
inline constexpr int kDefaultPostCycles = 220000;

struct Button {
  int row;   // 1..3
  int col;   // 0..9, maps to D2..D11
  std::string canonical;
};

struct PressConfig {
  int start_cycles = kDefaultStartCycles;
  int gap_cycles = kDefaultGapCycles;
  int settle_cycles = kDefaultSettleCycles;
  int timeout_cycles = kDefaultPressTimeoutCycles;
  int post_cycles = kDefaultPostCycles;
};

using AliasMap = std::unordered_map<std::string, std::vector<Button>>;
using PresetMap = std::unordered_map<std::string, std::vector<std::string>>;

std::string trim(std::string s);
std::string upper(std::string s);
std::vector<std::string> split_tokens(const std::string& line);
std::string canonical_name(int row, int dnum);
Button make_button(int row, int dnum);
std::optional<Button> parse_button_token(const std::string& raw);
AliasMap build_aliases();
PresetMap build_presets();

class Mk61Engine {
 public:
  Mk61Engine();

  bool set_mode(const std::string& mode_raw);
  void hard_reset(int boot_cycles = kDefaultBootCycles);

  bool execute_token(const std::string& token_raw, const AliasMap& aliases, const PressConfig& cfg, std::string& err);
  bool execute_tokens(const std::vector<std::string>& tokens, const AliasMap& aliases, const PressConfig& cfg, std::string& err);

  void step_cycles(int cycles);

  std::string display_text() const;
  std::string display_compact() const;

  int cycles() const { return total_cycles_; }
  int frames() const { return frame_count_; }
  std::string mode_name() const { return mode_name_; }

 private:
  struct ScheduledButton {
    int cycle;
    Button button;
  };

  bool run_until_idle(const PressConfig& cfg, std::string& err);
  void step_one();
  void on_step_done();

  mk61hls::TopState state_{};
  mk61hls::TopInputs in_{};
  mk61hls::TopOutputs out_{};
  std::array<uint8_t, 12> display_{};
  std::deque<ScheduledButton> scheduled_buttons_{};
  std::optional<Button> active_button_{};

  int mode_id_ = 0;
  std::string mode_name_ = "RAD";
  int total_cycles_ = 0;
  int frame_count_ = 0;
  int next_event_cycle_ = 0;
};

}  // namespace mk61nspire
