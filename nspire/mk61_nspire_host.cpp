#include "mk61_engine.hpp"

#include <iostream>
#include <string>
#include <vector>

namespace {

using mk61nspire::AliasMap;
using mk61nspire::Mk61Engine;
using mk61nspire::PresetMap;
using mk61nspire::PressConfig;

void print_grid() {
  std::cout << "MK-61 matrix (B_row_dnum):\n";
  std::cout << "row1: B_1_2 B_1_3 B_1_4 B_1_5 B_1_6 B_1_7 B_1_8 B_1_9 B_1_10 B_1_11\n";
  std::cout << "row2: B_2_2 B_2_3 B_2_4 B_2_5 B_2_6 B_2_7 B_2_8 B_2_9 B_2_10 B_2_11\n";
  std::cout << "row3: B_3_2 B_3_3 B_3_4 B_3_5 B_3_6 B_3_7 B_3_8 B_3_9 B_3_10 B_3_11\n";
}

void print_help() {
  std::cout
      << "Commands:\n"
      << "  /help                  show this help\n"
      << "  /display               show display\n"
      << "  /grid                  show MK-61 matrix grid\n"
      << "  /mode rad|deg|grd      set angle mode\n"
      << "  /reset                 full reset + boot warm-up\n"
      << "  /step N                advance raw cycles\n"
      << "  /press ROW DNUM        press matrix key, example: /press 2 11\n"
      << "  /preset NAME           run built-in preset\n"
      << "  /presets               list preset names\n"
      << "  /quit                  exit\n"
      << "Raw input is token sequence, examples:\n"
      << "  1 2 V + 3 +\n"
      << "  PI\n";
}

void print_banner(const Mk61Engine& emu) {
  std::cout << "MK-61 TI-nSpire variant (host debug mode)\n";
  std::cout << "mode=" << emu.mode_name() << " cycles=" << emu.cycles() << " frames=" << emu.frames() << "\n";
  std::cout << "display: " << emu.display_text() << "\n";
  std::cout << "compact: " << emu.display_compact() << "\n";
  std::cout << "Type /help for commands.\n";
}

}  // namespace

int main(int argc, char** argv) {
  int boot_cycles = mk61nspire::kDefaultBootCycles;
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
    const AliasMap aliases = mk61nspire::build_aliases();
    const PresetMap presets = mk61nspire::build_presets();

    Mk61Engine emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "mk61-nspire> ";
      if (!std::getline(std::cin, line)) break;
      line = mk61nspire::trim(line);
      if (line.empty()) continue;

      if (line[0] == '/') {
        std::vector<std::string> cmd = mk61nspire::split_tokens(line.substr(1));
        if (cmd.empty()) continue;
        const std::string op = mk61nspire::upper(cmd[0]);

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
        if (op == "GRID") {
          print_grid();
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
          std::cout << "reset done, compact=" << emu.display_compact() << "\n";
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
          const std::string key = mk61nspire::upper(cmd[1]);
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
        if (op == "PRESS") {
          if (cmd.size() < 3) {
            std::cout << "usage: /press ROW DNUM\n";
            continue;
          }
          std::string err;
          const std::string token = "B_" + cmd[1] + "_" + cmd[2];
          if (!emu.execute_token(token, aliases, cfg, err)) {
            std::cout << "error: " << err << "\n";
            continue;
          }
          std::cout << "compact: " << emu.display_compact() << "\n";
          continue;
        }

        std::cout << "unknown command. /help\n";
        continue;
      }

      const std::vector<std::string> tokens = mk61nspire::split_tokens(line);
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
