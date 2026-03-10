`timescale 1ns/1ps
module mk61_top_1k(
  input wire clk,
  input wire rst,
  input wire k1,
  input wire k2,
  input wire [1:0] mode, // kept for pin-compatible top-level interface
  output wire [3:0] dcycle,
  output wire syncout,
  output wire [7:0] segment
);
  wire serial_ring;
  wire [3:0] dcycle_u0;
  wire syncout_u0;
  wire [7:0] segment_u0;

  // Keep input for interface compatibility even though 1K profile does not use mode logic.
  wire mode_unused;
  assign mode_unused = mode[0] ^ mode[1];

  // Resource-constrained 1K profile:
  // - single IK1302 core
  // - local serial feedback (no external multi-chip/memory ring)
  mcu145ik13_core #(.CHIP(1302), .PRETICK_IN(0)) U0(
    .clk(clk),
    .rst(rst),
    .tick_en(1'b1),
    .rin(serial_ring),
    .rout(serial_ring),
    .k1(k1),
    .k2(k2),
    .dcycle(dcycle_u0),
    .syncout(syncout_u0),
    .segment(segment_u0),
    .icount(),
    .dcount(),
    .ecount(),
    .ucount(),
    .cptr(),
    .command(),
    .cur_ucmd()
  );

  assign dcycle = dcycle_u0;
  assign syncout = syncout_u0;
  assign segment = segment_u0;

endmodule
