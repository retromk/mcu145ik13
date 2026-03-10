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
using ZxKeyMap = std::unordered_map<std::string, std::vector<std::string>>;

ZxKeyMap build_zx_keymap() {
  ZxKeyMap m;

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

  m["P"] = {"+"};  // Plus
  m["M"] = {"-"};  // Minus
  m["X"] = {"*"};  // Multiply
  m["D"] = {"/"};  // Divide
  m["."] = {"."};
  m["N"] = {"/-/"}; // Negate

  m["ENT"] = {"V"};
  m["ENTER"] = {"V"};
  m["CAPS"] = {"V"};
  m["SYMB"] = {"V"};

  m["C"] = {"CX"};
  m["CLR"] = {"CX"};
  m["CLEAR"] = {"CX"};

  m["F"] = {"F"};
  m["K"] = {"K"};

  m["SIN"] = {"SIN"};
  m["COS"] = {"COS"};
  m["TAN"] = {"TG"};
  m["TG"] = {"TG"};
  m["PI"] = {"PI"};
  m["SQRT"] = {"SQRT"};
  m["X2"] = {"X2"};
  m["INVX"] = {"INVX"};
  m["POW"] = {"POW"};

  // Sinclair key matrix aliases (K<row><col>, row/col 0..4).
  // Typical wiring: row 0: SHIFT Z X C V ; row 1: A S D F G ; row 2: Q W E R T ; row 3: 1 2 3 4 5 ; row 4: 0 9 8 7 6 ; row 5: P O I U Y ; row 6: ENTER L K J H ; row 7: SPACE SYM M N B
  m["K30"] = {"1"};
  m["K31"] = {"2"};
  m["K32"] = {"3"};
  m["K33"] = {"4"};
  m["K34"] = {"5"};
  m["K40"] = {"0"};
  m["K41"] = {"9"};
  m["K42"] = {"8"};
  m["K43"] = {"7"};
  m["K44"] = {"6"};
  m["K50"] = {"+"}; // P
  m["K62"] = {"K"}; // K
  m["K66"] = {"V"}; // ENTER
  m["K72"] = {"-"}; // M
  m["K73"] = {"/-/"}; // N
  m["K70"] = {"."}; // SPACE -> dot in this profile
  m["K10"] = {"CX"}; // C
  m["K11"] = {"/"};  // D
  m["K12"] = {"F"};  // F
  m["K02"] = {"*"};  // X

  return m;
}

bool resolve_zx_tokens(const std::vector<std::string>& in,
                       const ZxKeyMap& zmap,
                       std::vector<std::string>& out,
                       std::string& err) {
  out.clear();
  for (const std::string& raw : in) {
    const std::string t = mk61nspire::upper(mk61nspire::trim(raw));
    if (t.empty()) continue;

    auto it = zmap.find(t);
    if (it != zmap.end()) {
      out.insert(out.end(), it->second.begin(), it->second.end());
      continue;
    }

    if (mk61nspire::parse_button_token(t).has_value()) {
      out.push_back(t);
      continue;
    }

    err = "Unknown ZX token: " + raw;
    return false;
  }
  return true;
}

void print_help() {
  std::cout
      << "ZX monitor commands:\n"
      << "  /help                     show help\n"
      << "  /display                  show display\n"
      << "  /mode rad|deg|grd         set angle mode\n"
      << "  /reset                    reset calculator\n"
      << "  /step N                   advance raw cycles\n"
      << "  /preset NAME              run MK-61 preset\n"
      << "  /presets                  list presets\n"
      << "  /zx KEYS...               run ZX key aliases\n"
      << "  /zx-help                  show ZX aliases\n"
      << "  /quit                     exit\n"
      << "Raw input is MK-61 tokens, examples:\n"
      << "  1 2 V + 3 +\n"
      << "  PI\n";
}

void print_zx_help() {
  std::cout
      << "ZX aliases -> MK-61:\n"
      << "  digits: 0..9\n"
      << "  P->+, M->-, X->*, D->/\n"
      << "  N->/-/, C->CX\n"
      << "  ENT/ENTER->V\n"
      << "  F->F, K->K\n"
      << "  functions: PI SIN COS TAN/TG SQRT X2 INVX POW\n"
      << "  matrix aliases: Krc (example K30=1, K66=ENTER)\n"
      << "Example:\n"
      << "  /zx 1 2 ENT P 3 P\n";
}

void print_banner(const Mk61Engine& emu) {
  std::cout << "MK-61 variant for ZX Spectrum (Z80 profile, host)\n";
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
    const ZxKeyMap zx_map = build_zx_keymap();

    Mk61Engine emu;
    if (!emu.set_mode(mode)) {
      std::cerr << "Invalid mode: " << mode << " (expected rad|deg|grd)\n";
      return 1;
    }
    emu.hard_reset(boot_cycles);

    print_banner(emu);

    std::string line;
    while (true) {
      std::cout << "zx> ";
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
        if (op == "ZX-HELP") {
          print_zx_help();
          continue;
        }
        if (op == "ZX") {
          if (cmd.size() < 2) {
            std::cout << "usage: /zx KEYS...\n";
            continue;
          }
          std::vector<std::string> raw_keys(cmd.begin() + 1, cmd.end());
          std::vector<std::string> mk61_tokens;
          std::string err;
          if (!resolve_zx_tokens(raw_keys, zx_map, mk61_tokens, err)) {
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
