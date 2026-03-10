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
using Mk90KeyMap = std::unordered_map<std::string, std::vector<std::string>>;

Mk90KeyMap build_mk90_keymap() {
  Mk90KeyMap m;

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
  m["PLUS"] = {"+"};
  m["MINUS"] = {"-"};
  m["MUL"] = {"*"};
  m["DIV"] = {"/"};
  m["DOT"] = {"."};

  m["ENT"] = {"V"};
  m["ENTER"] = {"V"};
  m["EXE"] = {"V"};
  m["RUN"] = {"V"};

  m["CLR"] = {"CX"};
  m["CLEAR"] = {"CX"};
  m["CX"] = {"CX"};

  m["NEG"] = {"/-/"};
  m["SIGN"] = {"/-/"};
  m["CHS"] = {"/-/"};

  m["SIN"] = {"SIN"};
  m["COS"] = {"COS"};
  m["TAN"] = {"TG"};
  m["TG"] = {"TG"};
  m["PI"] = {"PI"};
  m["SQRT"] = {"SQRT"};
  m["SQR"] = {"X2"};
  m["X2"] = {"X2"};
  m["INV"] = {"INVX"};
  m["INVX"] = {"INVX"};
  m["POW"] = {"POW"};

  m["SHIFT"] = {"F"};
  m["ALPHA"] = {"K"};

  return m;
}

bool resolve_mk90_tokens(const std::vector<std::string>& in,
                         const Mk90KeyMap& mmap,
                         std::vector<std::string>& out,
                         std::string& err) {
  out.clear();
  for (const std::string& raw : in) {
    const std::string t = mk61nspire::upper(mk61nspire::trim(raw));
    if (t.empty()) continue;

    auto it = mmap.find(t);
    if (it != mmap.end()) {
      out.insert(out.end(), it->second.begin(), it->second.end());
      continue;
    }

    if (mk61nspire::parse_button_token(t).has_value()) {
      out.push_back(t);
      continue;
    }

    err = "Unknown MK-90 key token: " + raw;
    return false;
  }
  return true;
}

void print_help() {
  std::cout
      << "MK-90 monitor commands:\n"
      << "  H                         help\n"
      << "  Q                         quit\n"
      << "  D                         display\n"
      << "  M RAD|DEG|GRD             mode\n"
      << "  R                         reset\n"
      << "  S N                       step N cycles\n"
      << "  K TOKENS...               send MK-61 tokens\n"
      << "  P KEYS...                 send MK-90 aliases\n"
      << "  B ROW DNUM                matrix press (B_row_dnum)\n"
      << "  L PRESET                  run preset\n"
      << "  LS                        list presets\n"
      << "  KH                        list MK-90 aliases\n"
      << "Examples:\n"
      << "  P 1 2 ENT + 3 +\n"
      << "  K PI\n";
}

void print_key_help() {
  std::cout
      << "MK-90 aliases:\n"
      << "  digits: 0..9\n"
      << "  ops: + - * / . (PLUS/MINUS/MUL/DIV/DOT)\n"
      << "  enter: ENT ENTER EXE RUN -> V\n"
      << "  clear: CLR CLEAR CX -> CX\n"
      << "  sign: NEG SIGN CHS -> /-/\n"
      << "  funcs: SIN COS TAN/TG PI SQRT SQR/X2 INV/INVX POW\n"
      << "  modifiers: SHIFT->F, ALPHA->K\n";
}

void print_banner(const Mk61Engine& emu) {
  std::cout << "MK-61 emulator variant for MK-90 (PDP-11 compatible)\n";
  std::cout << "MODE=" << emu.mode_name() << " CYCLES=" << emu.cycles() << " FRAMES=" << emu.frames() << "\n";
  std::cout << "DISPLAY=" << emu.display_compact() << "\n";
  std::cout << "Type H for help.\n";
}

}  // namespace

int main(int argc, char** argv) {
  int boot_cycles = mk61nspire::kDefaultBootCycles;
  PressConfig cfg;
  std::string mode = "rad";

  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    auto need_value = [&](const std::string& name) -> std::string {
      if (i + 1 >= argc) throw std::runtime_error("Missing value for " + name);
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
    const Mk90KeyMap mk90_map = build_mk90_keymap();

    Mk61Engine emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "MK90> ";
      if (!std::getline(std::cin, line)) break;
      line = mk61nspire::trim(line);
      if (line.empty()) continue;

      std::vector<std::string> cmd = mk61nspire::split_tokens(line);
      if (cmd.empty()) continue;
      const std::string op = mk61nspire::upper(cmd[0]);

      if (op == "H" || op == "HELP") {
        print_help();
        continue;
      }
      if (op == "Q" || op == "QUIT" || op == "EXIT") {
        break;
      }
      if (op == "D" || op == "DISPLAY") {
        std::cout << "DISPLAY=" << emu.display_text() << "\n";
        std::cout << "COMPACT=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "KH") {
        print_key_help();
        continue;
      }
      if (op == "M" || op == "MODE") {
        if (cmd.size() < 2) {
          std::cout << "usage: M RAD|DEG|GRD\n";
          continue;
        }
        if (!emu.set_mode(cmd[1])) {
          std::cout << "invalid mode\n";
          continue;
        }
        std::cout << "MODE=" << emu.mode_name() << "\n";
        continue;
      }
      if (op == "R" || op == "RESET") {
        emu.hard_reset(boot_cycles);
        std::cout << "RESET OK DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "S" || op == "STEP") {
        if (cmd.size() < 2) {
          std::cout << "usage: S N\n";
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
        std::cout << "CYCLES=" << emu.cycles() << " FRAMES=" << emu.frames() << " DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "LS") {
        std::cout << "PRESETS:\n";
        for (const auto& kv : presets) {
          std::cout << "  " << kv.first << "\n";
        }
        continue;
      }
      if (op == "L" || op == "LOAD") {
        if (cmd.size() < 2) {
          std::cout << "usage: L PRESET\n";
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
        std::cout << "OK DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "B") {
        if (cmd.size() < 3) {
          std::cout << "usage: B ROW DNUM\n";
          continue;
        }
        std::string err;
        const std::string token = "B_" + cmd[1] + "_" + cmd[2];
        if (!emu.execute_token(token, aliases, cfg, err)) {
          std::cout << "error: " << err << "\n";
          continue;
        }
        std::cout << "DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "K") {
        if (cmd.size() < 2) {
          std::cout << "usage: K TOKENS...\n";
          continue;
        }
        std::vector<std::string> tokens(cmd.begin() + 1, cmd.end());
        std::string err;
        if (!emu.execute_tokens(tokens, aliases, cfg, err)) {
          std::cout << "error: " << err << "\n";
          continue;
        }
        std::cout << "DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }
      if (op == "P") {
        if (cmd.size() < 2) {
          std::cout << "usage: P KEYS...\n";
          continue;
        }
        std::vector<std::string> keys(cmd.begin() + 1, cmd.end());
        std::vector<std::string> tokens;
        std::string err;
        if (!resolve_mk90_tokens(keys, mk90_map, tokens, err)) {
          std::cout << "error: " << err << "\n";
          continue;
        }
        if (!emu.execute_tokens(tokens, aliases, cfg, err)) {
          std::cout << "error: " << err << "\n";
          continue;
        }
        std::cout << "DISPLAY=" << emu.display_compact() << "\n";
        continue;
      }

      std::cout << "unknown command, type H\n";
    }

    return 0;
  } catch (const std::exception& e) {
    std::cerr << "[ERR] " << e.what() << "\n";
    return 1;
  }
}
