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
using DspicKeyMap = std::unordered_map<std::string, std::vector<std::string>>;

DspicKeyMap build_dspic_keymap() {
  DspicKeyMap m;

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

  m["KEY0"] = {"0"};
  m["KEY1"] = {"1"};
  m["KEY2"] = {"2"};
  m["KEY3"] = {"3"};
  m["KEY4"] = {"4"};
  m["KEY5"] = {"5"};
  m["KEY6"] = {"6"};
  m["KEY7"] = {"7"};
  m["KEY8"] = {"8"};
  m["KEY9"] = {"9"};
  m["KP_ADD"] = {"+"};
  m["KP_SUB"] = {"-"};
  m["KP_MUL"] = {"*"};
  m["KP_DIV"] = {"/"};
  m["KP_DOT"] = {"."};

  m["ENTER"] = {"V"};
  m["ENT"] = {"V"};
  m["EXE"] = {"V"};
  m["RUN"] = {"V"};
  m["EVAL"] = {"V"};

  m["CLR"] = {"CX"};
  m["CLEAR"] = {"CX"};
  m["AC"] = {"CX"};
  m["DEL"] = {"CX"};
  m["BKSP"] = {"CX"};

  m["NEG"] = {"/-/"};
  m["CHS"] = {"/-/"};
  m["SIGN"] = {"/-/"};

  m["SHIFT"] = {"F"};
  m["ALPHA"] = {"K"};

  m["PI"] = {"PI"};
  m["SIN"] = {"SIN"};
  m["COS"] = {"COS"};
  m["TAN"] = {"TG"};
  m["TG"] = {"TG"};
  m["SQRT"] = {"SQRT"};
  m["X2"] = {"X2"};
  m["INVX"] = {"INVX"};
  m["POW"] = {"POW"};

  return m;
}

bool resolve_dspic_tokens(const std::vector<std::string>& in,
                          const DspicKeyMap& dmap,
                          std::vector<std::string>& out,
                          std::string& err) {
  out.clear();
  for (const std::string& raw : in) {
    const std::string t = mk61nspire::upper(mk61nspire::trim(raw));
    if (t.empty()) continue;

    auto it = dmap.find(t);
    if (it != dmap.end()) {
      out.insert(out.end(), it->second.begin(), it->second.end());
      continue;
    }

    if (mk61nspire::parse_button_token(t).has_value()) {
      out.push_back(t);
      continue;
    }

    err = "Unknown dsPIC token: " + raw;
    return false;
  }
  return true;
}

void print_help() {
  std::cout
      << "dsPIC monitor commands:\n"
      << "  /help                     show help\n"
      << "  /display                  show display\n"
      << "  /mode rad|deg|grd         set angle mode\n"
      << "  /reset                    reset calculator\n"
      << "  /step N                   advance raw cycles\n"
      << "  /preset NAME              run MK-61 preset\n"
      << "  /presets                  list presets\n"
      << "  /dspic KEYS...            run dsPIC key aliases\n"
      << "  /dspic-help               show dsPIC aliases\n"
      << "  /quit                     exit\n"
      << "Raw input is MK-61 tokens, examples:\n"
      << "  1 2 V + 3 +\n"
      << "  PI\n";
}

void print_dspic_help() {
  std::cout
      << "dsPIC aliases -> MK-61:\n"
      << "  digits: 0..9 and KEY0..KEY9\n"
      << "  ops: + - * / . and KP_ADD/KP_SUB/KP_MUL/KP_DIV/KP_DOT\n"
      << "  enter: ENTER ENT EXE RUN EVAL -> V\n"
      << "  clear: CLR CLEAR AC DEL BKSP -> CX\n"
      << "  sign: NEG CHS SIGN -> /-/\n"
      << "  modifiers: SHIFT->F, ALPHA->K\n"
      << "  funcs: PI SIN COS TAN/TG SQRT X2 INVX POW\n"
      << "Example:\n"
      << "  /dspic KEY1 KEY2 ENTER KP_ADD KEY3 KP_ADD\n";
}

void print_banner(const Mk61Engine& emu) {
  std::cout << "MK-61 variant for dsPIC30F6014A (ASM profile, host)\n";
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
    const DspicKeyMap dspic_map = build_dspic_keymap();

    Mk61Engine emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "dspic> ";
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
          for (const auto& kv : presets) std::cout << "  " << kv.first << "\n";
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
        if (op == "DSPIC-HELP") {
          print_dspic_help();
          continue;
        }
        if (op == "DSPIC") {
          if (cmd.size() < 2) {
            std::cout << "usage: /dspic KEYS...\n";
            continue;
          }
          std::vector<std::string> raw_keys(cmd.begin() + 1, cmd.end());
          std::vector<std::string> mk61_tokens;
          std::string err;
          if (!resolve_dspic_tokens(raw_keys, dspic_map, mk61_tokens, err)) {
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
