#include "mk61_engine.hpp"

#include <algorithm>
#include <array>
#include <cctype>

namespace mk61nspire {
namespace {

constexpr char kSegChars[] = "0123456789-LCrE ";

std::optional<int> parse_small_int(const std::string& s) {
  if (s.empty()) return std::nullopt;
  int v = 0;
  for (char c : s) {
    if (!std::isdigit(static_cast<unsigned char>(c))) return std::nullopt;
    v = v * 10 + (c - '0');
  }
  return v;
}

void add_alias(AliasMap& m, const std::string& key, std::initializer_list<Button> seq) {
  m[upper(key)] = std::vector<Button>(seq);
}

}  // namespace

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

Mk61Engine::Mk61Engine() {
  set_mode("RAD");
  hard_reset(kDefaultBootCycles);
}

bool Mk61Engine::set_mode(const std::string& mode_raw) {
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

void Mk61Engine::hard_reset(int boot_cycles) {
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

bool Mk61Engine::execute_token(const std::string& token_raw, const AliasMap& aliases, const PressConfig& cfg, std::string& err) {
  return execute_tokens(std::vector<std::string>{token_raw}, aliases, cfg, err);
}

bool Mk61Engine::execute_tokens(const std::vector<std::string>& tokens, const AliasMap& aliases, const PressConfig& cfg, std::string& err) {
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
    if (cfg.settle_cycles > 0) step_cycles(cfg.settle_cycles);
    return true;
  }

  if (!run_until_idle(cfg, err)) return false;

  if (cfg.post_cycles > 0) step_cycles(cfg.post_cycles);
  return true;
}

void Mk61Engine::step_cycles(int cycles) {
  for (int i = 0; i < cycles; ++i) {
    step_one();
  }
}

std::string Mk61Engine::display_text() const {
  std::string out;
  auto append_seg = [&](uint8_t seg) {
    const unsigned idx = static_cast<unsigned>(seg & 0x0F);
    const char c = (idx < sizeof(kSegChars) - 1) ? kSegChars[idx] : '?';
    out.push_back(c);
    if (seg & 0x80) out.push_back('.');
  };

  for (int i = 0; i < 9; ++i) append_seg(display_[8 - i]);
  for (int i = 0; i < 3; ++i) append_seg(display_[11 - i]);
  return out;
}

std::string Mk61Engine::display_compact() const {
  std::string t = display_text();
  std::string out;
  for (char c : t) {
    if (c != ' ') out.push_back(c);
  }
  while (!out.empty() && out.back() == '.') out.pop_back();
  if (out.empty()) out = "0";
  return out;
}

bool Mk61Engine::run_until_idle(const PressConfig& cfg, std::string& err) {
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
      if (idle_cycles > settle_cycles) return true;
    } else {
      idle_cycles = 0;
    }
  }

  err = "Timed out while waiting scheduled buttons to complete";
  return false;
}

void Mk61Engine::step_one() {
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

void Mk61Engine::on_step_done() {
  if (out_.dcycle >= 2u && out_.dcycle <= 13u) {
    display_[out_.dcycle - 2u] = out_.segment;
  }
  if (out_.syncout) {
    frame_count_++;
  }
  total_cycles_++;
}

}  // namespace mk61nspire
