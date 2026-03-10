#include "mk61_hls.hpp"

#include <algorithm>

#include "rom_tables.hpp"

namespace mk61hls {
namespace {

inline bool bit_u32(uint32_t v, int bit) {
  return ((v >> bit) & 1u) != 0u;
}

inline uint8_t bits_u32(uint32_t v, int lo, int width) {
  return static_cast<uint8_t>((v >> lo) & ((1u << width) - 1u));
}

inline uint8_t jrom_idx(uint8_t icount) {
  static const uint8_t table[42] = {
      0, 1, 2, 3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5,
      3, 4, 5, 6, 7, 8, 0, 1, 2, 3, 4, 5, 6, 7, 8, 0, 1, 2, 3, 4, 5};
  return (icount < 42u) ? table[icount] : 0u;
}

inline uint8_t ucount_mask2(uint8_t x) {
  return static_cast<uint8_t>(x & 0x3u);
}

inline uint8_t icount_mask6(uint8_t x) {
  return static_cast<uint8_t>(x & 0x3Fu);
}

inline uint8_t dcount_mask4(uint8_t x) {
  return static_cast<uint8_t>(x & 0x0Fu);
}

inline uint8_t asp_mask7(uint8_t x) {
  return static_cast<uint8_t>(x & 0x7Fu);
}

inline void decode_stage(const CoreState& s,
                         int chip,
                         uint8_t& asp_dec,
                         uint8_t& cur_ucmd_dec,
                         bool& spw_dec,
                         bool& sp_rr1_dec,
                         bool& sp_rr4_dec) {
  asp_dec = 0u;
  cur_ucmd_dec = 0u;
  spw_dec = false;
  sp_rr1_dec = false;
  sp_rr4_dec = false;

  if (s.icount < 27u) {
    asp_dec = static_cast<uint8_t>(s.command & 0x7Fu);
  } else if (s.icount < 36u) {
    asp_dec = bits_u32(s.command, 8, 7);
  } else {
    const uint8_t c23_16 = bits_u32(s.command, 16, 8);
    if (c23_16 >= 0x20u) {
      if (s.icount == 36u) {
        spw_dec = true;
        sp_rr1_dec = bit_u32(s.command, 16 + s.ucount);
        sp_rr4_dec = bit_u32(s.command, 20 + s.ucount);
      }
      asp_dec = 0x5Fu;
    } else {
      asp_dec = bits_u32(s.command, 16, 6);
    }
  }

  const uint8_t jidx = jrom_idx(s.icount);
  uint8_t ucmd_raw = static_cast<uint8_t>(srom_lookup(chip, asp_dec, jidx) & 0x3Fu);

  if (ucmd_raw > 0x3Bu) {
    ucmd_raw = static_cast<uint8_t>(((ucmd_raw - 0x3Cu) << 1) + (s.rl ? 0u : 1u) + 0x3Cu);
  }

  cur_ucmd_dec = asp_mask7(ucmd_raw);
}

} // namespace

void core_reset(CoreState& s, int chip) {
  for (int i = 0; i < MCU_BITLEN; ++i) {
    s.rr[i] = false;
    s.rm[i] = false;
    s.rstreg[i] = false;
  }
  for (int i = 0; i < 4; ++i) {
    s.rs[i] = false;
    s.rs1[i] = false;
    s.rh[i] = false;
    s.dispout[i] = false;
  }

  s.sigma = false;
  s.carry = false;
  s.rl = false;
  s.rt = false;
  s.was_t_qrd = false;
  s.latchk1 = false;
  s.latchk2 = false;

  s.asp = 0u;
  s.icount = 0u;
  s.dcount = 0u;
  s.ecount = 0u;
  s.ucount = 0u;
  s.cptr = 0u;
  s.command = boot_command_for_chip(chip);
  s.cur_ucmd = 0u;

  s.rout = false;
  s.dcycle = 0u;
  s.syncout = false;
  s.segment = 0u;
}

void core_step(CoreState& s,
               int chip,
               bool pretick_in,
               bool rst,
               bool tick_en,
               bool rin,
               bool k1,
               bool k2) {
  if (rst) {
    core_reset(s, chip);
    return;
  }
  if (!tick_en) {
    return;
  }

  bool rr_n[MCU_BITLEN];
  bool rm_n[MCU_BITLEN];
  bool rst_n[MCU_BITLEN];
  bool rs_n[4];
  bool rs1_n[4];
  bool rh_n[4];
  bool dispout_n[4];

  for (int i = 0; i < MCU_BITLEN; ++i) {
    rr_n[i] = s.rr[i];
    rm_n[i] = s.rm[i];
    rst_n[i] = s.rstreg[i];
  }
  for (int i = 0; i < 4; ++i) {
    rs_n[i] = s.rs[i];
    rs1_n[i] = s.rs1[i];
    rh_n[i] = s.rh[i];
    dispout_n[i] = s.dispout[i];
  }

  bool sigma_n = s.sigma;
  bool carry_n = s.carry;
  bool rl_n = s.rl;
  bool rt_n = s.rt;
  bool was_t_qrd_n = s.was_t_qrd;
  bool latchk1_n = s.latchk1;
  bool latchk2_n = s.latchk2;

  uint8_t icount_n = s.icount;
  uint8_t dcount_n = s.dcount;
  uint8_t ecount_n = s.ecount;
  uint8_t ucount_n = s.ucount;
  uint8_t cptr_n = s.cptr;
  uint32_t command_n = s.command;
  uint8_t cur_ucmd_n = s.cur_ucmd;

  uint8_t dcycle_n = 0u;
  bool syncout_n = false;
  uint8_t segment_n = 0u;
  bool ret_bit = false;

  bool keybits_now[4] = {k1, false, false, k2};
  bool keybits_latched[4] = {latchk1_n, false, false, latchk2_n};

  if (pretick_in) {
    rm_n[MCU_BITLEN - 1] = rin;
  }

  uint8_t asp_dec = 0u;
  uint8_t cur_ucmd_dec = 0u;
  bool spw_dec = false;
  bool sp_rr1_dec = false;
  bool sp_rr4_dec = false;
  decode_stage(s, chip, asp_dec, cur_ucmd_dec, spw_dec, sp_rr1_dec, sp_rr4_dec);

  command_n = s.command;
  uint8_t asp_next = asp_dec;
  cur_ucmd_n = cur_ucmd_dec;

  if (spw_dec) {
    rr_n[4] = sp_rr1_dec;
    rr_n[16] = sp_rr4_dec;
  }

  const uint32_t urom_word = urom_lookup(chip, cur_ucmd_dec);

  const bool a_r = bit_u32(urom_word, 0);
  const bool a_m = bit_u32(urom_word, 1);
  const bool a_st = bit_u32(urom_word, 2);
  const bool a_nr = bit_u32(urom_word, 3);
  const bool a_10nl = bit_u32(urom_word, 4);
  const bool a_s = bit_u32(urom_word, 5);
  const bool a_4 = bit_u32(urom_word, 6);

  const bool b_s = bit_u32(urom_word, 7);
  const bool b_ns = bit_u32(urom_word, 8);
  const bool b_s1 = bit_u32(urom_word, 9);
  const bool b_6 = bit_u32(urom_word, 10);
  const bool b_1 = bit_u32(urom_word, 11);

  const bool g_l = bit_u32(urom_word, 12);
  const bool g_nl = bit_u32(urom_word, 13);
  const bool g_nt = bit_u32(urom_word, 14);

  const uint8_t r0 = bits_u32(urom_word, 15, 3);
  const bool r_1 = bit_u32(urom_word, 18);
  const bool r_2 = bit_u32(urom_word, 19);
  const bool m_bit = bit_u32(urom_word, 20);
  const bool l_bit = bit_u32(urom_word, 21);

  const uint8_t s_op = bits_u32(urom_word, 22, 2);
  const uint8_t s1_op = bits_u32(urom_word, 24, 2);
  const uint8_t st_op = bits_u32(urom_word, 26, 2);

  if (s1_op == 2u || s1_op == 3u) {
    rh_n[0] = keybits_now[s.ucount];
    rs1_n[0] = rs1_n[0] || rh_n[0];
  }

  if (k1 || k2) {
    latchk1_n = k1;
    latchk2_n = k2;
  }

  keybits_latched[0] = latchk1_n;
  keybits_latched[1] = false;
  keybits_latched[2] = false;
  keybits_latched[3] = latchk2_n;

  if (g_nt) {
    was_t_qrd_n = true;
  }

  rt_n = latchk1_n || latchk2_n;

  if (g_nt || was_t_qrd_n) {
    rs1_n[0] = keybits_latched[s.ucount];
  }

  bool a = false;
  bool b = false;
  bool g = false;

  if (a_r) {
    a = a || rr_n[0];
  }
  if (a_m) {
    a = a || rm_n[0];
  }
  if (a_st) {
    a = a || rst_n[0];
  }
  if (a_nr) {
    a = a || (!rr_n[0]);
  }
  if (a_10nl) {
    a = a || ((((10u >> s.ucount) & 1u) != 0u) && (!rl_n));
  }
  if (a_s) {
    a = a || rs_n[0];
  }
  if (a_4) {
    a = a || (((4u >> s.ucount) & 1u) != 0u);
  }

  if (b_1) {
    b = b || (((1u >> s.ucount) & 1u) != 0u);
  }
  if (b_6) {
    b = b || (((6u >> s.ucount) & 1u) != 0u);
  }
  if (b_s) {
    b = b || rs_n[0];
  }
  if (b_s1) {
    b = b || rs1_n[0];
  }
  if (b_ns) {
    b = b || (!rs_n[0]);
  }

  if (g_l) {
    g = g || rl_n;
  }
  if (g_nl) {
    g = g || (!rl_n);
  }
  if (g_nt) {
    g = g || (!rt_n);
  }

  if (s.ucount != 0u) {
    g = carry_n;
  }

  uint8_t sum2 = 0u;
  if (a) {
    ++sum2;
  }
  if (b) {
    ++sum2;
  }
  if (g) {
    ++sum2;
  }

  sigma_n = (sum2 & 1u) != 0u;
  carry_n = (sum2 & 2u) != 0u;

  bool newr0 = false;
  switch (r0) {
    case 0u:
      newr0 = rr_n[0];
      break;
    case 1u:
      newr0 = rr_n[12];
      break;
    case 2u:
      newr0 = sigma_n;
      break;
    case 3u:
      newr0 = rs_n[0];
      break;
    case 4u:
      newr0 = rr_n[0] || rs_n[0] || sigma_n;
      break;
    case 5u:
      newr0 = rs_n[0] || sigma_n;
      break;
    case 6u:
      newr0 = rr_n[0] || rs_n[0];
      break;
    default:
      newr0 = rr_n[0] || sigma_n;
      break;
  }

  if (r_1) {
    if (s.icount < 36u) {
      if ((s.command & 0xFF000000u) == 0u) {
        rr_n[MCU_BITLEN - 4] = sigma_n;
      }
    } else {
      rr_n[MCU_BITLEN - 4] = sigma_n;
    }
  }

  if (r_2) {
    if (s.icount < 36u) {
      if ((s.command & 0xFF000000u) == 0u) {
        rr_n[MCU_BITLEN - 8] = sigma_n;
      }
    } else {
      rr_n[MCU_BITLEN - 8] = sigma_n;
    }
  }

  if (l_bit && (s.ucount == 3u)) {
    rl_n = carry_n;
  }

  const bool newm0 = m_bit ? rs_n[0] : rm_n[0];

  switch (s_op) {
    case 0u: {
      const bool temp = rs_n[0];
      rs_n[0] = rs_n[1];
      rs_n[1] = rs_n[2];
      rs_n[2] = rs_n[3];
      rs_n[3] = temp;
      break;
    }
    case 1u:
      rs_n[0] = rs_n[1];
      rs_n[1] = rs_n[2];
      rs_n[2] = rs_n[3];
      rs_n[3] = rs1_n[0];
      break;
    case 2u:
      rs_n[0] = rs_n[1];
      rs_n[1] = rs_n[2];
      rs_n[2] = rs_n[3];
      rs_n[3] = sigma_n;
      break;
    default: {
      const bool temp = rs1_n[0];
      rs1_n[0] = rs1_n[1];
      rs1_n[1] = rs1_n[2];
      rs1_n[2] = rs1_n[3];
      rs1_n[3] = sigma_n || temp;
      break;
    }
  }

  switch (s1_op) {
    case 0u: {
      const bool temp = rs1_n[0];
      rs1_n[0] = rs1_n[1];
      rs1_n[1] = rs1_n[2];
      rs1_n[2] = rs1_n[3];
      rs1_n[3] = temp;
      break;
    }
    case 1u:
      rs1_n[0] = rs1_n[1];
      rs1_n[1] = rs1_n[2];
      rs1_n[2] = rs1_n[3];
      rs1_n[3] = sigma_n;
      break;
    case 2u: {
      const bool temp = rs1_n[0];
      rs1_n[0] = rs1_n[1];
      rs1_n[1] = rs1_n[2];
      rs1_n[2] = rs1_n[3];
      rs1_n[3] = temp;
      break;
    }
    default: {
      const bool temp = rs1_n[0];
      rs1_n[0] = rs1_n[1];
      rs1_n[1] = rs1_n[2];
      rs1_n[2] = rs1_n[3];
      rs1_n[3] = temp || sigma_n;
      break;
    }
  }

  switch (st_op) {
    case 1u:
      rst_n[8] = rst_n[4];
      rst_n[4] = rst_n[0];
      rst_n[0] = sigma_n;
      break;
    case 2u: {
      const bool temp = rst_n[0];
      rst_n[0] = rst_n[4];
      rst_n[4] = rst_n[8];
      rst_n[8] = temp;
      break;
    }
    case 3u: {
      const bool x = rst_n[0];
      const bool y = rst_n[4];
      const bool z = rst_n[8];
      rst_n[0] = sigma_n || y;
      rst_n[4] = x || z;
      rst_n[8] = x || y;
      break;
    }
    default:
      break;
  }

  ret_bit = newm0;

  for (int i = 0; i < MCU_BITLEN - 1; ++i) {
    rm_n[i] = rm_n[i + 1];
  }
  rm_n[MCU_BITLEN - 1] = rin;

  if ((s.icount < 36u) && ((s.command & 0xFF000000u) != 0u)) {
    newr0 = rr_n[0];
  }

  for (int i = 0; i < MCU_BITLEN - 1; ++i) {
    rr_n[i] = rr_n[i + 1];
  }
  rr_n[MCU_BITLEN - 1] = newr0;

  {
    const bool temp = rh_n[0];
    rh_n[0] = rh_n[1];
    rh_n[1] = rh_n[2];
    rh_n[2] = rh_n[3];
    rh_n[3] = temp;
  }

  if ((s.dcount < 13u) && (s.ecount == 0u)) {
    dispout_n[0] = dispout_n[1];
    dispout_n[1] = dispout_n[2];
    dispout_n[2] = dispout_n[3];
    dispout_n[3] = newr0;
  }

  {
    const bool temp = rst_n[0];
    for (int i = 0; i < MCU_BITLEN - 1; ++i) {
      rst_n[i] = rst_n[i + 1];
    }
    rst_n[MCU_BITLEN - 1] = temp;
  }

  if (s.ucount == 3u) {
    ucount_n = 0u;
    icount_n = icount_mask6(static_cast<uint8_t>(s.icount + 1u));
    ecount_n = ucount_mask2(static_cast<uint8_t>(s.ecount + 1u));
  } else {
    ucount_n = ucount_mask2(static_cast<uint8_t>(s.ucount + 1u));
  }

  if (icount_n >= 42u) {
    icount_n = 0u;
    uint8_t cptr_hi = 0u;
    if (rr_n[156]) {
      cptr_hi |= 0x1u;
    }
    if (rr_n[157]) {
      cptr_hi |= 0x2u;
    }
    if (rr_n[158]) {
      cptr_hi |= 0x4u;
    }
    if (rr_n[159]) {
      cptr_hi |= 0x8u;
    }

    cptr_n = static_cast<uint8_t>(((cptr_hi & 0x0Fu) << 4) |
                                  (rr_n[147] ? 0x8u : 0u) |
                                  (rr_n[146] ? 0x4u : 0u) |
                                  (rr_n[145] ? 0x2u : 0u) |
                                  (rr_n[144] ? 0x1u : 0u));

    command_n = mrom_lookup(chip, cptr_n);
    was_t_qrd_n = false;
    rt_n = false;
    latchk1_n = false;
    latchk2_n = false;
  }

  if (ecount_n >= 3u) {
    ecount_n = 0u;
    dcount_n = dcount_mask4(static_cast<uint8_t>(s.dcount + 1u));
  }

  if (dcount_n >= 14u) {
    dcount_n = 0u;
  }

  const bool seg_enable = ((command_n & 0x00FC0000u) == 0u) && (ecount_n == 0u) && (ucount_n == 0u);

  dcycle_n = seg_enable ? dcount_mask4(static_cast<uint8_t>(dcount_n + 1u)) : 0u;
  syncout_n = (dcount_n == 13u) && (ecount_n == 2u) && (ucount_n == 3u);

  segment_n = 0u;
  if (seg_enable) {
    segment_n = static_cast<uint8_t>((dispout_n[0] ? 0x01u : 0u) |
                                     (dispout_n[1] ? 0x02u : 0u) |
                                     (dispout_n[2] ? 0x04u : 0u) |
                                     (dispout_n[3] ? 0x08u : 0u));
    if (rl_n) {
      segment_n = static_cast<uint8_t>(segment_n | 0x80u);
    }
  }

  for (int i = 0; i < MCU_BITLEN; ++i) {
    s.rr[i] = rr_n[i];
    s.rm[i] = rm_n[i];
    s.rstreg[i] = rst_n[i];
  }
  for (int i = 0; i < 4; ++i) {
    s.rs[i] = rs_n[i];
    s.rs1[i] = rs1_n[i];
    s.rh[i] = rh_n[i];
    s.dispout[i] = dispout_n[i];
  }

  s.sigma = sigma_n;
  s.carry = carry_n;
  s.rl = rl_n;
  s.rt = rt_n;
  s.was_t_qrd = was_t_qrd_n;
  s.latchk1 = latchk1_n;
  s.latchk2 = latchk2_n;
  s.asp = asp_mask7(asp_next);

  s.icount = icount_mask6(icount_n);
  s.dcount = dcount_mask4(dcount_n);
  s.ecount = ucount_mask2(ecount_n);
  s.ucount = ucount_mask2(ucount_n);
  s.cptr = cptr_n;
  s.command = command_n;
  s.cur_ucmd = asp_mask7(cur_ucmd_n);

  s.rout = ret_bit;
  s.dcycle = dcycle_n;
  s.syncout = syncout_n;
  s.segment = segment_n;
}

void cmem_reset(CmemState& s) {
  for (int i = 0; i < CMEM_LEN; ++i) {
    s.mem[i] = false;
  }
  s.out_reg = false;
}

void cmem_step(CmemState& s, bool rst, bool tick_en, bool in_bit) {
  if (rst) {
    cmem_reset(s);
    return;
  }
  if (!tick_en) {
    return;
  }

  const bool out_old = s.mem[0];
  for (int i = 0; i < CMEM_LEN - 1; ++i) {
    s.mem[i] = s.mem[i + 1];
  }
  s.mem[CMEM_LEN - 1] = in_bit;
  s.out_reg = out_old;
}

void top_reset(TopState& s) {
  s.phase = 0u;
  core_reset(s.u0, 1302);
  core_reset(s.u1, 1303);
  core_reset(s.u2, 1306);
  cmem_reset(s.m0);
  cmem_reset(s.m1);
}

void top_step(TopState& s, const TopInputs& in, TopOutputs& out) {
  if (in.rst) {
    top_reset(s);
    out.dcycle = 0u;
    out.syncout = false;
    out.segment = 0u;
    out.phase = s.phase;
    return;
  }

  const uint8_t phase_old = s.phase;

  const bool tick_u0 = (phase_old == 0u);
  const bool tick_u1 = (phase_old == 1u);
  const bool tick_u2 = (phase_old == 2u);
  const bool tick_m0 = (phase_old == 3u);
  const bool tick_m1 = (phase_old == 4u);

  const bool d1 = s.u0.rout;
  const bool d2 = s.u1.rout;
  const bool d3 = s.u2.rout;
  const bool d4 = s.m0.out_reg;
  const bool d5 = s.m1.out_reg;
  const bool d0 = d5;

  bool mode_k1_u1 = false;
  switch (in.mode & 0x3u) {
    case 0u:
      mode_k1_u1 = (s.u1.dcount != 9u);
      break;
    case 1u:
      mode_k1_u1 = (s.u1.dcount != 10u);
      break;
    default:
      mode_k1_u1 = (s.u1.dcount != 11u);
      break;
  }

  core_step(s.u0, 1302, true, false, tick_u0, d0, in.k1, in.k2);
  core_step(s.u1, 1303, false, false, tick_u1, d1, mode_k1_u1, false);
  core_step(s.u2, 1306, false, false, tick_u2, d2, false, false);
  cmem_step(s.m0, false, tick_m0, d3);
  cmem_step(s.m1, false, tick_m1, d4);

  s.phase = (phase_old == 4u) ? 0u : static_cast<uint8_t>(phase_old + 1u);

  const bool u0_visible = (s.phase == 1u);
  out.dcycle = u0_visible ? s.u0.dcycle : 0u;
  out.syncout = u0_visible ? s.u0.syncout : false;
  out.segment = u0_visible ? s.u0.segment : 0u;
  out.phase = s.phase;
}

} // namespace mk61hls

extern "C" void mk61_top_hls_step(bool rst,
                                  bool k1,
                                  bool k2,
                                  uint8_t mode,
                                  uint8_t* dcycle,
                                  bool* syncout,
                                  uint8_t* segment,
                                  uint8_t* phase) {
  static mk61hls::TopState state{};

  mk61hls::TopInputs in{};
  in.rst = rst;
  in.k1 = k1;
  in.k2 = k2;
  in.mode = static_cast<uint8_t>(mode & 0x3u);

  mk61hls::TopOutputs out{};
  mk61hls::top_step(state, in, out);

  if (dcycle != nullptr) {
    *dcycle = out.dcycle;
  }
  if (syncout != nullptr) {
    *syncout = out.syncout;
  }
  if (segment != nullptr) {
    *segment = out.segment;
  }
  if (phase != nullptr) {
    *phase = out.phase;
  }
}
