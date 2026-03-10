`timescale 1ns/1ps
module ik1306_srom(
  input wire clk,
  input wire [6:0] addr,
  output reg [7:0] col0,
  output reg [7:0] col1,
  output reg [7:0] col2,
  output reg [7:0] col3,
  output reg [7:0] col4,
  output reg [7:0] col5,
  output reg [7:0] col6,
  output reg [7:0] col7,
  output reg [7:0] col8
);
`ifdef GOWIN_BRAM_ROM
(* ram_style = "block" *) reg [71:0] mem [0:127];
integer i;
initial begin
  for (i = 0; i < 128; i = i + 1) mem[i] = 72'h0;
  $readmemh("rom_data/srom_1306.mem", mem);
end
always @(posedge clk) begin
  {col0,col1,col2,col3,col4,col5,col6,col7,col8} <= mem[addr];
end
`else
always @* begin
  case(addr)
    7'd0: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd1: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h2C, 8'h2A, 8'h27, 8'h13, 8'h2B, 8'h27, 8'h13, 8'h2B, 8'h27}; end
    7'd2: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h34, 8'h2A, 8'h27, 8'h13, 8'h2B, 8'h27, 8'h13, 8'h2B, 8'h27}; end
    7'd3: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h29, 8'h2A, 8'h35, 8'h29, 8'h2B, 8'h35, 8'h29, 8'h2B, 8'h35}; end
    7'd4: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h29, 8'h12, 8'h35, 8'h29, 8'h3F, 8'h35, 8'h29, 8'h3F, 8'h35}; end
    7'd5: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h2E, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd6: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h2A, 8'h02, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd7: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h12, 8'h05, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd8: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd9: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h02, 8'h00, 8'h24, 8'h02, 8'h00, 8'h24, 8'h02, 8'h00}; end
    7'd10: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h30, 8'h1D, 8'h05, 8'h2F, 8'h1D, 8'h00, 8'h00, 8'h1D, 8'h00}; end
    7'd11: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h22, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd12: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0C, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd13: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd14: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h24, 8'h25, 8'h00}; end
    7'd15: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h31, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd16: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h0F, 8'h0F, 8'h0F}; end
    7'd17: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h34, 8'h05, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd18: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd19: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h03, 8'h18, 8'h00, 8'h00, 8'h00}; end
    7'd20: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h18, 8'h25, 8'h00, 8'h03, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd21: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h03, 8'h39, 8'h00, 8'h00, 8'h00, 8'h14, 8'h18, 8'h00}; end
    7'd22: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h36, 8'h00, 8'h00, 8'h03, 8'h0B, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd23: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h03, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd24: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h37, 8'h1E, 8'h00, 8'h00, 8'h1E, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd25: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h01, 8'h06, 8'h07, 8'h01, 8'h06, 8'h07, 8'h01, 8'h06, 8'h07}; end
    7'd26: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h34, 8'h12, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd27: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3C, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd28: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3E, 8'h00, 8'h00, 8'h2D, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd29: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd30: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd31: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd32: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h01, 8'h25, 8'h00, 8'h01, 8'h25, 8'h00, 8'h24, 8'h02, 8'h00}; end
    7'd33: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h04, 8'h02, 8'h03, 8'h04, 8'h02, 8'h24, 8'h02, 8'h00}; end
    7'd34: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h01, 8'h06, 8'h07, 8'h01, 8'h06, 8'h07, 8'h24, 8'h02, 8'h00}; end
    7'd35: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h01, 8'h04, 8'h08, 8'h01, 8'h04, 8'h08, 8'h24, 8'h00, 8'h1A}; end
    7'd36: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h06, 8'h09, 8'h03, 8'h06, 8'h09, 8'h24, 8'h00, 8'h02}; end
    7'd37: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h25, 8'h00, 8'h03, 8'h25, 8'h00, 8'h24, 8'h25, 8'h00}; end
    7'd38: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h00, 8'h38, 8'h03, 8'h00, 8'h0B, 8'h03, 8'h25, 8'h00}; end
    7'd39: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h25, 8'h00, 8'h24, 8'h25, 8'h0E, 8'h05, 8'h00, 8'h00}; end
    7'd40: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h25, 8'h00, 8'h03, 8'h25, 8'h00, 8'h03, 8'h25, 8'h00}; end
    7'd41: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h19, 8'h05, 8'h00, 8'h19, 8'h05, 8'h00, 8'h00}; end
    7'd42: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h29, 8'h12}; end
    7'd43: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h21, 8'h00, 8'h00, 8'h21, 8'h24, 8'h25, 8'h03, 8'h25}; end
    7'd44: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h0D, 8'h02, 8'h00, 8'h0D, 8'h02, 8'h00, 8'h0D, 8'h02}; end
    7'd45: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h17, 8'h00, 8'h00, 8'h17, 8'h24, 8'h05, 8'h00, 8'h00}; end
    7'd46: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h00, 8'h05, 8'h24, 8'h00, 8'h05, 8'h24, 8'h00, 8'h05}; end
    7'd47: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h25, 8'h00, 8'h24, 8'h25, 8'h00, 8'h24, 8'h25, 8'h00}; end
    7'd48: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h13, 8'h0A, 8'h00, 8'h00, 8'h03, 8'h0B, 8'h00, 8'h28, 8'h00}; end
    7'd49: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h03, 8'h05, 8'h00, 8'h03, 8'h05, 8'h00, 8'h03, 8'h05}; end
    7'd50: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h03, 8'h00, 8'h0B, 8'h03, 8'h0B, 8'h00, 8'h00, 8'h00}; end
    7'd51: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h2C, 8'h02, 8'h00, 8'h24, 8'h02, 8'h00, 8'h24, 8'h02, 8'h00}; end
    7'd52: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h02, 8'h00, 8'h00}; end
    7'd53: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h0F, 8'h0F, 8'h00}; end
    7'd54: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h16, 8'h00, 8'h00, 8'h16, 8'h00, 8'h00, 8'h16, 8'h00}; end
    7'd55: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h17, 8'h00, 8'h00, 8'h17, 8'h00, 8'h00, 8'h00, 8'h21}; end
    7'd56: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h17, 8'h00, 8'h00, 8'h17, 8'h24, 8'h02, 8'h00}; end
    7'd57: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h29, 8'h12, 8'h00}; end
    7'd58: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h14, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h0F, 8'h00, 8'h00}; end
    7'd59: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h0F, 8'h00, 8'h00}; end
    7'd60: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h13, 8'h0A, 8'h00, 8'h00, 8'h03, 8'h0B, 8'h00, 8'h00, 8'h00}; end
    7'd61: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h18, 8'h0B, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd62: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h13, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h00, 8'h2A, 8'h00}; end
    7'd63: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h03, 8'h3D, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd64: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h3B, 8'h00, 8'h00, 8'h3B, 8'h00, 8'h12, 8'h14, 8'h00}; end
    7'd65: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h00, 8'h00, 8'h0F, 8'h00, 8'h00, 8'h05, 8'h24, 8'h02}; end
    7'd66: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h00, 8'h25, 8'h03, 8'h00, 8'h25, 8'h03, 8'h00, 8'h25}; end
    7'd67: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h20, 8'h00, 8'h00, 8'h20, 8'h00, 8'h00, 8'h20}; end
    7'd68: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h11, 8'h05, 8'h00, 8'h11, 8'h05, 8'h00, 8'h11, 8'h05}; end
    7'd69: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h11, 8'h25, 8'h00, 8'h11, 8'h25, 8'h00, 8'h11, 8'h25}; end
    7'd70: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h10, 8'h00, 8'h00}; end
    7'd71: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h00, 8'h00, 8'h33, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd72: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h2A, 8'h0F, 8'h0F, 8'h12, 8'h00, 8'h00}; end
    7'd73: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h1B, 8'h1C, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd74: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h15, 8'h00, 8'h03, 8'h15, 8'h00, 8'h03, 8'h15, 8'h00}; end
    7'd75: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h02, 8'h00, 8'h00, 8'h00, 8'h00, 8'h1B, 8'h02, 8'h00}; end
    7'd76: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h03, 8'h00, 8'h12, 8'h00, 8'h00, 8'h00}; end
    7'd77: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h03, 8'h12, 8'h12, 8'h12, 8'h12, 8'h00}; end
    7'd78: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h24, 8'h23, 8'h02}; end
    7'd79: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h24, 8'h23, 8'h02, 8'h00}; end
    7'd80: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h26, 8'h27, 8'h00, 8'h28, 8'h27, 8'h00, 8'h28, 8'h27, 8'h00}; end
    7'd81: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h26, 8'h27, 8'h00, 8'h28, 8'h27, 8'h00, 8'h28, 8'h27}; end
    7'd82: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h29, 8'h2A, 8'h27, 8'h29, 8'h2B, 8'h27, 8'h29, 8'h2B, 8'h3A}; end
    7'd83: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h12, 8'h12, 8'h12, 8'h00, 8'h00, 8'h10, 8'h00, 8'h00}; end
    7'd84: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h12, 8'h00, 8'h00, 8'h00, 8'h00, 8'h10, 8'h00, 8'h00}; end
    7'd85: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h0F, 8'h0F, 8'h0F, 8'h00}; end
    7'd86: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h25, 8'h00, 8'h0E, 8'h0F, 8'h0F, 8'h0F}; end
    7'd87: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h0F, 8'h00, 8'h00, 8'h0F, 8'h0F, 8'h0F, 8'h0F}; end
    7'd88: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h0E, 8'h18, 8'h00}; end
    7'd89: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd90: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h1D, 8'h00, 8'h00, 8'h1D, 8'h00, 8'h00, 8'h1D, 8'h00}; end
    7'd91: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1F, 8'h1A, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd92: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h16, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd93: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h16, 8'h05, 8'h00, 8'h16, 8'h05, 8'h00, 8'h16, 8'h05}; end
    7'd94: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h16, 8'h02, 8'h00, 8'h16, 8'h02, 8'h00, 8'h16, 8'h02}; end
    7'd95: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h21, 8'h02, 8'h03, 8'h21, 8'h02, 8'h03, 8'h21, 8'h02}; end
    7'd96: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h18, 8'h0F, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd97: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h1B, 8'h03, 8'h0B, 8'h00, 8'h00, 8'h00}; end
    7'd98: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h12, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd99: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h1B, 8'h03, 8'h3D, 8'h00, 8'h00, 8'h00}; end
    7'd100: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h18, 8'h03, 8'h18, 8'h05, 8'h03, 8'h18, 8'h05, 8'h00}; end
    7'd101: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h00, 8'h32, 8'h03, 8'h00, 8'h32, 8'h03, 8'h00, 8'h32}; end
    7'd102: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h24, 8'h33, 8'h00, 8'h00, 8'h33, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd103: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h21, 8'h00, 8'h00, 8'h21, 8'h00, 8'h00, 8'h00}; end
    7'd104: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h2C, 8'h2A, 8'h27, 8'h13, 8'h2B, 8'h27, 8'h00, 8'h00}; end
    7'd105: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h03, 8'h25, 8'h00, 8'h03, 8'h25, 8'h00, 8'h13, 8'h09, 8'h00}; end
    7'd106: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h3B, 8'h05, 8'h00, 8'h3B, 8'h05, 8'h00, 8'h3B, 8'h05}; end
    7'd107: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h0D, 8'h05, 8'h00, 8'h0D, 8'h05, 8'h00, 8'h0D, 8'h05}; end
    7'd108: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h13, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h07}; end
    7'd109: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h18, 8'h0B, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd110: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h17, 8'h00, 8'h00, 8'h17, 8'h0E, 8'h05, 8'h0D, 8'h02}; end
    7'd111: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h18, 8'h00, 8'h25, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00}; end
    7'd112: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h03, 8'h00, 8'h00, 8'h00, 8'h18, 8'h00, 8'h00}; end
    7'd113: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h13, 8'h09, 8'h00, 8'h00, 8'h09, 8'h00, 8'h00, 8'h09, 8'h00}; end
    7'd114: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h0F, 8'h02, 8'h24, 8'h25, 8'h00, 8'h24, 8'h25, 8'h00}; end
    7'd115: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h00, 8'h00, 8'h29, 8'h0F, 8'h0F, 8'h0F, 8'h12, 8'h00}; end
    7'd116: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h29, 8'h12, 8'h00, 8'h29, 8'h3F, 8'h00, 8'h13, 8'h0F}; end
    7'd117: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h00, 8'h3D, 8'h00, 8'h00, 8'h3D, 8'h00, 8'h00, 8'h3D, 8'h00}; end
    7'd118: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h1B, 8'h03, 8'h00, 8'h0B, 8'h03, 8'h0B, 8'h13, 8'h39, 8'h24}; end
    7'd119: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h0E, 8'h02, 8'h00, 8'h24, 8'h02, 8'h00, 8'h13, 8'h07, 8'h00}; end
    7'd120: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd121: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd122: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd123: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd124: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd125: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd126: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    7'd127: begin {col0,col1,col2,col3,col4,col5,col6,col7,col8} = {8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F}; end
    default: begin col0=8'h00; col1=8'h00; col2=8'h00; col3=8'h00; col4=8'h00; col5=8'h00; col6=8'h00; col7=8'h00; col8=8'h00; end
  endcase
end
`endif
endmodule
