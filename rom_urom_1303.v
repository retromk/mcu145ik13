`timescale 1ns/1ps
module ik1303_urom(
  input wire clk,
  input wire [6:0] addr,
  output reg [31:0] dout
);
`ifdef GOWIN_BRAM_ROM
(* ram_style = "block" *) reg [31:0] mem [0:127];
integer i;
initial begin
  for (i = 0; i < 128; i = i + 1) mem[i] = 32'h00000000;
  $readmemh("rom_data/urom_1303.mem", mem);
end
always @(posedge clk) begin
  dout <= mem[addr];
end
`else
always @* begin
  case(addr)
    7'd0: dout = 32'h00000000;
    7'd1: dout = 32'h00800001;
    7'd2: dout = 32'h00040020;
    7'd3: dout = 32'h01440090;
    7'd4: dout = 32'h00A00081;
    7'd5: dout = 32'h01000000;
    7'd6: dout = 32'h01400020;
    7'd7: dout = 32'h00800008;
    7'd8: dout = 32'h00A03180;
    7'd9: dout = 32'h01002200;
    7'd10: dout = 32'h00800400;
    7'd11: dout = 32'h01418001;
    7'd12: dout = 32'h00080020;
    7'd13: dout = 32'h00841020;
    7'd14: dout = 32'h00203100;
    7'd15: dout = 32'h00203088;
    7'd16: dout = 32'h00A00820;
    7'd17: dout = 32'h00800120;
    7'd18: dout = 32'h008001C0;
    7'd19: dout = 32'h00810081;
    7'd20: dout = 32'h00A00089;
    7'd21: dout = 32'h00800401;
    7'd22: dout = 32'h00A010A0;
    7'd23: dout = 32'h00A01081;
    7'd24: dout = 32'h00818001;
    7'd25: dout = 32'h01A00220;
    7'd26: dout = 32'h00201100;
    7'd27: dout = 32'h00203420;
    7'd28: dout = 32'h00008000;
    7'd29: dout = 32'h00801020;
    7'd30: dout = 32'h00201420;
    7'd31: dout = 32'h00801190;
    7'd32: dout = 32'h00040000;
    7'd33: dout = 32'h00080820;
    7'd34: dout = 32'h00800002;
    7'd35: dout = 32'h00140002;
    7'd36: dout = 32'h00800100;
    7'd37: dout = 32'h00A03C20;
    7'd38: dout = 32'h00A00808;
    7'd39: dout = 32'h00A01008;
    7'd40: dout = 32'h00200540;
    7'd41: dout = 32'h00601209;
    7'd42: dout = 32'h00083100;
    7'd43: dout = 32'h00A03081;
    7'd44: dout = 32'h08800004;
    7'd45: dout = 32'h00058001;
    7'd46: dout = 32'h01001280;
    7'd47: dout = 32'h01008001;
    7'd48: dout = 32'h01200209;
    7'd49: dout = 32'h04018001;
    7'd50: dout = 32'h00040002;
    7'd51: dout = 32'h01000001;
    7'd52: dout = 32'h00010200;
    7'd53: dout = 32'h00800840;
    7'd54: dout = 32'h00A01181;
    7'd55: dout = 32'h04018801;
    7'd56: dout = 32'h00A10181;
    7'd57: dout = 32'h00800801;
    7'd58: dout = 32'h00040001;
    7'd59: dout = 32'h00011190;
    7'd60: dout = 32'h00858001;
    7'd61: dout = 32'h00040020;
    7'd62: dout = 32'h03200209;
    7'd63: dout = 32'h008000C0;
    7'd64: dout = 32'h04000020;
    7'd65: dout = 32'h00600081;
    7'd66: dout = 32'h01000000;
    7'd67: dout = 32'h01000180;
    default: dout = 32'h00000000;
  endcase
end
`endif
endmodule
