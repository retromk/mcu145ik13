`timescale 1ns/1ps
module ik13_mrom #(parameter integer CHIP=1302)(
  input wire clk,
  input wire [7:0] addr,
  output wire [31:0] dout
);
generate
  if (CHIP==1302) begin : G0
    ik1302_mrom u(.clk(clk), .addr(addr), .dout(dout));
  end else if (CHIP==1303) begin : G1
    ik1303_mrom u(.clk(clk), .addr(addr), .dout(dout));
  end else begin : G2
    ik1306_mrom u(.clk(clk), .addr(addr), .dout(dout));
  end
endgenerate
endmodule

module ik13_urom #(parameter integer CHIP=1302)(
  input wire clk,
  input wire [6:0] addr,
  output wire [31:0] dout
);
generate
  if (CHIP==1302) begin : G0
    ik1302_urom u(.clk(clk), .addr(addr), .dout(dout));
  end else if (CHIP==1303) begin : G1
    ik1303_urom u(.clk(clk), .addr(addr), .dout(dout));
  end else begin : G2
    ik1306_urom u(.clk(clk), .addr(addr), .dout(dout));
  end
endgenerate
endmodule

module ik13_srom #(parameter integer CHIP=1302)(
  input wire clk,
  input wire [6:0] addr,
  output wire [7:0] col0,
  output wire [7:0] col1,
  output wire [7:0] col2,
  output wire [7:0] col3,
  output wire [7:0] col4,
  output wire [7:0] col5,
  output wire [7:0] col6,
  output wire [7:0] col7,
  output wire [7:0] col8
);
generate
  if (CHIP==1302) begin : G0
    ik1302_srom u(.clk(clk), .addr(addr), .col0(col0), .col1(col1), .col2(col2), .col3(col3), .col4(col4), .col5(col5), .col6(col6), .col7(col7), .col8(col8));
  end else if (CHIP==1303) begin : G1
    ik1303_srom u(.clk(clk), .addr(addr), .col0(col0), .col1(col1), .col2(col2), .col3(col3), .col4(col4), .col5(col5), .col6(col6), .col7(col7), .col8(col8));
  end else begin : G2
    ik1306_srom u(.clk(clk), .addr(addr), .col0(col0), .col1(col1), .col2(col2), .col3(col3), .col4(col4), .col5(col5), .col6(col6), .col7(col7), .col8(col8));
  end
endgenerate
endmodule
