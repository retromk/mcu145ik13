#include "../hls/mk61_hls.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <deque>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

constexpr int kResetCycles = 8;
constexpr int kDefaultBootCycles = 120000;
constexpr int kDefaultStartCycles = 0;
constexpr int kDefaultGapCycles = 90000;
constexpr int kDefaultSettleCycles = 6000;
constexpr int kDefaultPressTimeoutCycles = 300000;
constexpr int kDefaultPostCycles = 220000;
constexpr char kSegChars[] = "0123456789-LCrE ";

struct Button {
  int row;
  int col;
  std::string canonical;
};

struct PressConfig {
  int start_cycles = kDefaultStartCycles;
  int gap_cycles = kDefaultGapCycles;
  int settle_cycles = kDefaultSettleCycles;
  int timeout_cycles = kDefaultPressTimeoutCycles;
  int post_cycles = kDefaultPostCycles;
};

struct ScheduledButton {
  int cycle;
  Button button;
};

using AliasMap = std::unordered_map<std::string, std::vector<Button>>;
using PresetMap = std::unordered_map<std::string, std::vector<std::string>>;

std::string trim(std::string s) {
  while (!s.empty() && std::isspace(static_cast<unsigned char>(s.front()))) s.erase(s.begin());
  while (!s.empty() && std::isspace(static_cast<unsigned char>(s.back()))) s.pop_back();
  return s;
}

std::string upper(std::string s) {
  for (char& c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
  return s;
}

std::vector<std::string> split_tokens(const std::string& line) {
  std::vector<std::string> out;
  std::string cur;
  for (char c : line) {
    if (std::isspace(static_cast<unsigned char>(c)) || c == ',' || c == ';') {
      if (!cur.empty()) {
        out.push_back(cur);
        cur.clear();
      }
    } else {
      cur.push_back(c);
    }
  }
  if (!cur.empty()) out.push_back(cur);
  return out;
}

std::string canonical_name(int row, int dnum) {
  return "B_" + std::to_string(row) + "_" + std::to_string(dnum);
}

Button make_button(int row, int dnum) {
  return Button{row, dnum - 2, canonical_name(row, dnum)};
}

std::optional<int> parse_small_int(const std::string& s) {
  if (s.empty()) return std::nullopt;
  int v = 0;
  for (char c : s) {
    if (!std::isdigit(static_cast<unsigned char>(c))) return std::nullopt;
    v = v * 10 + (c - '0');
  }
  return v;
}

std::optional<Button> parse_button_token(const std::string& raw) {
  std::string t = upper(raw);

  auto parse_by_row_dnum = [](int row, int dnum) -> std::optional<Button> {
    if (row < 1 || row > 3 || dnum < 2 || dnum > 11) return std::nullopt;
    return make_button(row, dnum);
  };

  if (t.size() >= 4 && t[0] == 'B' && t[1] == '_') {
    std::size_t p = t.find('_', 2);
    if (p != std::string::npos) {
      auto row = parse_small_int(t.substr(2, p - 2));
      auto dnum = parse_small_int(t.substr(p + 1));
      if (row && dnum) return parse_by_row_dnum(*row, *dnum);
    }
  }

  if (t.size() >= 4 && t[0] == 'R') {
    std::size_t p = t.find('D', 1);
    if (p != std::string::npos) {
      auto row = parse_small_int(t.substr(1, p - 1));
      auto dnum = parse_small_int(t.substr(p + 1));
      if (row && dnum) return parse_by_row_dnum(*row, *dnum);
    }
  }

  std::size_t colon = t.find(':');
  if (colon != std::string::npos) {
    auto row = parse_small_int(t.substr(0, colon));
    auto dnum = parse_small_int(t.substr(colon + 1));
    if (row && dnum) return parse_by_row_dnum(*row, *dnum);
  }

  return std::nullopt;
}

void add_alias(AliasMap& m, const std::string& key, std::initializer_list<Button> seq) {
  m[upper(key)] = std::vector<Button>(seq);
}

AliasMap build_aliases() {
  AliasMap a;

  for (int row = 1; row <= 3; ++row) {
    for (int d = 2; d <= 11; ++d) {
      const Button b = make_button(row, d);
      add_alias(a, b.canonical, {b});
      add_alias(a, "R" + std::to_string(row) + "D" + std::to_string(d), {b});
      add_alias(a, std::to_string(row) + ":" + std::to_string(d), {b});
    }
  }

  const Button f = make_button(3, 11);
  const Button k = make_button(3, 10);

  add_alias(a, "0", {make_button(1, 2)});
  add_alias(a, "1", {make_button(1, 3)});
  add_alias(a, "2", {make_button(1, 4)});
  add_alias(a, "3", {make_button(1, 5)});
  add_alias(a, "4", {make_button(1, 6)});
  add_alias(a, "5", {make_button(1, 7)});
  add_alias(a, "6", {make_button(1, 8)});
  add_alias(a, "7", {make_button(1, 9)});
  add_alias(a, "8", {make_button(1, 10)});
  add_alias(a, "9", {make_button(1, 11)});

  add_alias(a, "+", {make_button(2, 2)});
  add_alias(a, "-", {make_button(2, 3)});
  add_alias(a, "*", {make_button(2, 4)});
  add_alias(a, "X", {make_button(2, 4)});
  add_alias(a, "/", {make_button(2, 5)});
  add_alias(a, ".", {make_button(2, 7)});
  add_alias(a, ",", {make_button(2, 7)});
  add_alias(a, "SIGN", {make_button(2, 8)});
  add_alias(a, "/-/", {make_button(2, 8)});

  add_alias(a, "ENTER", {make_button(2, 9)});
  add_alias(a, "=", {make_button(2, 9)});
  add_alias(a, "VP", {make_button(2, 9)});
  add_alias(a, "V", {make_button(2, 11)});
  add_alias(a, "CX", {make_button(2, 10)});
  add_alias(a, "CLR", {make_button(2, 10)});
  add_alias(a, "CLEAR", {make_button(2, 10)});

  add_alias(a, "F", {f});
  add_alias(a, "K", {k});
  add_alias(a, "SP", {make_button(3, 2)});
  add_alias(a, "BP", {make_button(3, 3)});
  add_alias(a, "VO", {make_button(3, 4)});
  add_alias(a, "PP", {make_button(3, 5)});
  add_alias(a, "X2P", {make_button(3, 6)});
  add_alias(a, "P2X", {make_button(3, 8)});

  add_alias(a, "PI", {f, make_button(2, 2)});
  add_alias(a, "SIN", {f, make_button(1, 9)});
  add_alias(a, "COS", {f, make_button(1, 10)});
  add_alias(a, "TG", {f, make_button(1, 11)});
  add_alias(a, "TAN", {f, make_button(1, 11)});
  add_alias(a, "SQRT", {f, make_button(2, 3)});
  add_alias(a, "X2", {f, make_button(2, 4)});
  add_alias(a, "X^2", {f, make_button(2, 4)});
  add_alias(a, "INVX", {f, make_button(2, 5)});
  add_alias(a, "1/X", {f, make_button(2, 5)});
  add_alias(a, "POW", {f, make_button(2, 6)});
  add_alias(a, "X^Y", {f, make_button(2, 6)});

  return a;
}

PresetMap build_presets() {
  PresetMap p;
  p["BOOT"] = {"1"};
  p["CALC_12_ENTER_3_PLUS"] = {"1", "2", "V", "+", "3", "+"};
  p["CALC_1_ENTER_2_PLUS"] = {"1", "V", "+", "2", "+"};
  p["PI"] = {"PI"};
  p["SIN0"] = {"0", "SIN"};
  return p;
}

class Mk61PicoCalc {
 public:
  Mk61PicoCalc() {
    set_mode("RAD");
    hard_reset(kDefaultBootCycles);
  }

  bool set_mode(const std::string& mode_raw) {
    const std::string mode = upper(trim(mode_raw));
    if (mode == "RAD") {
      mode_id_ = 0;
      mode_name_ = "RAD";
      in_.mode = 0;
      return true;
    }
    if (mode == "DEG") {
      mode_id_ = 1;
      mode_name_ = "DEG";
      in_.mode = 1;
      return true;
    }
    if (mode == "GRD") {
      mode_id_ = 2;
      mode_name_ = "GRD";
      in_.mode = 2;
      return true;
    }
    return false;
  }

  void hard_reset(int boot_cycles) {
    mk61hls::top_reset(state_);

    display_.fill(0x0F);
    display_[7] = 0x80;

    total_cycles_ = 0;
    frame_count_ = 0;
    active_button_.reset();
    scheduled_buttons_.clear();
    next_event_cycle_ = 0;

    in_ = {};
    in_.rst = true;
    in_.mode = static_cast<uint8_t>(mode_id_);

    for (int i = 0; i < kResetCycles; ++i) {
      mk61hls::top_step(state_, in_, out_);
      on_step_done();
    }

    in_.rst = false;
    step_cycles(std::max(0, boot_cycles));

    active_button_.reset();
    scheduled_buttons_.clear();
    next_event_cycle_ = total_cycles_;
  }

  bool execute_token(const std::string& token_raw, const AliasMap& aliases, const PressConfig& cfg, std::string& err) {
    return execute_tokens(std::vector<std::string>{token_raw}, aliases, cfg, err);
  }

  bool execute_tokens(const std::vector<std::string>& tokens, const AliasMap& aliases, const PressConfig& cfg, std::string& err) {
    int schedule_cycle = std::max(total_cycles_ + std::max(0, cfg.start_cycles), next_event_cycle_);
    bool queued_any = false;

    for (const std::string& tok : tokens) {
      const std::string t = upper(trim(tok));
      if (t.empty()) continue;

      if (t == "NONE" || t == "_" || t == "PAUSE") {
        schedule_cycle += std::max(0, cfg.gap_cycles);
        continue;
      }

      std::vector<Button> seq;
      auto it = aliases.find(t);
      if (it != aliases.end()) {
        seq = it->second;
      } else {
        auto btn = parse_button_token(t);
        if (!btn.has_value()) {
          err = "Unknown token: " + tok;
          return false;
        }
        seq.push_back(*btn);
      }

      for (const Button& b : seq) {
        queued_any = true;
        scheduled_buttons_.push_back(ScheduledButton{schedule_cycle, b});
        schedule_cycle += std::max(0, cfg.gap_cycles);
      }
    }

    next_event_cycle_ = schedule_cycle;

    if (!queued_any) {
      if (cfg.settle_cycles > 0) {
        step_cycles(cfg.settle_cycles);
      }
      return true;
    }

    if (!run_until_idle(cfg, err)) {
      return false;
    }

    if (cfg.post_cycles > 0) {
      step_cycles(cfg.post_cycles);
    }
    return true;
  }

  void step_cycles(int cycles) {
    for (int i = 0; i < cycles; ++i) {
      step_one();
    }
  }

  std::string display_text() const {
    std::string out;
    auto append_seg = [&](uint8_t seg) {
      const unsigned idx = static_cast<unsigned>(seg & 0x0F);
      char c = (idx < sizeof(kSegChars) - 1) ? kSegChars[idx] : '?';
      out.push_back(c);
      if (seg & 0x80) out.push_back('.');
    };

    for (int i = 0; i < 9; ++i) append_seg(display_[8 - i]);
    for (int i = 0; i < 3; ++i) append_seg(display_[11 - i]);
    return out;
  }

  std::string display_compact() const {
    std::string t = display_text();
    std::string out;
    for (char c : t) {
      if (c != ' ') out.push_back(c);
    }
    while (!out.empty() && out.back() == '.') out.pop_back();
    if (out.empty()) out = "0";
    return out;
  }

  int cycles() const { return total_cycles_; }
  int frames() const { return frame_count_; }
  std::string mode_name() const { return mode_name_; }

 private:
  bool run_until_idle(const PressConfig& cfg, std::string& err) {
    const int settle_cycles = std::max(0, cfg.settle_cycles);
    int future_span = 0;
    if (!scheduled_buttons_.empty()) {
      future_span = std::max(0, scheduled_buttons_.back().cycle - total_cycles_);
    }

    const int max_wait = std::max(1, cfg.timeout_cycles) + future_span + settle_cycles + 256;
    int idle_cycles = 0;

    for (int i = 0; i < max_wait; ++i) {
      step_one();
      const bool idle = scheduled_buttons_.empty() && !active_button_.has_value();
      if (idle) {
        idle_cycles++;
        if (idle_cycles > settle_cycles) {
          return true;
        }
      } else {
        idle_cycles = 0;
      }
    }

    err = "Timed out while waiting scheduled buttons to complete";
    return false;
  }

  void step_one() {
    if (!active_button_.has_value()) {
      while (!scheduled_buttons_.empty() && scheduled_buttons_.front().cycle <= total_cycles_) {
        active_button_ = scheduled_buttons_.front().button;
        scheduled_buttons_.pop_front();
        break;
      }
    }

    in_.k1 = false;
    in_.k2 = false;
    in_.mode = static_cast<uint8_t>(mode_id_);

    if (state_.phase == 0u) {
      const bool display_window = ((state_.u0.command & 0x00FC0000u) == 0u);

      if (display_window && state_.u0.dcount == 12u) {
        in_.k2 = true;
      }

      if (active_button_.has_value() && display_window && state_.u0.dcount == static_cast<uint8_t>(active_button_->col + 1)) {
        switch (active_button_->row) {
          case 1:
            in_.k1 = true;
            in_.k2 = false;
            break;
          case 2:
            in_.k1 = false;
            in_.k2 = true;
            break;
          case 3:
            in_.k1 = true;
            in_.k2 = true;
            break;
          default:
            in_.k1 = false;
            in_.k2 = false;
            break;
        }
        active_button_.reset();
      }
    }

    mk61hls::top_step(state_, in_, out_);
    on_step_done();
  }

  void on_step_done() {
    if (out_.dcycle >= 2u && out_.dcycle <= 13u) {
      display_[out_.dcycle - 2u] = out_.segment;
    }
    if (out_.syncout) {
      frame_count_++;
    }
    total_cycles_++;
  }

  mk61hls::TopState state_{};
  mk61hls::TopInputs in_{};
  mk61hls::TopOutputs out_{};
  std::array<uint8_t, 12> display_{};
  std::deque<ScheduledButton> scheduled_buttons_;
  std::optional<Button> active_button_;

  int mode_id_ = 0;
  std::string mode_name_ = "RAD";
  int total_cycles_ = 0;
  int frame_count_ = 0;
  int next_event_cycle_ = 0;
};

void print_help() {
  std::cout
      << "Commands:\n"
      << "  /help                  show this help\n"
      << "  /display               show current display\n"
      << "  /mode rad|deg|grd      set angle mode\n"
      << "  /reset                 full reset + boot warm-up\n"
      << "  /step N                advance raw cycles\n"
      << "  /preset NAME           run built-in preset\n"
      << "  /presets               list preset names\n"
      << "  /quit                  exit\n"
      << "Input without '/' is treated as token sequence, example:\n"
      << "  1 2 V + 3 +\n"
      << "  PI\n"
      << "  9 SQRT\n";
}

void print_banner(const Mk61PicoCalc& emu) {
  std::cout << "MK-61 PicoCalc emulator (HLS core)\n";
  std::cout << "mode=" << emu.mode_name() << " cycles=" << emu.cycles() << " frames=" << emu.frames() << "\n";
  std::cout << "display: " << emu.display_text() << "\n";
  std::cout << "compact: " << emu.display_compact() << "\n";
  std::cout << "Type /help for commands.\n";
}

}  // namespace

int main(int argc, char** argv) {
  int boot_cycles = kDefaultBootCycles;
  PressConfig cfg;
  std::string mode = "rad";

  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    auto need_value = [&](const std::string& name) -> std::string {
      if (i + 1 >= argc) {
        throw std::runtime_error("Missing value for " + name);
      }
      return argv[++i];
    };

    if (arg == "--boot-cycles") {
      boot_cycles = std::max(0, std::stoi(need_value(arg)));
    } else if (arg == "--start-cycles") {
      cfg.start_cycles = std::max(0, std::stoi(need_value(arg)));
    } else if (arg == "--gap-cycles") {
      cfg.gap_cycles = std::max(0, std::stoi(need_value(arg)));
    } else if (arg == "--settle-cycles") {
      cfg.settle_cycles = std::max(0, std::stoi(need_value(arg)));
    } else if (arg == "--press-timeout") {
      cfg.timeout_cycles = std::max(1, std::stoi(need_value(arg)));
    } else if (arg == "--post-cycles") {
      cfg.post_cycles = std::max(0, std::stoi(need_value(arg)));
    } else if (arg == "--mode") {
      mode = need_value(arg);
    } else if (arg == "-h" || arg == "--help") {
      print_help();
      return 0;
    } else {
      std::cerr << "Unknown argument: " << arg << "\n";
      return 1;
    }
  }

  try {
    const AliasMap aliases = build_aliases();
    const PresetMap presets = build_presets();

    Mk61PicoCalc emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "mk61> ";
      if (!std::getline(std::cin, line)) break;
      line = trim(line);
      if (line.empty()) continue;

      if (line[0] == '/') {
        std::vector<std::string> cmd = split_tokens(line.substr(1));
        if (cmd.empty()) continue;
        const std::string op = upper(cmd[0]);

        if (op == "HELP") {
          print_help();
          continue;
        }
        if (op == "QUIT" || op == "EXIT") {
          break;
        }
        if (op == "DISPLAY") {
          std::cout << "display: " << emu.display_text() << "\n";
          std::cout << "compact: " << emu.display_compact() << "\n";
          continue;
        }
        if (op == "MODE") {
          if (cmd.size() < 2) {
            std::cout << "usage: /mode rad|deg|grd\n";
            continue;
          }
          if (!emu.set_mode(cmd[1])) {
            std::cout << "invalid mode\n";
            continue;
          }
          std::cout << "mode set to " << emu.mode_name() << "\n";
          continue;
        }
        if (op == "RESET") {
          emu.hard_reset(boot_cycles);
          std::cout << "reset done\n";
          std::cout << "compact: " << emu.display_compact() << "\n";
          continue;
        }
        if (op == "STEP") {
          if (cmd.size() < 2) {
            std::cout << "usage: /step N\n";
            continue;
          }
          int n = 0;
          try {
            n = std::stoi(cmd[1]);
          } catch (...) {
            std::cout << "invalid number\n";
            continue;
          }
          emu.step_cycles(std::max(0, n));
          std::cout << "cycles=" << emu.cycles() << " frames=" << emu.frames() << " compact=" << emu.display_compact() << "\n";
          continue;
        }
        if (op == "PRESETS") {
          std::cout << "Available presets:\n";
          for (const auto& kv : presets) {
            std::cout << "  " << kv.first << "\n";
          }
          continue;
        }
        if (op == "PRESET") {
          if (cmd.size() < 2) {
            std::cout << "usage: /preset NAME\n";
            continue;
          }
          const std::string key = upper(cmd[1]);
          auto it = presets.find(key);
          if (it == presets.end()) {
            std::cout << "unknown preset\n";
            continue;
          }
          std::string err;
          if (!emu.execute_tokens(it->second, aliases, cfg, err)) {
            std::cout << "error: " << err << "\n";
            continue;
          }
          std::cout << "preset done, compact=" << emu.display_compact() << "\n";
          continue;
        }

        std::cout << "unknown command. /help\n";
        continue;
      }

      const std::vector<std::string> tokens = split_tokens(line);
      std::string err;
      if (!emu.execute_tokens(tokens, aliases, cfg, err)) {
        std::cout << "error: " << err << "\n";
        continue;
      }
      std::cout << "compact: " << emu.display_compact() << "\n";
    }

    return 0;
  } catch (const std::exception& e) {
    std::cerr << "[ERR] " << e.what() << "\n";
    return 1;
  }
}
