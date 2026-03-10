#include "../nspire/mk61_engine.hpp"

#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

using mk61nspire::AliasMap;
using mk61nspire::Mk61Engine;
using mk61nspire::PresetMap;
using mk61nspire::PressConfig;
using Sb4KeyMap = std::unordered_map<std::string, std::vector<std::string>>;

Sb4KeyMap build_sb4_keymap() {
  Sb4KeyMap m;

  m["0"] = {"0"};
  m["1"] = {"1"};
  m["2"] = {"2"};
  m["3"] = {"3"};
  m["4"] = {"4"};
  m["5"] = {"5"};
  m["6"] = {"6"};
  m["7"] = {"7"};
  m["8"] = {"8"};
  m["9"] = {"9"};

  m["+"] = {"+"};
  m["-"] = {"-"};
  m["*"] = {"*"};
  m["/"] = {"/"};
  m["."] = {"."};
  m["NEG"] = {"/-/"};

  m["A"] = {"V"};
  m["EXE"] = {"V"};
  m["ENTER"] = {"V"};
  m["RUN"] = {"V"};
  m["B"] = {"CX"};
  m["CLEAR"] = {"CX"};
  m["X"] = {"F"};
  m["Y"] = {"K"};
  m["L"] = {"F"};
  m["R"] = {"K"};
  m["ZL"] = {"F"};
  m["ZR"] = {"K"};

  m["PI"] = {"PI"};
  m["SIN"] = {"SIN"};
  m["COS"] = {"COS"};
  m["TAN"] = {"TG"};
  m["TG"] = {"TG"};
  m["SQRT"] = {"SQRT"};
  m["X2"] = {"X2"};
  m["INVX"] = {"INVX"};
  m["POW"] = {"POW"};

  m["#B_RRIGHT"] = {"V"}; // A
  m["#B_RDOWN"] = {"CX"}; // B
  m["#B_RUP"] = {"F"};    // X
  m["#B_RLEFT"] = {"K"};  // Y
  m["#B_L1"] = {"F"};     // L
  m["#B_R1"] = {"K"};     // R
  m["#B_S1"] = {"F"};     // ZL
  m["#B_S2"] = {"K"};     // ZR

  return m;
}

bool resolve_sb4_tokens(const std::vector<std::string>& in,
                        const Sb4KeyMap& smap,
                        std::vector<std::string>& out,
                        std::string& err) {
  out.clear();
  for (const std::string& raw : in) {
    const std::string t = mk61nspire::upper(mk61nspire::trim(raw));
    if (t.empty()) continue;

    auto it = smap.find(t);
    if (it != smap.end()) {
      out.insert(out.end(), it->second.begin(), it->second.end());
      continue;
    }

    if (mk61nspire::parse_button_token(t).has_value()) {
      out.push_back(t);
      continue;
    }

    err = "Unknown Smile BASIC key token: " + raw;
    return false;
  }
  return true;
}

void print_help() {
  std::cout
      << "Commands:\n"
      << "  /help                     show help\n"
      << "  /display                  show display\n"
      << "  /mode rad|deg|grd         set angle mode\n"
      << "  /reset                    reset calculator\n"
      << "  /step N                   advance raw cycles\n"
      << "  /preset NAME              run MK-61 preset\n"
      << "  /presets                  list presets\n"
      << "  /sb4 KEYS...              run Smile BASIC 4 key sequence\n"
      << "  /sb4-help                 show Switch/SB4 key aliases\n"
      << "  /quit                     exit\n"
      << "Raw input is MK-61 token sequence, examples:\n"
      << "  1 2 V + 3 +\n"
      << "  PI\n";
}

void print_sb4_help() {
  std::cout
      << "Smile BASIC 4 aliases -> MK-61:\n"
      << "  A/EXE/ENTER -> V\n"
      << "  B/CLEAR -> CX\n"
      << "  X or L or ZL -> F\n"
      << "  Y or R or ZR -> K\n"
      << "  Digits: 0..9\n"
      << "  Ops: + - * / . NEG\n"
      << "  Funcs: PI SIN COS TAN/TG SQRT X2 INVX POW\n"
      << "  Also accepted: #B_RRIGHT #B_RDOWN #B_RUP #B_RLEFT #B_L1 #B_R1 #B_S1 #B_S2\n"
      << "Example:\n"
      << "  /sb4 1 2 A + 3 +\n";
}

void print_banner(const Mk61Engine& emu) {
  std::cout << "MK-61 variant for Nintendo Switch (Smile BASIC 4, host)\n";
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
    const Sb4KeyMap sb4_map = build_sb4_keymap();

    Mk61Engine emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "switchSB4> ";
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
        if (op == "SB4-HELP") {
          print_sb4_help();
          continue;
        }
        if (op == "SB4") {
          if (cmd.size() < 2) {
            std::cout << "usage: /sb4 KEYS...\n";
            continue;
          }
          std::vector<std::string> raw_keys(cmd.begin() + 1, cmd.end());
          std::vector<std::string> mk61_tokens;
          std::string err;
          if (!resolve_sb4_tokens(raw_keys, sb4_map, mk61_tokens, err)) {
            std::cout << "error: " << err << "\n";
            continue;
          }
          if (!emu.execute_tokens(mk61_tokens, aliases, cfg, err)) {
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
