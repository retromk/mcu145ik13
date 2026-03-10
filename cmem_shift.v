`timescale 1ns/1ps
module cmem_shift #(parameter integer LEN=1008)(
  input wire clk,
  input wire rst,
  input wire tick_en,
  input wire in_bit,
  output wire out_bit
);
  reg out_reg;
  assign out_bit = out_reg;

`ifdef GOWIN_BRAM_SHIFT
  function integer clog2;
    input integer value;
    integer v;
    begin
      v = value - 1;
      clog2 = 0;
      while (v > 0) begin
        v = v >> 1;
        clog2 = clog2 + 1;
      end
    end
  endfunction

  localparam integer ADDR_W = (clog2(LEN) < 1) ? 1 : clog2(LEN);
  localparam [ADDR_W-1:0] LEN_LAST = LEN - 1;
  localparam [ADDR_W:0] LEN_COUNT = LEN;

  (* ram_style = "block" *) reg mem [0:LEN-1];
  reg [ADDR_W-1:0] head;
  reg [ADDR_W:0] fill_count;

  always @(posedge clk) begin
    if (rst) begin
      head <= {ADDR_W{1'b0}};
      fill_count <= {(ADDR_W+1){1'b0}};
      out_reg <= 1'b0;
    end else if (tick_en) begin
      if (fill_count < LEN_COUNT) out_reg <= 1'b0;
      else out_reg <= mem[head];

      mem[head] <= in_bit;
      if (head == LEN_LAST) head <= {ADDR_W{1'b0}};
      else head <= head + {{(ADDR_W-1){1'b0}}, 1'b1};

      if (fill_count < LEN_COUNT) fill_count <= fill_count + {{ADDR_W{1'b0}}, 1'b1};
    end
  end
`else
  reg [LEN-1:0] mem;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      mem <= {LEN{1'b0}};
      out_reg <= 1'b0;
    end else if (tick_en) begin
      // Emulate cMem::tick(): return old mem[0], then shift input in.
      out_reg <= mem[0];
      mem <= {in_bit, mem[LEN-1:1]};
    end
  end
`endif
endmodule
