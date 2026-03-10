#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <QString>

#include "../emu145/pmkemu/cmcu13.h"
#include "../emu145/pmkemu/cmem.h"
#include "../emu145/pmkemu/mcommands.h"
#include "../emu145/pmkemu/synchro.h"
#include "../emu145/pmkemu/ucommands.h"

namespace {

constexpr char kSegChars[] = "0123456789-LCrE ";

struct ButtonEvent {
  int top_cycle;
  int chain_cycle;
  int row;
  int col;
};

enum class Mode {
  kRad,
  kDeg,
  kGrd,
};

struct Config {
  int cycles_top = 200000;
  int phase_div = 5;
  Mode mode = Mode::kRad;
  std::string buttons_path;
  std::string trace_path;
  std::string frames_path;
};

bool parse_int(const std::string& s, int* out) {
  char* end = nullptr;
  long v = std::strtol(s.c_str(), &end, 10);
  if (!end || *end != '\0') {
    return false;
  }
  if (v < std::numeric_limits<int>::min() || v > std::numeric_limits<int>::max()) {
    return false;
  }
  *out = static_cast<int>(v);
  return true;
}

Mode parse_mode(const std::string& s) {
  if (s == "rad") return Mode::kRad;
  if (s == "deg") return Mode::kDeg;
  if (s == "grd") return Mode::kGrd;
  throw std::runtime_error("Invalid --mode value: " + s + " (expected rad|deg|grd)");
}

Config parse_args(int argc, char** argv) {
  Config cfg;
  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    auto need_val = [&](const std::string& opt) -> std::string {
      if (i + 1 >= argc) {
        throw std::runtime_error("Missing value for " + opt);
      }
      return std::string(argv[++i]);
    };

    if (arg == "--cycles-top") {
      std::string v = need_val(arg);
      if (!parse_int(v, &cfg.cycles_top) || cfg.cycles_top <= 0) {
        throw std::runtime_error("Invalid --cycles-top: " + v);
      }
    } else if (arg == "--phase-div") {
      std::string v = need_val(arg);
      if (!parse_int(v, &cfg.phase_div) || cfg.phase_div <= 0) {
        throw std::runtime_error("Invalid --phase-div: " + v);
      }
    } else if (arg == "--mode") {
      cfg.mode = parse_mode(need_val(arg));
    } else if (arg == "--buttons") {
      cfg.buttons_path = need_val(arg);
    } else if (arg == "--trace") {
      cfg.trace_path = need_val(arg);
    } else if (arg == "--frames") {
      cfg.frames_path = need_val(arg);
    } else if (arg == "--help" || arg == "-h") {
      std::cout
          << "Usage: emu145_ref_runner [options]\n"
          << "  --cycles-top N   Total top-level cycles (default 200000)\n"
          << "  --phase-div N    Top cycles per emu chain cycle (default 5)\n"
          << "  --mode M         rad|deg|grd (default rad)\n"
          << "  --buttons PATH   Input events file: <top_cycle> <row> <col>\n"
          << "  --trace PATH     Output trace CSV\n"
          << "  --frames PATH    Output sync frames CSV\n";
      std::exit(0);
    } else {
      throw std::runtime_error("Unknown argument: " + arg);
    }
  }

  if (cfg.buttons_path.empty()) {
    throw std::runtime_error("--buttons is required");
  }
  if (cfg.trace_path.empty()) {
    throw std::runtime_error("--trace is required");
  }
  if (cfg.frames_path.empty()) {
    throw std::runtime_error("--frames is required");
  }
  return cfg;
}

std::vector<ButtonEvent> load_events(const Config& cfg) {
  std::ifstream in(cfg.buttons_path);
  if (!in) {
    throw std::runtime_error("Failed to open buttons file: " + cfg.buttons_path);
  }

  std::vector<ButtonEvent> events;
  int cyc = 0, row = 0, col = 0;
  while (in >> cyc >> row >> col) {
    if (cyc < 0) cyc = 0;
    if (row < 1 || row > 3 || col < 0 || col > 9) {
      continue;
    }
    const int chain_cyc = (cyc + cfg.phase_div - 1) / cfg.phase_div;
    events.push_back(ButtonEvent{cyc, chain_cyc, row, col});
  }

  std::sort(events.begin(), events.end(), [](const ButtonEvent& a, const ButtonEvent& b) {
    if (a.chain_cycle != b.chain_cycle) return a.chain_cycle < b.chain_cycle;
    if (a.row != b.row) return a.row < b.row;
    return a.col < b.col;
  });
  return events;
}

std::string render_frame(const std::array<unsigned char, 12>& display) {
  std::string out;
  auto append_seg = [&](unsigned char seg) {
    const unsigned idx = static_cast<unsigned>(seg & 0x0F);
    char c = (idx < sizeof(kSegChars) - 1) ? kSegChars[idx] : '?';
    out.push_back(c);
    if (seg & 0x80) out.push_back('.');
  };

  for (int i = 0; i < 9; ++i) append_seg(display[8 - i]);
  for (int i = 0; i < 3; ++i) append_seg(display[11 - i]);
  return out;
}

bool mode_k1(Mode mode, unsigned dcount) {
  switch (mode) {
    case Mode::kRad:
      return dcount != 9;
    case Mode::kDeg:
      return dcount != 10;
    case Mode::kGrd:
      return dcount != 11;
  }
  return true;
}

void load_roms(cMCU* ik1302, cMCU* ik1303, cMCU* ik1306) {
  for (int i = 0; i < 68; ++i) {
    ik1302->ucrom[i].raw = ik1302_urom[i];
    ik1303->ucrom[i].raw = ik1303_urom[i];
    ik1306->ucrom[i].raw = ik1306_urom[i];
  }

  for (int i = 0; i < 128; ++i) {
    for (int j = 0; j < 9; ++j) {
      ik1302->asprom[i][j] = ik1302_srom[i][j];
      ik1303->asprom[i][j] = ik1303_srom[i][j];
      ik1306->asprom[i][j] = ik1306_srom[i][j];
    }
  }

  for (int i = 0; i < 256; ++i) {
    ik1302->cmdrom[i] = ik1302_mrom[i];
    ik1303->cmdrom[i] = ik1303_mrom[i];
    ik1306->cmdrom[i] = ik1306_mrom[i];
  }
}

}  // namespace

int main(int argc, char** argv) {
  try {
    const Config cfg = parse_args(argc, argv);
    const std::vector<ButtonEvent> events = load_events(cfg);

    const int cycles_chain = (cfg.cycles_top + cfg.phase_div - 1) / cfg.phase_div;

    cMCU ik1302(nullptr, QString("IK1302"), false);
    cMCU ik1303(nullptr, QString("IK1303"), false);
    cMCU ik1306(nullptr, QString("IK1306"), false);
    cMem ir2_1;
    cMem ir2_2;

    load_roms(&ik1302, &ik1303, &ik1306);

    ik1302.init();
    ik1303.init();
    ik1306.init();

    std::ofstream trace(cfg.trace_path);
    if (!trace) {
      throw std::runtime_error("Failed to open trace output: " + cfg.trace_path);
    }

    std::ofstream frames(cfg.frames_path);
    if (!frames) {
      throw std::runtime_error("Failed to open frames output: " + cfg.frames_path);
    }

    trace << "chain_cycle,top_cycle,dcycle,sync,seg,k1,k2,btn,row,col,cptr,command,ucmd,phase,display,text\n";
    frames << "chain_cycle,top_cycle,display,text\n";

    std::array<unsigned char, 12> display{};
    display.fill(0x0F);
    display[7] = 0x80;

    bool chain = false;
    unsigned int dcycle = 0;
    bool sync = false;
    unsigned char seg = 0;
    unsigned int btnpressed = 0;
    size_t event_idx = 0;

    for (int cyc = 0; cyc < cycles_chain; ++cyc) {
      while (btnpressed == 0 && event_idx < events.size() && events[event_idx].chain_cycle <= cyc) {
        btnpressed = (static_cast<unsigned>(events[event_idx].row) << 8U) |
                     static_cast<unsigned>(events[event_idx].col);
        ++event_idx;
      }

      bool k1 = false;
      bool k2 = false;

      if (ik1302.strobe()) {
        if (ik1302.dcount == 12) {
          k2 = true;
        }

        if (btnpressed != 0) {
          const unsigned row = (btnpressed >> 8U) & 0x3U;
          const unsigned col = btnpressed & 0xFFU;
          if ((ik1302.dcount + 1U) == (2U + col)) {
            switch (row) {
              case 1:
                k1 = true;
                k2 = false;
                break;
              case 2:
                k1 = false;
                k2 = true;
                break;
              case 3:
                k1 = true;
                k2 = true;
                break;
              default:
                k1 = false;
                k2 = false;
                break;
            }
            btnpressed = 0;
          }
        }
      }

      chain = ik1302.tick(chain, k1, k2, &dcycle, &sync, &seg);

      if (ik1302.strobe()) {
        if (dcycle > 1U && dcycle < 14U) {
          display[dcycle - 2U] = seg;
        }
      } else if (sync) {
        display.fill(0x0F);
      }

      if (sync) {
        frames << cyc << ',' << (cyc * cfg.phase_div) << ',';
        for (int i = 0; i < 12; ++i) {
          if (i) frames << ' ';
          frames << "0x" << std::hex << std::setw(2) << std::setfill('0')
                 << static_cast<unsigned>(display[i]) << std::dec;
        }
        frames << ',' << '"' << render_frame(display) << '"' << '\n';
      }

      const unsigned row_dbg = (btnpressed >> 8U) & 0x3U;
      const unsigned col_dbg = btnpressed & 0xFFU;

      trace << cyc << ',' << (cyc * cfg.phase_div) << ','
            << dcycle << ',' << (sync ? 1 : 0) << ','
            << "0x" << std::hex << std::setw(2) << std::setfill('0')
            << static_cast<unsigned>(seg) << std::dec << ','
            << (k1 ? 1 : 0) << ',' << (k2 ? 1 : 0) << ',' << btnpressed << ','
            << row_dbg << ',' << col_dbg << ','
            << static_cast<unsigned>(ik1302.cptr) << ','
            << "0x" << std::hex << std::setw(8) << std::setfill('0')
            << ik1302.command << std::dec << ','
            << static_cast<unsigned>(ik1302.cur_ucmd) << ','
            << 0 << ',';

      for (int i = 0; i < 12; ++i) {
        if (i) trace << ' ';
        trace << "0x" << std::hex << std::setw(2) << std::setfill('0')
              << static_cast<unsigned>(display[i]) << std::dec;
      }
      trace << ',' << '"' << render_frame(display) << '"' << '\n';

      const bool grd = mode_k1(cfg.mode, ik1303.dcount);
      chain = ik1303.tick(chain, grd, false, nullptr, nullptr, nullptr);
      chain = ik1306.tick(chain, false, false, nullptr, nullptr, nullptr);
      chain = ir2_1.tick(chain);
      chain = ir2_2.tick(chain);
      ik1302.pretick(chain);
    }

    std::cout << "[emu145_ref_runner] cycles_chain=" << cycles_chain
              << " events=" << events.size() << " trace='" << cfg.trace_path
              << "' frames='" << cfg.frames_path << "'\n";

    return 0;
  } catch (const std::exception& e) {
    std::cerr << "[emu145_ref_runner][ERR] " << e.what() << "\n";
    return 1;
  }
}
