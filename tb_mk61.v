`timescale 1ns/1ps
module tb_mk61;
  localparam integer CLK_HALF_PERIOD_NS = 5;
  localparam integer RESET_CYCLES = 8;
  localparam integer DEFAULT_CYCLES = 20000;
  localparam integer PIPE_PHASE_CYCLES = 5;
  localparam integer SYNC_PERIOD_CYCLES = 168 * PIPE_PHASE_CYCLES;
  localparam integer MAX_KEY_EVENTS = 1024;
  localparam integer MAX_BUTTON_EVENTS = 1024;
  localparam integer INPUT_MODE_KEYS = 0;
  localparam integer INPUT_MODE_BUTTONS = 1;

  reg clk = 1'b0;
  reg rst = 1'b1;
  reg k1 = 1'b0;
  reg k2 = 1'b0;
  reg [1:0] mode = 2'd0;

  wire [3:0] dcycle;
  wire       syncout;
  wire [7:0] segment;

  integer trace_fd;
  integer cycle;
  integer sim_cycles;
  integer errors;
  integer sync_count;
  integer last_sync_cycle;
  integer sync_delta;
  integer mode_sel;

  integer key_event_cycle [0:MAX_KEY_EVENTS-1];
  reg     key_event_k1 [0:MAX_KEY_EVENTS-1];
  reg     key_event_k2 [0:MAX_KEY_EVENTS-1];
  integer key_event_count;
  integer key_event_idx;
  integer key_file_fd;
  integer key_file_cycle;
  integer key_file_k1;
  integer key_file_k2;
  integer key_scan_rv;
  integer key_load_done;
  reg [1023:0] key_file_path;

  integer button_event_cycle [0:MAX_BUTTON_EVENTS-1];
  integer button_event_row [0:MAX_BUTTON_EVENTS-1];
  integer button_event_col [0:MAX_BUTTON_EVENTS-1];
  integer button_event_count;
  integer button_event_idx;
  integer button_file_fd;
  integer button_file_cycle;
  integer button_file_row;
  integer button_file_col;
  integer button_scan_rv;
  integer button_load_done;
  reg [1023:0] button_file_path;

  integer input_mode;
  integer btnpressed;
  reg [1:0] btn_row;
  reg [3:0] btn_col;

  mk61_top dut(
    .clk(clk),
    .rst(rst),
    .k1(k1),
    .k2(k2),
    .mode(mode),
    .dcycle(dcycle),
    .syncout(syncout),
    .segment(segment)
  );

  always #CLK_HALF_PERIOD_NS clk = ~clk;

  task load_input_events;
    begin
      key_event_count = 0;
      button_event_count = 0;
      input_mode = INPUT_MODE_KEYS;

      if ($value$plusargs("buttons=%s", button_file_path)) begin
        input_mode = INPUT_MODE_BUTTONS;
        button_file_fd = $fopen(button_file_path, "r");
        if (button_file_fd == 0) begin
          $display("[TB][FAIL] cannot open button events file: %0s", button_file_path);
`ifdef __ICARUS__
          $finish_and_return(1);
`else
          $finish;
`endif
        end
        button_load_done = 0;
        while ((button_event_count < MAX_BUTTON_EVENTS) && (button_load_done == 0)) begin
          button_scan_rv = $fscanf(button_file_fd, "%d %d %d\n", button_file_cycle, button_file_row, button_file_col);
          if (button_scan_rv != 3) begin
            button_load_done = 1;
          end else begin
            if (button_file_cycle < 0) button_file_cycle = 0;
            if ((button_file_row < 1) || (button_file_row > 3) || (button_file_col < 0) || (button_file_col > 9)) begin
              $display("[TB][WARN] skip invalid button event: cycle=%0d row=%0d col=%0d", button_file_cycle, button_file_row, button_file_col);
            end else begin
              button_event_cycle[button_event_count] = button_file_cycle;
              button_event_row[button_event_count] = button_file_row;
              button_event_col[button_event_count] = button_file_col;
              button_event_count = button_event_count + 1;
            end
          end
        end
        $fclose(button_file_fd);
        $display("[TB] loaded %0d button events from %0s", button_event_count, button_file_path);
      end else if ($value$plusargs("keys=%s", key_file_path)) begin
        key_file_fd = $fopen(key_file_path, "r");
        if (key_file_fd == 0) begin
          $display("[TB][FAIL] cannot open key events file: %0s", key_file_path);
`ifdef __ICARUS__
          $finish_and_return(1);
`else
          $finish;
`endif
        end
        key_load_done = 0;
        while ((key_event_count < MAX_KEY_EVENTS) && (key_load_done == 0)) begin
          key_scan_rv = $fscanf(key_file_fd, "%d %d %d\n", key_file_cycle, key_file_k1, key_file_k2);
          if (key_scan_rv != 3) begin
            key_load_done = 1;
          end else begin
            if (key_file_cycle < 0) key_file_cycle = 0;
            key_event_cycle[key_event_count] = key_file_cycle;
            key_event_k1[key_event_count] = (key_file_k1 != 0);
            key_event_k2[key_event_count] = (key_file_k2 != 0);
            key_event_count = key_event_count + 1;
          end
        end
        $fclose(key_file_fd);
        $display("[TB] loaded %0d key events from %0s", key_event_count, key_file_path);
      end else begin
        // Default deterministic scenario used by build_and_check.sh.
        key_event_cycle[0] = 200;  key_event_k1[0] = 1'b1; key_event_k2[0] = 1'b0;
        key_event_cycle[1] = 210;  key_event_k1[1] = 1'b0; key_event_k2[1] = 1'b0;
        key_event_cycle[2] = 600;  key_event_k1[2] = 1'b0; key_event_k2[2] = 1'b1;
        key_event_cycle[3] = 612;  key_event_k1[3] = 1'b0; key_event_k2[3] = 1'b0;
        key_event_cycle[4] = 1200; key_event_k1[4] = 1'b1; key_event_k2[4] = 1'b1;
        key_event_cycle[5] = 1210; key_event_k1[5] = 1'b0; key_event_k2[5] = 1'b0;
        key_event_count = 6;
        $display("[TB] using built-in key scenario");
      end

      key_event_idx = 0;
      button_event_idx = 0;
      btnpressed = 0;
    end
  endtask

  task apply_key_events;
    input integer c;
    begin
      while ((key_event_idx < key_event_count) && (key_event_cycle[key_event_idx] == c)) begin
        k1 = key_event_k1[key_event_idx];
        k2 = key_event_k2[key_event_idx];
        key_event_idx = key_event_idx + 1;
      end
    end
  endtask

  task apply_button_events;
    input integer c;
    begin
      // Queue next scheduled button once previous one is consumed by scan logic.
      // Unlike direct "== c" matching, this preserves events that become overdue
      // while a prior key is still pending.
      while ((btnpressed == 0) &&
             (button_event_idx < button_event_count) &&
             (button_event_cycle[button_event_idx] <= c)) begin
        btnpressed = (button_event_row[button_event_idx] << 8) | button_event_col[button_event_idx];
        button_event_idx = button_event_idx + 1;
      end

      k1 = 1'b0;
      k2 = 1'b0;

      // Emu145 keypad scan mapping (row/column->K1/K2),
      // driven once per emu-cycle just before U0 tick (phase==0).
      if (dut.phase == 3'd0) begin
        if (((dut.U0.command & 32'h00FC0000) == 0) && (dut.U0.dcount == 4'd12)) k2 = 1'b1;

        if (btnpressed != 0) begin
        btn_row = btnpressed[9:8];
        btn_col = btnpressed[3:0];
          if (((dut.U0.command & 32'h00FC0000) == 0) && (dut.U0.dcount == (btn_col + 4'd1))) begin
            case (btn_row)
              2'd1: begin k1 = 1'b1; k2 = 1'b0; end
              2'd2: begin k1 = 1'b0; k2 = 1'b1; end
              2'd3: begin k1 = 1'b1; k2 = 1'b1; end
              default: begin k1 = 1'b0; k2 = 1'b0; end
            endcase
            btnpressed = 0;
          end
        end
      end
    end
  endtask

`ifndef YOSYS
  initial begin
    $dumpfile("tb_mk61.vcd");
    $dumpvars(0, tb_mk61);

    sim_cycles = DEFAULT_CYCLES;
    if (!$value$plusargs("cycles=%d", sim_cycles)) sim_cycles = DEFAULT_CYCLES;
    if (sim_cycles <= 0) sim_cycles = DEFAULT_CYCLES;

    mode_sel = 0;
    if ($value$plusargs("mode=%d", mode_sel)) begin
      if (mode_sel < 0) mode_sel = 0;
      if (mode_sel > 2) mode_sel = 2;
    end
    mode = mode_sel[1:0];

    trace_fd = $fopen("rtl_trace.csv", "w");
    if (trace_fd == 0) begin
      $display("[TB][FAIL] cannot open rtl_trace.csv");
`ifdef __ICARUS__
      $finish_and_return(1);
`else
      $finish;
`endif
    end

    $fwrite(trace_fd, "cycle,icount,dcount,ecount,ucount,dcycle,sync,seg,u0_dcycle,u0_sync,u0_seg,phase,k1,k2,cptr,command,ucmd,rl,sigma,carry,dispout,rr0,rm0,rs,rs1,rr144,rr145,rr146,rr147,rr156,rr157,rr158,rr159,m_bit,newm0,ret,cptr1,cmd1,cptr2,cmd2,d1,d2,d3,d4,d5,chain\n");

    load_input_events();

    for (cycle = 0; cycle < RESET_CYCLES; cycle = cycle + 1) begin
      @(posedge clk);
    end
    rst = 1'b0;

    errors = 0;
    sync_count = 0;
    last_sync_cycle = -1;

    for (cycle = 0; cycle < sim_cycles; cycle = cycle + 1) begin
      if (input_mode == INPUT_MODE_BUTTONS) apply_button_events(cycle);
      else apply_key_events(cycle);

      @(posedge clk);
      #1;

      if ((^dcycle === 1'bx) || (syncout === 1'bx) || (^segment === 1'bx)) begin
        errors = errors + 1;
        $display("[TB][ERR] X/Z detected at cycle=%0d dcycle=%b sync=%b segment=%b", cycle, dcycle, syncout, segment);
      end

      if (dcycle > 4'd14) begin
        errors = errors + 1;
        $display("[TB][ERR] dcycle out of range at cycle=%0d dcycle=%0d", cycle, dcycle);
      end

      if (syncout) begin
        sync_count = sync_count + 1;
        if (last_sync_cycle >= 0) begin
          sync_delta = cycle - last_sync_cycle;
          if (sync_delta != SYNC_PERIOD_CYCLES) begin
            errors = errors + 1;
            $display("[TB][ERR] sync period mismatch at cycle=%0d delta=%0d expected=%0d", cycle, sync_delta, SYNC_PERIOD_CYCLES);
          end
        end
        last_sync_cycle = cycle;
      end

      $fwrite(trace_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%02x,%0d,%0d,0x%02x,%0d,%0d,%0d,0x%02x,0x%08x,0x%02x,%0d,%0d,%0d,0x%01x,%0d,%0d,0x%01x,0x%01x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0x%02x,0x%08x,0x%02x,0x%08x,%0d,%0d,%0d,%0d,%0d,%0d\n",
        cycle, dut.U0.icount, dut.U0.dcount, dut.U0.ecount, dut.U0.ucount,
        dcycle, syncout, segment, dut.U0.dcycle, dut.U0.syncout, dut.U0.segment, dut.phase, k1, k2,
        dut.U0.cptr, dut.U0.command, dut.U0.cur_ucmd, dut.U0.rl, dut.U0.sigma, dut.U0.carry,
        dut.U0.dispout, dut.U0.rr[0], dut.U0.rm[0], dut.U0.rs, dut.U0.rs1,
        dut.U0.rr[144], dut.U0.rr[145], dut.U0.rr[146], dut.U0.rr[147],
        dut.U0.rr[156], dut.U0.rr[157], dut.U0.rr[158], dut.U0.rr[159],
        dut.U0.m_bit, dut.U0.newm0, dut.U0.ret_bit,
        dut.U1.cptr, dut.U1.command, dut.U2.cptr, dut.U2.command, dut.d1, dut.d2, dut.d3, dut.d4, dut.d5, dut.chain);
    end

    $fclose(trace_fd);

    if (sync_count == 0) begin
      errors = errors + 1;
      $display("[TB][ERR] no sync pulses observed");
    end

    if (errors != 0) begin
      $display("[TB][FAIL] cycles=%0d sync_count=%0d errors=%0d", sim_cycles, sync_count, errors);
`ifdef __ICARUS__
      $finish_and_return(1);
`else
      $finish;
`endif
    end

    $display("[TB][PASS] cycles=%0d sync_count=%0d errors=%0d", sim_cycles, sync_count, errors);
    $finish;
  end
`else
  initial begin
    // Yosys front-end does not support event controls used by this simulation-only TB.
    $display("[TB] Yosys parse-only stub");
  end
`endif
endmodule
