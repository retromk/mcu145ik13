#include "fx2regs.h"
#include "fx2macros.h"
#include "delay.h"
#include "setupdat.h"
#include "eputils.h"

#define PA_CLK    bmBIT0
#define PA_RST    bmBIT1
#define PA_K1     bmBIT2
#define PA_K2     bmBIT3
#define PA_MODE0  bmBIT4
#define PA_MODE1  bmBIT5

#define CTRL_RST            bmBIT0
#define CTRL_MODE0          bmBIT1
#define CTRL_MODE1          bmBIT2
#define CTRL_DIRECT_MODE    bmBIT3
#define CTRL_DIRECT_K1      bmBIT4
#define CTRL_DIRECT_K2      bmBIT5
#define CTRL_USE_SCAN_GATE  bmBIT6
#define CTRL_AUTO_K2        bmBIT7

#define VR_GET_INFO      0xB0
#define VR_SET_CONTROL   0xB1
#define VR_STEP          0xB2
#define VR_QUEUE_BUTTON  0xB3
#define VR_GET_STATE     0xB4
#define VR_SET_HOLD      0xB5
#define VR_CLEAR_FRAME   0xB6

static __xdata BYTE g_display[12];
static __xdata BYTE g_reply[32];

static BYTE g_ctrl_bits;
static BYTE g_hold_cycles;
static BYTE g_pa_static;

static BYTE g_last_dcycle;
static BYTE g_last_sync;
static BYTE g_prev_sync;
static BYTE g_last_scan_active;
static BYTE g_last_segment;
static WORD g_frame_counter;

static BYTE g_pending_row;
static BYTE g_pending_col;
static BYTE g_active_row;
static BYTE g_active_hold;

static BYTE min_u8_word(BYTE limit, WORD v) {
  if (v < (WORD)limit) return (BYTE)v;
  return limit;
}

static void write_ep0_bytes(const __xdata BYTE *src, BYTE len) {
  BYTE i;
  for (i = 0; i < len; i++) {
    EP0BUF[i] = src[i];
  }
  EP0BCH = 0;
  EP0BCL = len;
}

static void row_to_lines(BYTE row, BYTE *k1, BYTE *k2) {
  switch (row) {
    case 1:
      *k1 = 1;
      *k2 = 0;
      break;
    case 2:
      *k1 = 0;
      *k2 = 1;
      break;
    case 3:
      *k1 = 1;
      *k2 = 1;
      break;
    default:
      *k1 = 0;
      *k2 = 0;
      break;
  }
}

static void apply_ctrl_static(void) {
  g_pa_static = 0;
  if (g_ctrl_bits & CTRL_RST) g_pa_static |= PA_RST;
  if (g_ctrl_bits & CTRL_MODE0) g_pa_static |= PA_MODE0;
  if (g_ctrl_bits & CTRL_MODE1) g_pa_static |= PA_MODE1;
  IOA = g_pa_static;
}

static void sample_inputs(void) {
  BYTE pb = IOB;
  BYTE seg = IOD;
  BYTE dcycle = pb & 0x0F;
  BYTE sync = (pb >> 4) & 0x01;
  BYTE scan = (pb >> 5) & 0x01;

  g_last_dcycle = dcycle;
  g_last_sync = sync;
  g_last_scan_active = scan;
  g_last_segment = seg;

  if ((dcycle >= 2) && (dcycle <= 13)) {
    g_display[dcycle - 2] = seg;
  }

  if ((sync != 0) && (g_prev_sync == 0)) {
    g_frame_counter++;
  }
  g_prev_sync = sync;
}

static void tick_once(void) {
  BYTE k1 = 0;
  BYTE k2 = 0;
  BYTE pa;

  if (g_ctrl_bits & CTRL_DIRECT_MODE) {
    if (g_ctrl_bits & CTRL_DIRECT_K1) k1 = 1;
    if (g_ctrl_bits & CTRL_DIRECT_K2) k2 = 1;
  } else {
    if ((g_ctrl_bits & CTRL_AUTO_K2) != 0) {
      BYTE auto_ok = 1;
      if ((g_ctrl_bits & CTRL_USE_SCAN_GATE) != 0) auto_ok = g_last_scan_active;
      if (auto_ok && (g_last_dcycle == 12)) k2 = 1;
    }

    if (g_active_hold != 0) {
      row_to_lines(g_active_row, &k1, &k2);
      g_active_hold--;
      if (g_active_hold == 0) {
        g_active_row = 0;
        g_pending_row = 0;
        g_pending_col = 0;
      }
    } else if ((g_pending_row >= 1) && (g_pending_row <= 3) && (g_pending_col <= 9)) {
      BYTE allow = (g_last_dcycle == (g_pending_col + 1));
      if ((g_ctrl_bits & CTRL_USE_SCAN_GATE) != 0) {
        allow = allow && (g_last_scan_active != 0);
      }

      if (allow) {
        g_active_row = g_pending_row;
        g_active_hold = g_hold_cycles;
        if (g_active_hold == 0) g_active_hold = 1;

        row_to_lines(g_active_row, &k1, &k2);

        g_active_hold--;
        if (g_active_hold == 0) {
          g_active_row = 0;
          g_pending_row = 0;
          g_pending_col = 0;
        }
      }
    }
  }

  pa = g_pa_static;
  if (k1) pa |= PA_K1;
  if (k2) pa |= PA_K2;

  IOA = pa;
  NOP;
  NOP;
  IOA = pa | PA_CLK;
  NOP;
  NOP;
  NOP;
  sample_inputs();
  IOA = pa;
}

static void tick_many(WORD count) {
  WORD i;
  for (i = 0; i < count; i++) {
    tick_once();
  }
}

static BYTE build_state_reply(void) {
  BYTE i;
  BYTE flags = 0;

  if ((g_pending_row >= 1) && (g_pending_row <= 3) && (g_pending_col <= 9)) flags |= bmBIT0;
  if (g_active_hold != 0) flags |= bmBIT1;
  if ((g_ctrl_bits & CTRL_DIRECT_MODE) != 0) flags |= bmBIT2;
  if ((g_ctrl_bits & CTRL_USE_SCAN_GATE) != 0) flags |= bmBIT3;
  if ((g_ctrl_bits & CTRL_AUTO_K2) != 0) flags |= bmBIT4;
  if (g_last_sync != 0) flags |= bmBIT5;
  if (g_last_scan_active != 0) flags |= bmBIT6;

  g_reply[0] = 1; /* protocol version */
  g_reply[1] = 1; /* firmware major */
  g_reply[2] = flags;
  g_reply[3] = g_ctrl_bits;
  g_reply[4] = g_hold_cycles;
  g_reply[5] = g_last_dcycle;
  g_reply[6] = g_last_segment;
  g_reply[7] = (BYTE)(g_frame_counter & 0xFF);
  g_reply[8] = (BYTE)((g_frame_counter >> 8) & 0xFF);
  g_reply[9] = g_pending_row;
  g_reply[10] = g_pending_col;
  g_reply[11] = g_active_row;
  g_reply[12] = g_active_hold;
  g_reply[13] = g_last_scan_active;

  for (i = 0; i < 12; i++) {
    g_reply[14 + i] = g_display[i];
  }

  return 26;
}

static BOOL request_is_vendor(void) {
  return (SETUPDAT[0] & 0x60) == 0x40;
}

static BOOL request_is_in(void) {
  return (SETUPDAT[0] & bmBIT7) != 0;
}

BOOL handle_vendorcommand(BYTE cmd) {
  BYTE n;

  if (!request_is_vendor()) return FALSE;

  switch (cmd) {
    case VR_GET_INFO:
    case VR_GET_STATE:
      if (!request_is_in()) return FALSE;
      n = build_state_reply();
      n = min_u8_word(n, SETUP_LENGTH());
      write_ep0_bytes(g_reply, n);
      return TRUE;

    case VR_SET_CONTROL:
      if (request_is_in()) return FALSE;
      g_ctrl_bits = SETUPDAT[2];
      apply_ctrl_static();
      return TRUE;

    case VR_STEP:
      {
        WORD steps;
        if (!request_is_in()) return FALSE;
        steps = SETUP_VALUE();
        if (steps == 0) steps = 1;
        tick_many(steps);
        n = build_state_reply();
        n = min_u8_word(n, SETUP_LENGTH());
        write_ep0_bytes(g_reply, n);
      }
      return TRUE;

    case VR_QUEUE_BUTTON:
      if (request_is_in()) return FALSE;
      if (SETUPDAT[2] == 0) {
        g_pending_row = 0;
        g_pending_col = 0;
        g_active_row = 0;
        g_active_hold = 0;
        return TRUE;
      }
      if ((SETUPDAT[2] < 1) || (SETUPDAT[2] > 3) || (SETUPDAT[3] > 9)) {
        return FALSE;
      }
      g_pending_row = SETUPDAT[2];
      g_pending_col = SETUPDAT[3];
      g_active_row = 0;
      g_active_hold = 0;
      return TRUE;

    case VR_SET_HOLD:
      if (request_is_in()) return FALSE;
      g_hold_cycles = SETUPDAT[2];
      if (g_hold_cycles == 0) g_hold_cycles = 1;
      return TRUE;

    case VR_CLEAR_FRAME:
      if (request_is_in()) return FALSE;
      g_frame_counter = 0;
      return TRUE;

    default:
      return FALSE;
  }
}

BOOL handle_get_descriptor(void) {
  return FALSE;
}

BOOL handle_get_interface(BYTE ifc, BYTE *alt_ifc) {
  (void)ifc;
  *alt_ifc = 0;
  return TRUE;
}

BOOL handle_set_interface(BYTE ifc, BYTE alt_ifc) {
  (void)ifc;
  (void)alt_ifc;
  return TRUE;
}

BYTE handle_get_configuration(void) {
  return 1;
}

BOOL handle_set_configuration(BYTE cfg) {
  return (cfg == 0) || (cfg == 1);
}

void handle_reset_ep(BYTE ep) {
  (void)ep;
}

static void init_state(void) {
  BYTE i;

  g_ctrl_bits = CTRL_RST | CTRL_USE_SCAN_GATE | CTRL_AUTO_K2;
  g_hold_cycles = 4;
  g_pa_static = 0;

  g_last_dcycle = 0;
  g_last_sync = 0;
  g_prev_sync = 0;
  g_last_scan_active = 0;
  g_last_segment = 0;
  g_frame_counter = 0;

  g_pending_row = 0;
  g_pending_col = 0;
  g_active_row = 0;
  g_active_hold = 0;

  for (i = 0; i < 12; i++) g_display[i] = 0x0F;
  g_display[7] = 0x80;
}

static void main_init(void) {
  REVCTL = 0x03;
  SETCPUFREQ(CLK_48M);

  IFCONFIG = bmIFCLKSRC | bm3048MHZ;
  SYNCDELAY3;

  EP1OUTCFG = 0x00;
  EP1INCFG = 0x00;
  EP2CFG = 0x00;
  EP4CFG = 0x00;
  EP6CFG = 0x00;
  EP8CFG = 0x00;

  PORTACFG = 0x00;
  PORTCCFG = 0x00;
  PORTECFG = 0x00;

  OEA = PA_CLK | PA_RST | PA_K1 | PA_K2 | PA_MODE0 | PA_MODE1;
  OEB = 0x00;
  OEC = 0x00;
  OED = 0x00;

  init_state();
  apply_ctrl_static();
  sample_inputs();

  handle_hispeed((USBCS & bmHSM) ? TRUE : FALSE);

  USBIE = bmSUDAV | bmURES | bmHSGRANT;

  USBCS |= bmRENUM | bmDISCON;
  delay(25);
  USBCS &= (BYTE)~bmDISCON;
}

void main(void) {
  main_init();

  while (TRUE) {
    BYTE irq = USBIRQ;

    if (irq & bmSUDAV) {
      EXIF &= (BYTE)~bmBIT4;
      USBIRQ = bmSUDAV;
      handle_setupdata();
    }

    if (irq & bmURES) {
      EXIF &= (BYTE)~bmBIT4;
      USBIRQ = bmURES;
      handle_hispeed(FALSE);
    }

    if (irq & bmHSGRANT) {
      EXIF &= (BYTE)~bmBIT4;
      USBIRQ = bmHSGRANT;
      handle_hispeed(TRUE);
    }
  }
}
