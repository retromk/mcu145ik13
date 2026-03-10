`timescale 1ns/1ps
module mk61_top_1k_board(
  input wire CLK,      // Pin 47 (27 MHz oscillator)
  input wire KEY_A_N,  // Pin 13, active-low key
  output wire LED_R_N, // Pin 9,  active-low RGB LED red
  output wire LED_G_N, // Pin 11, active-low RGB LED green
  output wire LED_B_N  // Pin 10, active-low RGB LED blue
);
  reg [19:0] boot_cnt = 20'd0;
  wire boot_rst = (boot_cnt != 20'hFFFFF);
  wire k1 = ~KEY_A_N;
  wire [3:0] dcycle;
  wire syncout;
  wire [7:0] segment;

  reg [20:0] sync_stretch = 21'd0;
  wire seg_nonzero = |segment;
  wire sync_pulse = syncout;
  wire hb = boot_cnt[19];

  // Start with a deterministic reset pulse after configuration.
  always @(posedge CLK) begin
    if (boot_cnt != 20'hFFFFF) boot_cnt <= boot_cnt + 20'd1;
  end

  // Stretch sync pulse to make it visible on onboard LED.
  always @(posedge CLK) begin
    if (sync_pulse) sync_stretch <= 21'h1FFFFF;
    else if (sync_stretch != 0) sync_stretch <= sync_stretch - 21'd1;
  end

  mk61_top_1k U(
    .clk(CLK),
    .rst(boot_rst),
    .k1(k1),
    .k2(1'b0),
    .mode(2'b00), // RAD
    .dcycle(dcycle),
    .syncout(syncout),
    .segment(segment)
  );

  // Active-low LEDs:
  // - R: heartbeat while running
  // - G: any segment activity
  // - B: stretched sync pulses
  assign LED_R_N = ~hb;
  assign LED_G_N = ~seg_nonzero;
  assign LED_B_N = ~(sync_stretch != 0);

endmodule
