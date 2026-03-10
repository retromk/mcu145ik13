#include "mk61_hls.hpp"

#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

struct KeyEvent {
  int cycle;
  int k1;
  int k2;
};

struct ButtonEvent {
  int cycle;
  int row;
  int col;
};

constexpr int kResetCycles = 8;
constexpr const char* kKeyEventsPath = "logs/virtual_keys.txt";
constexpr const char* kButtonEventsPath = "logs/virtual_buttons.txt";

int parse_int_arg(int argc, char** argv, const std::string& key, int default_value) {
  for (int i = 1; i + 1 < argc; ++i) {
    if (std::string(argv[i]) == key) {
      return std::stoi(argv[i + 1]);
    }
  }
  return default_value;
}

bool has_flag_arg(int argc, char** argv, const std::string& key) {
  for (int i = 1; i < argc; ++i) {
    if (std::string(argv[i]) == key) {
      return true;
    }
  }
  return false;
}

std::vector<KeyEvent> load_key_events(const std::string& path) {
  std::vector<KeyEvent> events;
  std::ifstream in(path);
  if (!in.is_open()) {
    return events;
  }

  int cyc = 0;
  int k1 = 0;
  int k2 = 0;
  while (in >> cyc >> k1 >> k2) {
    if (cyc < 0) {
      cyc = 0;
    }
    events.push_back(KeyEvent{cyc, (k1 != 0) ? 1 : 0, (k2 != 0) ? 1 : 0});
  }
  return events;
}

std::vector<ButtonEvent> load_button_events(const std::string& path) {
  std::vector<ButtonEvent> events;
  std::ifstream in(path);
  if (!in.is_open()) {
    return events;
  }

  int cyc = 0;
  int row = 0;
  int col = 0;
  while (in >> cyc >> row >> col) {
    if (cyc < 0) {
      cyc = 0;
    }
    if (row < 1 || row > 3 || col < 0 || col > 9) {
      continue;
    }
    events.push_back(ButtonEvent{cyc, row, col});
  }
  return events;
}

} // namespace

int main(int argc, char** argv) {
  const int sim_cycles = parse_int_arg(argc, argv, "--cycles", 20000);
  const bool use_external_events = has_flag_arg(argc, argv, "--use-external-events");
  int mode_sel = parse_int_arg(argc, argv, "--mode", 0);
  if (mode_sel < 0) {
    mode_sel = 0;
  }
  if (mode_sel > 2) {
    mode_sel = 2;
  }

  std::vector<ButtonEvent> button_events;
  std::vector<KeyEvent> key_events;

  if (use_external_events) {
    if (std::filesystem::exists(kButtonEventsPath)) {
      button_events = load_button_events(kButtonEventsPath);
    }
    if (button_events.empty() && std::filesystem::exists(kKeyEventsPath)) {
      key_events = load_key_events(kKeyEventsPath);
    }
  }

  enum class InputMode { Keys, Buttons };
  InputMode input_mode = InputMode::Buttons;

  if (use_external_events && !button_events.empty()) {
    input_mode = InputMode::Buttons;
    std::cout << "[TB-HLS] loaded " << button_events.size() << " button events from " << kButtonEventsPath << "\n";
  } else if (use_external_events && !key_events.empty()) {
    input_mode = InputMode::Keys;
    std::cout << "[TB-HLS] loaded " << key_events.size() << " key events from " << kKeyEventsPath << "\n";
  } else {
    input_mode = InputMode::Keys;
    key_events = {
        KeyEvent{200, 1, 0},
        KeyEvent{210, 0, 0},
        KeyEvent{600, 0, 1},
        KeyEvent{612, 0, 0},
        KeyEvent{1200, 1, 1},
        KeyEvent{1210, 0, 0},
    };
    std::cout << "[TB-HLS] using built-in key scenario\n";
  }

  std::size_t key_event_idx = 0;
  std::size_t button_event_idx = 0;
  bool btn_active = false;
  int btn_row = 0;
  int btn_col = 0;

  mk61hls::TopState state{};
  mk61hls::TopInputs in{};
  mk61hls::TopOutputs out{};

  std::ofstream trace("rtl_trace_hls.csv", std::ios::out | std::ios::trunc);
  if (!trace.is_open()) {
    std::cerr << "[ERR] cannot open rtl_trace_hls.csv\n";
    return 1;
  }
  trace << "cycle,dcycle,sync,seg,k1,k2\n";

  in.rst = true;
  in.k1 = false;
  in.k2 = false;
  in.mode = static_cast<uint8_t>(mode_sel);

  for (int i = 0; i < kResetCycles; ++i) {
    mk61hls::top_step(state, in, out);
  }

  in.rst = false;

  for (int cyc = 0; cyc < sim_cycles; ++cyc) {
    if (input_mode == InputMode::Buttons) {
      while (!btn_active && button_event_idx < button_events.size() && button_events[button_event_idx].cycle <= cyc) {
        btn_row = button_events[button_event_idx].row;
        btn_col = button_events[button_event_idx].col;
        btn_active = true;
        ++button_event_idx;
      }

      in.k1 = false;
      in.k2 = false;

      if (state.phase == 0u) {
        const bool display_window = ((state.u0.command & 0x00FC0000u) == 0u);

        if (display_window && state.u0.dcount == 12u) {
          in.k2 = true;
        }

        if (btn_active && display_window && state.u0.dcount == static_cast<uint8_t>(btn_col + 1)) {
          if (btn_row == 1) {
            in.k1 = true;
            in.k2 = false;
          } else if (btn_row == 2) {
            in.k1 = false;
            in.k2 = true;
          } else if (btn_row == 3) {
            in.k1 = true;
            in.k2 = true;
          }
          btn_active = false;
        }
      }
    } else {
      while (key_event_idx < key_events.size() && key_events[key_event_idx].cycle == cyc) {
        in.k1 = (key_events[key_event_idx].k1 != 0);
        in.k2 = (key_events[key_event_idx].k2 != 0);
        ++key_event_idx;
      }
    }

    mk61hls::top_step(state, in, out);

    trace << cyc << ',' << static_cast<int>(out.dcycle) << ',' << (out.syncout ? 1 : 0) << ','
          << static_cast<int>(out.segment) << ',' << (in.k1 ? 1 : 0) << ',' << (in.k2 ? 1 : 0) << '\n';
  }

  std::cout << "[OK] generated rtl_trace_hls.csv (cycles=" << sim_cycles << " mode=" << mode_sel << ")\n";
  return 0;
}
