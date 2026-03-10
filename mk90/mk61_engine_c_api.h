#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mk61_ctx mk61_ctx;

mk61_ctx* mk61_create(void);
void mk61_destroy(mk61_ctx* ctx);

int mk61_set_mode(mk61_ctx* ctx, const char* mode_name);
void mk61_reset(mk61_ctx* ctx, int boot_cycles);

void mk61_set_timing(mk61_ctx* ctx,
                     int start_cycles,
                     int gap_cycles,
                     int settle_cycles,
                     int timeout_cycles,
                     int post_cycles);

int mk61_press_token_seq(mk61_ctx* ctx, const char* token_line, char* err_buf, int err_buf_len);
int mk61_press_token(mk61_ctx* ctx, const char* token, char* err_buf, int err_buf_len);
int mk61_press_matrix(mk61_ctx* ctx, int row, int dnum, char* err_buf, int err_buf_len);
void mk61_step_cycles(mk61_ctx* ctx, int cycles);

int mk61_get_cycles(const mk61_ctx* ctx);
int mk61_get_frames(const mk61_ctx* ctx);

int mk61_get_display_text(const mk61_ctx* ctx, char* out_buf, int out_buf_len);
int mk61_get_display_compact(const mk61_ctx* ctx, char* out_buf, int out_buf_len);

#ifdef __cplusplus
}
#endif
