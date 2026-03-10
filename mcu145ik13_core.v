`timescale 1ns/1ps
// Verilog-2005 port of pmkemu cMCU::tick() for IK1302/1303/1306 (bit-serial).
// - No SystemVerilog packages/structs.
// - ROMs are async by default; optional GOWIN_BRAM_ROM mode uses sync BRAM-backed tables.
// - ucmd_u bitfields match cmcu13.h exactly.

module mcu145ik13_core #(
  parameter integer CHIP = 1302,
  parameter integer PRETICK_IN = 0
)(
  input  wire        clk,
  input  wire        rst,
  input  wire        tick_en,

  input  wire        rin,
  output wire        rout,

  input  wire        k1,
  input  wire        k2,

  // Master-only observability (optional)
  output reg [3:0]   dcycle,
  output reg         syncout,
  output reg [7:0]   segment,

  // debug/trace
  output reg [5:0]   icount,
  output reg [3:0]   dcount,
  output reg [1:0]   ecount,
  output reg [1:0]   ucount,
  output reg [7:0]   cptr,
  output reg [31:0]  command,
  output reg [6:0]   cur_ucmd
);

  localparam integer MCU_BITLEN = 168;

  // shift registers
  reg [MCU_BITLEN-1:0] rr;
  reg [MCU_BITLEN-1:0] rm;
  reg [MCU_BITLEN-1:0] rstreg;

  reg [3:0] rs;
  reg [3:0] rs1;
  reg [3:0] rh;
  reg [3:0] dispout;

  reg sigma;
  reg carry;
  reg rl;
  reg rt;
  reg was_t_qrd;
  reg latchk1, latchk2;
  reg [6:0] asp;
  reg [6:0] cur_ucmd_dec;
  reg [6:0] asp_dec;
  reg spw_dec;
  reg sp_rr1_dec;
  reg sp_rr4_dec;
  wire [6:0] asp_lookup;

  // ROM wires
  wire [31:0] urom_word;
  wire [7:0] s0,s1,s2,s3,s4,s5,s6,s7,s8;

  ik13_urom #(.CHIP(CHIP)) UROM(.clk(clk), .addr(cur_ucmd_dec), .dout(urom_word));
  assign asp_lookup = (icount < 27) ? command[6:0] :
                      ((icount < 36) ? command[14:8] :
                      ((command[23:16] >= 8'h20) ? 7'h5f : {1'b0, command[21:16]}));

  ik13_srom #(.CHIP(CHIP)) SROM(.clk(clk), .addr(asp_lookup), .col0(s0), .col1(s1), .col2(s2), .col3(s3), .col4(s4), .col5(s5), .col6(s6), .col7(s7), .col8(s8));

  // ucmd_u bitfields (cmcu13.h)
  wire a_r    = urom_word[0];
  wire a_m    = urom_word[1];
  wire a_st   = urom_word[2];
  wire a_nr   = urom_word[3];
  wire a_10nl = urom_word[4];
  wire a_s    = urom_word[5];
  wire a_4    = urom_word[6];

  wire b_s    = urom_word[7];
  wire b_ns   = urom_word[8];
  wire b_s1   = urom_word[9];
  wire b_6    = urom_word[10];
  wire b_1    = urom_word[11];

  wire g_l    = urom_word[12];
  wire g_nl   = urom_word[13];
  wire g_nt   = urom_word[14];

  wire [2:0] r0   = urom_word[17:15];
  wire r_1         = urom_word[18];
  wire r_2         = urom_word[19];
  wire m_bit       = urom_word[20];
  wire l_bit       = urom_word[21];

  wire [1:0] s_op  = urom_word[23:22];
  wire [1:0] s1_op = urom_word[25:24];
  wire [1:0] st_op = urom_word[27:26];
  reg rout_reg;
  reg ret_bit;

  // In phase-scheduled top-level this holds the return bit of the most recent tick.
  assign rout = rout_reg;

  // jrom[42] from cmcu13.cpp
  function [3:0] jrom_idx;
    input [5:0] i;
    begin
      case(i)
        6'd0:  jrom_idx=0;  6'd1:  jrom_idx=1;  6'd2:  jrom_idx=2;  6'd3:  jrom_idx=3;
        6'd4:  jrom_idx=4;  6'd5:  jrom_idx=5;  6'd6:  jrom_idx=3;  6'd7:  jrom_idx=4;
        6'd8:  jrom_idx=5;  6'd9:  jrom_idx=3;  6'd10: jrom_idx=4;  6'd11: jrom_idx=5;
        6'd12: jrom_idx=3;  6'd13: jrom_idx=4;  6'd14: jrom_idx=5;  6'd15: jrom_idx=3;
        6'd16: jrom_idx=4;  6'd17: jrom_idx=5;  6'd18: jrom_idx=3;  6'd19: jrom_idx=4;
        6'd20: jrom_idx=5;  6'd21: jrom_idx=3;  6'd22: jrom_idx=4;  6'd23: jrom_idx=5;
        6'd24: jrom_idx=6;  6'd25: jrom_idx=7;  6'd26: jrom_idx=8;
        6'd27: jrom_idx=0;  6'd28: jrom_idx=1;  6'd29: jrom_idx=2;  6'd30: jrom_idx=3;
        6'd31: jrom_idx=4;  6'd32: jrom_idx=5;  6'd33: jrom_idx=6;  6'd34: jrom_idx=7;
        6'd35: jrom_idx=8;
        6'd36: jrom_idx=0;  6'd37: jrom_idx=1;  6'd38: jrom_idx=2;  6'd39: jrom_idx=3;
        6'd40: jrom_idx=4;  6'd41: jrom_idx=5;
        default: jrom_idx=0;
      endcase
    end
  endfunction

  integer i;
  reg [7:0] ucmd_raw;
  reg [3:0] jidx;
  reg [6:0] asp_next;
  reg [3:0] keybits_now;
  reg [3:0] keybits_latched;

  // temp vars per tick
  reg [MCU_BITLEN-1:0] rr_n, rm_n, rst_n;
  reg [3:0] rs_n, rs1_n, rh_n, dispout_n;
  reg sigma_n, carry_n, rl_n, rt_n, was_t_qrd_n, latchk1_n, latchk2_n;
  reg [5:0] icount_n;
  reg [3:0] dcount_n;
  reg [1:0] ecount_n, ucount_n;
  /* verilator lint_off UNOPTFLAT */
  reg [7:0] cptr_n;
  /* verilator lint_on UNOPTFLAT */
  reg [31:0] command_n;
  reg [6:0] cur_ucmd_n;
  reg [3:0] dcycle_n;
  reg syncout_n;
  reg [7:0] segment_n;
  reg [0:0] newm0;
  reg [0:0] newr0;
  reg [0:0] a,b,g;
  reg [1:0] sum2;
  reg temp;
  reg x,y,z;
  reg [7:0] cptr_hi;
  localparam [3:0] CONST_10 = 4'd10;
  localparam [3:0] CONST_6  = 4'd6;
  localparam [3:0] CONST_4  = 4'd4;
  localparam [3:0] CONST_1  = 4'd1;
  localparam [31:0] BOOT_COMMAND =
    (CHIP == 1302) ? 32'h00204E4E :
    (CHIP == 1303) ? 32'h00386050 :
    (CHIP == 1306) ? 32'h00070000 :
                     32'h00000000;

  wire [31:0] mrom_word_next;

  ik13_mrom #(.CHIP(CHIP)) MROM_NEXT(.clk(clk), .addr(cptr_n), .dout(mrom_word_next));

  // Decode current microcommand exactly as in cmcu13.cpp, in a dedicated comb stage.
  always @* begin
    asp_dec = 7'd0;
    cur_ucmd_dec = 7'd0;
    spw_dec = 1'b0;
    sp_rr1_dec = 1'b0;
    sp_rr4_dec = 1'b0;
    jidx = jrom_idx(icount);
    ucmd_raw = 8'd0;

    if (icount < 27) begin
      asp_dec = command[6:0];
    end else if ((icount >= 27) && (icount < 36)) begin
      asp_dec = command[14:8];
    end else begin
      if (command[23:16] >= 8'h20) begin
        if (icount == 36) begin
          spw_dec = 1'b1;
          sp_rr1_dec = command[5'd16 + {3'b000, ucount}];
          sp_rr4_dec = command[5'd20 + {3'b000, ucount}];
        end
        asp_dec = 7'h5f;
      end else begin
        asp_dec = {1'b0, command[21:16]};
      end
    end

    // Keep SROM column select explicit so simulators reliably track s0..s8
    // in this always block's implicit sensitivity list.
    case (jidx)
      4'd0: ucmd_raw = s0;
      4'd1: ucmd_raw = s1;
      4'd2: ucmd_raw = s2;
      4'd3: ucmd_raw = s3;
      4'd4: ucmd_raw = s4;
      4'd5: ucmd_raw = s5;
      4'd6: ucmd_raw = s6;
      4'd7: ucmd_raw = s7;
      default: ucmd_raw = s8;
    endcase

    ucmd_raw = ucmd_raw & 8'h3f;
    if (ucmd_raw > 8'h3b) begin
      ucmd_raw = (ucmd_raw - 8'h3c) * 2;
      ucmd_raw = ucmd_raw + (rl ? 8'd0 : 8'd1);
      ucmd_raw = ucmd_raw + 8'h3c;
    end
    cur_ucmd_dec = ucmd_raw[6:0];
  end

  always @* begin
    // defaults = hold
    rr_n = rr; rm_n = rm; rst_n = rstreg;
    rs_n = rs; rs1_n = rs1; rh_n = rh; dispout_n = dispout;
    sigma_n = sigma; carry_n = carry; rl_n = rl; rt_n = rt;
    was_t_qrd_n = was_t_qrd;
    latchk1_n = latchk1; latchk2_n = latchk2;
    icount_n = icount; dcount_n = dcount; ecount_n = ecount; ucount_n = ucount;
    cptr_n = cptr; command_n = command; cur_ucmd_n = cur_ucmd;
    dcycle_n = 0; syncout_n = 0; segment_n = 0;
    ret_bit = 0;
    keybits_now = {k2, 2'b00, k1};
    keybits_latched = {latchk2_n, 2'b00, latchk1_n};

    // emu145 IK1302 performs pretick(chain): rm[MSB] is loaded before tick().
    // Enabling this matches that behavior without changing U1/U2 semantics.
    if (PRETICK_IN != 0) begin
      rm_n[MCU_BITLEN-1] = rin;
    end

    // fetch current macro command (as in init / tick end)
    command_n = command;

    // Apply decode stage outputs.
    asp_next = asp_dec;
    cur_ucmd_n = cur_ucmd_dec;
    if (spw_dec) begin
      rr_n[4*1] = sp_rr1_dec;
      rr_n[4*4] = sp_rr4_dec;
    end

    // --- early s1 cases 2/3: rh[0]=keybit; rs1[0]|=rh[0] ---
    case (s1_op)
      2'd2, 2'd3: begin
        rh_n[0] = keybits_now[ucount];
        rs1_n[0] = rs1_n[0] | rh_n[0];
      end
      default: ;
    endcase

    // latch keys
    if (k1 | k2) begin
      latchk1_n = k1;
      latchk2_n = k2;
    end
    keybits_latched = {latchk2_n, 2'b00, latchk1_n};

    if (g_nt) was_t_qrd_n = 1'b1;

    if (latchk1_n | latchk2_n) rt_n = 1'b1;
    else rt_n = 1'b0;

    if (g_nt | was_t_qrd_n) begin
      rs1_n[0] = keybits_latched[ucount];
    end

    // --- A/B/G ---
    a=0; b=0; g=0;
    if (a_r)    a = a | rr_n[0];
    if (a_m)    a = a | rm_n[0];
    if (a_st)   a = a | rst_n[0];
    if (a_nr)   a = a | (~rr_n[0]);
    if (a_10nl) a = a | (CONST_10[ucount] & (~rl_n));
    if (a_s)    a = a | rs_n[0];
    if (a_4)    a = a | CONST_4[ucount];

    if (b_1)    b = b | CONST_1[ucount];
    if (b_6)    b = b | CONST_6[ucount];
    if (b_s)    b = b | rs_n[0];
    if (b_s1)   b = b | rs1_n[0];
    if (b_ns)   b = b | (~rs_n[0]);

    if (g_l)    g = g | rl_n;
    if (g_nl)   g = g | (~rl_n);
    if (g_nt)   g = g | (~rt_n);

    if (ucount != 0) g = carry_n;

    sum2 = a + b + g;     // 0..3
    sigma_n = sum2[0];
    carry_n = sum2[1];

    // --- newr0 ---
    case (r0)
      3'd0: newr0 = rr_n[0];
      3'd1: newr0 = rr_n[3*4];
      3'd2: newr0 = sigma_n;
      3'd3: newr0 = rs_n[0];
      3'd4: newr0 = rr_n[0] | rs_n[0] | sigma_n;
      3'd5: newr0 = rs_n[0] | sigma_n;
      3'd6: newr0 = rr_n[0] | rs_n[0];
      default: newr0 = rr_n[0] | sigma_n;
    endcase

    // r_1 / r_2 injection
    if (r_1) begin
      if (icount < 36) begin
        if ((command & 32'hff000000) == 0) rr_n[MCU_BITLEN-1*4] = sigma_n;
      end else rr_n[MCU_BITLEN-1*4] = sigma_n;
    end
    if (r_2) begin
      if (icount < 36) begin
        if ((command & 32'hff000000) == 0) rr_n[MCU_BITLEN-2*4] = sigma_n;
      end else rr_n[MCU_BITLEN-2*4] = sigma_n;
    end

    // latch L
    if (l_bit) begin
      if (ucount == 3) rl_n = carry_n;
    end

    // newm0
    if (m_bit) newm0 = rs_n[0];
    else newm0 = rm_n[0];

    // S op
    case (s_op)
      2'd0: begin
        temp = rs_n[0];
        rs_n[0]=rs_n[1]; rs_n[1]=rs_n[2]; rs_n[2]=rs_n[3];
        rs_n[3]=temp;
      end
      2'd1: begin
        rs_n[0]=rs_n[1]; rs_n[1]=rs_n[2]; rs_n[2]=rs_n[3];
        rs_n[3]=rs1_n[0];
      end
      2'd2: begin
        rs_n[0]=rs_n[1]; rs_n[1]=rs_n[2]; rs_n[2]=rs_n[3];
        rs_n[3]=sigma_n;
      end
      2'd3: begin
        temp = rs1_n[0];
        rs1_n[0]=rs1_n[1]; rs1_n[1]=rs1_n[2]; rs1_n[2]=rs1_n[3];
        rs1_n[3]=sigma_n | temp;
      end
    endcase

    // S1 op
    case (s1_op)
      2'd0: begin
        temp = rs1_n[0];
        rs1_n[0]=rs1_n[1]; rs1_n[1]=rs1_n[2]; rs1_n[2]=rs1_n[3];
        rs1_n[3]=temp;
      end
      2'd1: begin
        rs1_n[0]=rs1_n[1]; rs1_n[1]=rs1_n[2]; rs1_n[2]=rs1_n[3];
        rs1_n[3]=sigma_n;
      end
      2'd2: begin
        temp = rs1_n[0];
        rs1_n[0]=rs1_n[1]; rs1_n[1]=rs1_n[2]; rs1_n[2]=rs1_n[3];
        rs1_n[3]=temp;
      end
      2'd3: begin
        temp = rs1_n[0];
        rs1_n[0]=rs1_n[1]; rs1_n[1]=rs1_n[2]; rs1_n[2]=rs1_n[3];
        rs1_n[3]=temp | sigma_n;
      end
    endcase

    // ST op
    case (st_op)
      2'd1: begin
        rst_n[8]=rst_n[4];
        rst_n[4]=rst_n[0];
        rst_n[0]=sigma_n;
      end
      2'd2: begin
        temp = rst_n[0];
        rst_n[0]=rst_n[4];
        rst_n[4]=rst_n[8];
        rst_n[8]=temp;
      end
      2'd3: begin
        x = rst_n[0*4];
        y = rst_n[1*4];
        z = rst_n[2*4];
        rst_n[0*4] = sigma_n | y;
        rst_n[1*4] = x | z;
        rst_n[2*4] = x | y;
      end
      default: ;
    endcase

    // return bit
    ret_bit = newm0;

    // shift M
    for (i=0; i<MCU_BITLEN-1; i=i+1) rm_n[i] = rm_n[i+1];
    rm_n[MCU_BITLEN-1] = rin;

    // mod flag - do not modify R
    if ((icount < 36) && ((command & 32'hff000000) != 0)) newr0 = rr_n[0];

    // shift R
    for (i=0; i<MCU_BITLEN-1; i=i+1) rr_n[i] = rr_n[i+1];
    rr_n[MCU_BITLEN-1] = newr0;

    // rotate H
    temp = rh_n[0];
    rh_n[0]=rh_n[1]; rh_n[1]=rh_n[2]; rh_n[2]=rh_n[3];
    rh_n[3]=temp;

    // display shift
    if ((dcount < 13) && (ecount == 0)) begin
      dispout_n[0]=dispout_n[1];
      dispout_n[1]=dispout_n[2];
      dispout_n[2]=dispout_n[3];
      dispout_n[3]=newr0;
    end

    // shift ST with rotate bit0->MSB
    temp = rst_n[0];
    for (i=0; i<MCU_BITLEN-1; i=i+1) rst_n[i] = rst_n[i+1];
    rst_n[MCU_BITLEN-1] = temp;

    // counters
    if (ucount == 2'd3) begin
      ucount_n = 2'd0;
      icount_n = icount + 6'd1;
      ecount_n = ecount + 2'd1;
    end else begin
      ucount_n = ucount + 2'd1;
    end

    if (icount_n >= 42) begin
      icount_n = 0;
      // update cptr from rr bits (after shift, as in C++)
      cptr_hi = (rr_n[39*4+0] ? 8'd1 : 8'd0) |
                (rr_n[39*4+1] ? 8'd2 : 8'd0) |
                (rr_n[39*4+2] ? 8'd4 : 8'd0) |
                (rr_n[39*4+3] ? 8'd8 : 8'd0);
      cptr_n = {cptr_hi[3:0],
                (rr_n[36*4+3] ? 1'b1 : 1'b0),
                (rr_n[36*4+2] ? 1'b1 : 1'b0),
                (rr_n[36*4+1] ? 1'b1 : 1'b0),
                (rr_n[36*4+0] ? 1'b1 : 1'b0)};

      command_n = mrom_word_next;
      was_t_qrd_n = 1'b0;
      rt_n = 1'b0;
      latchk1_n = 1'b0;
      latchk2_n = 1'b0;
    end

    if (ecount_n >= 3) begin
      ecount_n = 0;
      dcount_n = dcount + 1;
    end
    if (dcount_n >= 14) begin
      dcount_n = 0;
    end

    // master outputs
    dcycle_n = (((command_n & 32'h00FC0000) == 0) && (ecount_n==0) && (ucount_n==0)) ? (dcount_n + 1) : 0;
    syncout_n = ((dcount_n==13) && (ecount_n==2) && (ucount_n==3)) ? 1'b1 : 1'b0;

    segment_n = (((command_n & 32'h00FC0000) == 0) && (ecount_n==0) && (ucount_n==0)) ?
                ({7'b0000000, dispout_n[0]} | ({7'b0000000, dispout_n[1]}<<1) | ({7'b0000000, dispout_n[2]}<<2) | ({7'b0000000, dispout_n[3]}<<3))
                : 8'h00;
    temp = (((command_n & 32'h00FC0000) == 0) ? rl_n : 1'b0);
    if (temp) segment_n = segment_n | 8'h80;

  end

  // sequential update
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rr <= 0; rm <= 0; rstreg <= 0;
      rs <= 0; rs1 <= 0; rh <= 0; dispout <= 0;
      sigma <= 0; carry <= 0; rl <= 0; rt <= 0; was_t_qrd <= 0;
      latchk1 <= 0; latchk2 <= 0; asp <= 0;
      icount <= 0; dcount <= 0; ecount <= 0; ucount <= 0;
      cptr <= 0; command <= BOOT_COMMAND; cur_ucmd <= 0;
      rout_reg <= 0;
      dcycle <= 0; syncout <= 0; segment <= 0;
    end else if (tick_en) begin
      rr <= rr_n; rm <= rm_n; rstreg <= rst_n;
      rs <= rs_n; rs1 <= rs1_n; rh <= rh_n; dispout <= dispout_n;
      sigma <= sigma_n; carry <= carry_n; rl <= rl_n; rt <= rt_n; was_t_qrd <= was_t_qrd_n;
      latchk1 <= latchk1_n; latchk2 <= latchk2_n; asp <= asp_next;
      icount <= icount_n; dcount <= dcount_n; ecount <= ecount_n; ucount <= ucount_n;
      cptr <= cptr_n;
      command <= command_n;
      cur_ucmd <= cur_ucmd_n;
      rout_reg <= ret_bit;
      dcycle <= dcycle_n; syncout <= syncout_n; segment <= segment_n;
    end
  end

endmodule
