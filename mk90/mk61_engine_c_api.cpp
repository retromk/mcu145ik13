#include "mk61_engine_c_api.h"

#include "../nspire/mk61_engine.hpp"

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

struct mk61_ctx {
  mk61nspire::Mk61Engine emu;
  mk61nspire::AliasMap aliases;
  mk61nspire::PressConfig cfg;
};

namespace {

void write_error(const std::string& msg, char* err_buf, int err_buf_len) {
  if (!err_buf || err_buf_len <= 0) return;
  std::snprintf(err_buf, static_cast<std::size_t>(err_buf_len), "%s", msg.c_str());
}

void clear_error(char* err_buf, int err_buf_len) {
  if (!err_buf || err_buf_len <= 0) return;
  err_buf[0] = '\0';
}

int copy_out(const std::string& s, char* out_buf, int out_buf_len) {
  if (!out_buf || out_buf_len <= 0) return 0;
  const std::size_t n = static_cast<std::size_t>(out_buf_len);
  std::snprintf(out_buf, n, "%s", s.c_str());
  return 1;
}

}  // namespace

extern "C" {

mk61_ctx* mk61_create(void) {
  mk61_ctx* ctx = new mk61_ctx();
  ctx->aliases = mk61nspire::build_aliases();
  ctx->emu.hard_reset(mk61nspire::kDefaultBootCycles);
  return ctx;
}

void mk61_destroy(mk61_ctx* ctx) {
  delete ctx;
}

int mk61_set_mode(mk61_ctx* ctx, const char* mode_name) {
  if (!ctx || !mode_name) return 0;
  return ctx->emu.set_mode(mode_name) ? 1 : 0;
}

void mk61_reset(mk61_ctx* ctx, int boot_cycles) {
  if (!ctx) return;
  if (boot_cycles < 0) boot_cycles = 0;
  ctx->emu.hard_reset(boot_cycles);
}

void mk61_set_timing(mk61_ctx* ctx,
                     int start_cycles,
                     int gap_cycles,
                     int settle_cycles,
                     int timeout_cycles,
                     int post_cycles) {
  if (!ctx) return;
  ctx->cfg.start_cycles = (start_cycles < 0) ? 0 : start_cycles;
  ctx->cfg.gap_cycles = (gap_cycles < 0) ? 0 : gap_cycles;
  ctx->cfg.settle_cycles = (settle_cycles < 0) ? 0 : settle_cycles;
  ctx->cfg.timeout_cycles = (timeout_cycles < 1) ? 1 : timeout_cycles;
  ctx->cfg.post_cycles = (post_cycles < 0) ? 0 : post_cycles;
}

int mk61_press_token_seq(mk61_ctx* ctx, const char* token_line, char* err_buf, int err_buf_len) {
  if (!ctx || !token_line) {
    write_error("invalid args", err_buf, err_buf_len);
    return 0;
  }

  clear_error(err_buf, err_buf_len);
  std::string err;
  const std::vector<std::string> tokens = mk61nspire::split_tokens(token_line);
  if (!ctx->emu.execute_tokens(tokens, ctx->aliases, ctx->cfg, err)) {
    write_error(err, err_buf, err_buf_len);
    return 0;
  }
  return 1;
}

int mk61_press_token(mk61_ctx* ctx, const char* token, char* err_buf, int err_buf_len) {
  if (!ctx || !token) {
    write_error("invalid args", err_buf, err_buf_len);
    return 0;
  }

  clear_error(err_buf, err_buf_len);
  std::string err;
  if (!ctx->emu.execute_token(token, ctx->aliases, ctx->cfg, err)) {
    write_error(err, err_buf, err_buf_len);
    return 0;
  }
  return 1;
}

int mk61_press_matrix(mk61_ctx* ctx, int row, int dnum, char* err_buf, int err_buf_len) {
  if (!ctx) {
    write_error("invalid args", err_buf, err_buf_len);
    return 0;
  }
  const std::string token = mk61nspire::canonical_name(row, dnum);
  return mk61_press_token(ctx, token.c_str(), err_buf, err_buf_len);
}

void mk61_step_cycles(mk61_ctx* ctx, int cycles) {
  if (!ctx) return;
  if (cycles < 0) cycles = 0;
  ctx->emu.step_cycles(cycles);
}

int mk61_get_cycles(const mk61_ctx* ctx) {
  if (!ctx) return 0;
  return ctx->emu.cycles();
}

int mk61_get_frames(const mk61_ctx* ctx) {
  if (!ctx) return 0;
  return ctx->emu.frames();
}

int mk61_get_display_text(const mk61_ctx* ctx, char* out_buf, int out_buf_len) {
  if (!ctx) return 0;
  return copy_out(ctx->emu.display_text(), out_buf, out_buf_len);
}

int mk61_get_display_compact(const mk61_ctx* ctx, char* out_buf, int out_buf_len) {
  if (!ctx) return 0;
  return copy_out(ctx->emu.display_compact(), out_buf, out_buf_len);
}

}  // extern "C"
