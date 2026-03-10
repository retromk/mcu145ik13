`timescale 1ns/1ps
module mk61_top(
  input wire clk,
  input wire rst,
  input wire k1,
  input wire k2,
  input wire [1:0] mode, // 0=RAD, 1=DEG, 2=GRD (emu145-compatible)
  output wire [3:0] dcycle,
  output wire syncout,
  output wire [7:0] segment
);
  wire d0,d1,d2,d3,d4,d5;
  reg [2:0] phase;
  wire [3:0] dcount_u1;
  wire [3:0] dcycle_u0;
  wire syncout_u0;
  wire [7:0] segment_u0;
  wire chain;
  wire mode_k1_u1;
  wire tick_u0, tick_u1, tick_u2, tick_m0, tick_m1;
  wire u0_visible;

  assign chain = d5;
  assign d0 = chain;
  assign tick_u0 = (phase == 3'd0);
  assign tick_u1 = (phase == 3'd1);
  assign tick_u2 = (phase == 3'd2);
  assign tick_m0 = (phase == 3'd3);
  assign tick_m1 = (phase == 3'd4);
  assign u0_visible = (phase == 3'd1);
  assign dcycle = u0_visible ? dcycle_u0 : 4'd0;
  assign syncout = u0_visible ? syncout_u0 : 1'b0;
  assign segment = u0_visible ? segment_u0 : 8'h00;

  assign mode_k1_u1 =
    (mode == 2'd0) ? (dcount_u1 != 4'd9)  :
    (mode == 2'd1) ? (dcount_u1 != 4'd10) :
                     (dcount_u1 != 4'd11);

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      phase <= 3'd0;
    end else begin
      if (phase == 3'd4) phase <= 3'd0;
      else phase <= phase + 3'd1;
    end
  end

  // Master IK1302 provides dcycle/sync/segment
  mcu145ik13_core #(.CHIP(1302), .PRETICK_IN(1)) U0(
    .clk(clk), .rst(rst), .tick_en(tick_u0),
    .rin(d0), .rout(d1),
    .k1(k1), .k2(k2),
    .dcycle(dcycle_u0), .syncout(syncout_u0), .segment(segment_u0),
    .icount(), .dcount(), .ecount(), .ucount(), .cptr(), .command(), .cur_ucmd()
  );

  mcu145ik13_core #(.CHIP(1303), .PRETICK_IN(0)) U1(
    .clk(clk), .rst(rst), .tick_en(tick_u1),
    .rin(d1), .rout(d2),
    .k1(mode_k1_u1), .k2(1'b0),
    .dcycle(), .syncout(), .segment(),
    .icount(), .dcount(dcount_u1), .ecount(), .ucount(), .cptr(), .command(), .cur_ucmd()
  );

  mcu145ik13_core #(.CHIP(1306), .PRETICK_IN(0)) U2(
    .clk(clk), .rst(rst), .tick_en(tick_u2),
    .rin(d2), .rout(d3),
    .k1(1'b0), .k2(1'b0),
    .dcycle(), .syncout(), .segment(),
    .icount(), .dcount(), .ecount(), .ucount(), .cptr(), .command(), .cur_ucmd()
  );

  cmem_shift #(.LEN(1008)) M0(.clk(clk), .rst(rst), .tick_en(tick_m0), .in_bit(d3), .out_bit(d4));
  cmem_shift #(.LEN(1008)) M1(.clk(clk), .rst(rst), .tick_en(tick_m1), .in_bit(d4), .out_bit(d5));

endmodule
