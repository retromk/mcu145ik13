#include "mk61_engine_c_api.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char* key;
  const char* seq;
} key_alias_t;

static const key_alias_t k_mk90_aliases[] = {
    {"0", "0"},
    {"1", "1"},
    {"2", "2"},
    {"3", "3"},
    {"4", "4"},
    {"5", "5"},
    {"6", "6"},
    {"7", "7"},
    {"8", "8"},
    {"9", "9"},
    {"+", "+"},
    {"-", "-"},
    {"*", "*"},
    {"/", "/"},
    {".", "."},
    {"PLUS", "+"},
    {"MINUS", "-"},
    {"MUL", "*"},
    {"DIV", "/"},
    {"DOT", "."},
    {"ENT", "V"},
    {"ENTER", "V"},
    {"EXE", "V"},
    {"RUN", "V"},
    {"CLR", "CX"},
    {"CLEAR", "CX"},
    {"CX", "CX"},
    {"NEG", "/-/"},
    {"SIGN", "/-/"},
    {"CHS", "/-/"},
    {"SIN", "SIN"},
    {"COS", "COS"},
    {"TAN", "TG"},
    {"TG", "TG"},
    {"PI", "PI"},
    {"SQRT", "SQRT"},
    {"SQR", "X2"},
    {"X2", "X2"},
    {"INV", "INVX"},
    {"INVX", "INVX"},
    {"POW", "POW"},
    {"SHIFT", "F"},
    {"ALPHA", "K"},
};

static const int k_alias_count = (int)(sizeof(k_mk90_aliases) / sizeof(k_mk90_aliases[0]));

static void str_upper(char* s) {
  while (*s) {
    *s = (char)toupper((unsigned char)*s);
    ++s;
  }
}

static const char* find_alias(const char* key_upper) {
  int i;
  for (i = 0; i < k_alias_count; ++i) {
    if (strcmp(k_mk90_aliases[i].key, key_upper) == 0) return k_mk90_aliases[i].seq;
  }
  return NULL;
}

static int translate_mk90_to_mk61(const char* src, char* dst, int dst_len, char* err, int err_len) {
  char buf[1024];
  char* saveptr = NULL;
  char* tok;
  int first = 1;

  if (!src || !dst || dst_len <= 0) return 0;
  if ((int)strlen(src) >= (int)sizeof(buf)) {
    snprintf(err, (size_t)err_len, "input too long");
    return 0;
  }

  strcpy(buf, src);
  dst[0] = '\0';

  tok = strtok_r(buf, " \t\r\n,;", &saveptr);
  while (tok) {
    char up[128];
    const char* mapped;
    if ((int)strlen(tok) >= (int)sizeof(up)) {
      snprintf(err, (size_t)err_len, "token too long");
      return 0;
    }
    strcpy(up, tok);
    str_upper(up);
    mapped = find_alias(up);
    if (!mapped) {
      mapped = up;
    }

    if (!first) {
      if ((int)strlen(dst) + 1 >= dst_len) {
        snprintf(err, (size_t)err_len, "output overflow");
        return 0;
      }
      strcat(dst, " ");
    }

    if ((int)strlen(dst) + (int)strlen(mapped) >= dst_len) {
      snprintf(err, (size_t)err_len, "output overflow");
      return 0;
    }
    strcat(dst, mapped);
    first = 0;
    tok = strtok_r(NULL, " \t\r\n,;", &saveptr);
  }
  return 1;
}

static void print_help(void) {
  puts("MK-90 RT-11 style monitor:");
  puts("  H               help");
  puts("  Q               quit");
  puts("  D               display");
  puts("  R               reset");
  puts("  M RAD|DEG|GRD   mode");
  puts("  K ...           send MK-61 tokens");
  puts("  P ...           send MK-90 key aliases");
  puts("  S N             step cycles");
  puts("Examples:");
  puts("  P 1 2 ENT + 3 +");
  puts("  K PI");
}

int mk90_emulator_main(void) {
  mk61_ctx* ctx;
  char line[1024];
  char cmd[32];
  char arg[960];
  char out[64];
  char err[256];

  ctx = mk61_create();
  if (!ctx) {
    puts("ERR: cannot init mk61");
    return 1;
  }

  puts("MK-61 variant for MK-90 (RT-11 stub)");
  mk61_get_display_compact(ctx, out, (int)sizeof(out));
  printf("DISPLAY=%s\n", out);
  puts("Type H for help.");

  while (1) {
    int n;
    printf("MK90> ");
    fflush(stdout);
    if (!fgets(line, (int)sizeof(line), stdin)) break;
    if (sscanf(line, "%31s %959[^\n]", cmd, arg) < 1) continue;
    str_upper(cmd);

    if (strcmp(cmd, "H") == 0 || strcmp(cmd, "HELP") == 0) {
      print_help();
      continue;
    }
    if (strcmp(cmd, "Q") == 0 || strcmp(cmd, "QUIT") == 0) {
      break;
    }
    if (strcmp(cmd, "D") == 0 || strcmp(cmd, "DISPLAY") == 0) {
      mk61_get_display_text(ctx, out, (int)sizeof(out));
      printf("DISPLAY=%s\n", out);
      mk61_get_display_compact(ctx, out, (int)sizeof(out));
      printf("COMPACT=%s\n", out);
      continue;
    }
    if (strcmp(cmd, "R") == 0 || strcmp(cmd, "RESET") == 0) {
      mk61_reset(ctx, 120000);
      mk61_get_display_compact(ctx, out, (int)sizeof(out));
      printf("RESET OK DISPLAY=%s\n", out);
      continue;
    }
    if (strcmp(cmd, "M") == 0 || strcmp(cmd, "MODE") == 0) {
      char mode[32];
      if (sscanf(line, "%*s %31s", mode) < 1) {
        puts("usage: M RAD|DEG|GRD");
        continue;
      }
      if (!mk61_set_mode(ctx, mode)) {
        puts("invalid mode");
      } else {
        printf("MODE=%s\n", mode);
      }
      continue;
    }
    if (strcmp(cmd, "S") == 0 || strcmp(cmd, "STEP") == 0) {
      if (sscanf(line, "%*s %d", &n) < 1) {
        puts("usage: S N");
        continue;
      }
      if (n < 0) n = 0;
      mk61_step_cycles(ctx, n);
      mk61_get_display_compact(ctx, out, (int)sizeof(out));
      printf("DISPLAY=%s\n", out);
      continue;
    }
    if (strcmp(cmd, "K") == 0) {
      if (sscanf(line, "%*s %959[^\n]", arg) < 1) {
        puts("usage: K TOKENS...");
        continue;
      }
      if (!mk61_press_token_seq(ctx, arg, err, (int)sizeof(err))) {
        printf("ERR: %s\n", err);
      } else {
        mk61_get_display_compact(ctx, out, (int)sizeof(out));
        printf("DISPLAY=%s\n", out);
      }
      continue;
    }
    if (strcmp(cmd, "P") == 0) {
      char mk61_line[1024];
      if (sscanf(line, "%*s %959[^\n]", arg) < 1) {
        puts("usage: P KEYS...");
        continue;
      }
      if (!translate_mk90_to_mk61(arg, mk61_line, (int)sizeof(mk61_line), err, (int)sizeof(err))) {
        printf("ERR: %s\n", err);
        continue;
      }
      if (!mk61_press_token_seq(ctx, mk61_line, err, (int)sizeof(err))) {
        printf("ERR: %s\n", err);
      } else {
        mk61_get_display_compact(ctx, out, (int)sizeof(out));
        printf("DISPLAY=%s\n", out);
      }
      continue;
    }

    puts("unknown command, type H");
  }

  mk61_destroy(ctx);
  return 0;
}

#ifdef MK90_STUB_MAIN
int main(void) {
  return mk90_emulator_main();
}
#endif
