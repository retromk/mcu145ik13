#pragma once

#include <cstdint>

namespace mk61hls {

inline constexpr int MCU_BITLEN = 168;
inline constexpr int CMEM_LEN = 1008;

struct CoreState {
  bool rr[MCU_BITLEN];
  bool rm[MCU_BITLEN];
  bool rstreg[MCU_BITLEN];

  bool rs[4];
  bool rs1[4];
  bool rh[4];
  bool dispout[4];

  bool sigma;
  bool carry;
  bool rl;
  bool rt;
  bool was_t_qrd;
  bool latchk1;
  bool latchk2;

  uint8_t asp;
  uint8_t icount;
  uint8_t dcount;
  uint8_t ecount;
  uint8_t ucount;
  uint8_t cptr;
  uint32_t command;
  uint8_t cur_ucmd;

  bool rout;
  uint8_t dcycle;
  bool syncout;
  uint8_t segment;
};

struct CmemState {
  bool mem[CMEM_LEN];
  bool out_reg;
};

struct TopState {
  uint8_t phase;
  CoreState u0;
  CoreState u1;
  CoreState u2;
  CmemState m0;
  CmemState m1;
};

struct TopInputs {
  bool rst;
  bool k1;
  bool k2;
  uint8_t mode; // 0=RAD, 1=DEG, 2=GRD
};

struct TopOutputs {
  uint8_t dcycle;
  bool syncout;
  uint8_t segment;
  uint8_t phase;
};

void core_reset(CoreState& s, int chip);
void core_step(CoreState& s, int chip, bool pretick_in, bool rst, bool tick_en, bool rin, bool k1, bool k2);

void cmem_reset(CmemState& s);
void cmem_step(CmemState& s, bool rst, bool tick_en, bool in_bit);

void top_reset(TopState& s);
void top_step(TopState& s, const TopInputs& in, TopOutputs& out);

} // namespace mk61hls

extern "C" void mk61_top_hls_step(bool rst,
                                  bool k1,
                                  bool k2,
                                  uint8_t mode,
                                  uint8_t* dcycle,
                                  bool* syncout,
                                  uint8_t* segment,
                                  uint8_t* phase);
