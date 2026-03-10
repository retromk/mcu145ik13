library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_mk61_vhdl is
  generic (
    G_SIM_CYCLES : integer := 20000;
    G_MODE       : integer := 0;
    G_USE_EXTERNAL_EVENTS : integer := 0
  );
end entity tb_mk61_vhdl;

architecture sim of tb_mk61_vhdl is
  constant CLK_HALF_PERIOD_NS : time := 5 ns;
  constant RESET_CYCLES       : integer := 8;

  constant MAX_KEY_EVENTS    : integer := 4096;
  constant MAX_BUTTON_EVENTS : integer := 4096;

  constant INPUT_MODE_KEYS    : integer := 0;
  constant INPUT_MODE_BUTTONS : integer := 1;

  function mode_to_slv(v : integer) return std_logic_vector is
  begin
    case v is
      when 0 =>
        return "00";
      when 1 =>
        return "01";
      when 2 =>
        return "10";
      when others =>
        return "00";
    end case;
  end function;

  function is_display_window(cmd : std_logic_vector(31 downto 0)) return boolean is
  begin
    return (unsigned(cmd) and to_unsigned(16#00FC0000#, 32)) = to_unsigned(0, 32);
  end function;

  type int_arr is array (natural range <>) of integer;
  type sl_arr is array (natural range <>) of std_logic;

  constant DEFAULT_EVENT_CYCLE : int_arr(0 to 5) := (200, 210, 600, 612, 1200, 1210);
  constant DEFAULT_EVENT_K1    : sl_arr(0 to 5) := ('1', '0', '0', '0', '1', '0');
  constant DEFAULT_EVENT_K2    : sl_arr(0 to 5) := ('0', '0', '1', '0', '1', '0');

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal k1      : std_logic := '0';
  signal k2      : std_logic := '0';
  signal mode    : std_logic_vector(1 downto 0) := "00";
  signal dcycle  : std_logic_vector(3 downto 0) := (others => '0');
  signal syncout : std_logic := '0';
  signal segment : std_logic_vector(7 downto 0) := (others => '0');

  signal dbg_phase      : std_logic_vector(2 downto 0) := (others => '0');
  signal dbg_u0_dcount  : std_logic_vector(3 downto 0) := (others => '0');
  signal dbg_u0_command : std_logic_vector(31 downto 0) := (others => '0');
begin
  clk <= not clk after CLK_HALF_PERIOD_NS;

  dut : entity work.mk61_top_vhdl
    port map (
      clk     => clk,
      rst     => rst,
      k1      => k1,
      k2      => k2,
      mode    => mode,
      dcycle  => dcycle,
      syncout => syncout,
      segment => segment,
      dbg_phase => dbg_phase,
      dbg_u0_dcount => dbg_u0_dcount,
      dbg_u0_command => dbg_u0_command
    );

  stim : process
    file trace_fd : text open write_mode is "rtl_trace_vhdl.csv";
    file key_fd : text;
    file button_fd : text;

    variable key_cycle : int_arr(0 to MAX_KEY_EVENTS - 1);
    variable key_k1 : sl_arr(0 to MAX_KEY_EVENTS - 1);
    variable key_k2 : sl_arr(0 to MAX_KEY_EVENTS - 1);
    variable key_count : integer := 0;
    variable key_idx : integer := 0;

    variable button_cycle : int_arr(0 to MAX_BUTTON_EVENTS - 1);
    variable button_row : int_arr(0 to MAX_BUTTON_EVENTS - 1);
    variable button_col : int_arr(0 to MAX_BUTTON_EVENTS - 1);
    variable button_count : integer := 0;
    variable button_idx : integer := 0;

    variable input_mode : integer := INPUT_MODE_KEYS;
    variable btnpressed_row : integer := 0;
    variable btnpressed_col : integer := 0;

    variable line_v : line;
    variable parse_line : line;
    variable st : file_open_status;
    variable ok : boolean;
    variable v0, v1, v2 : integer;
  begin
    write(line_v, string'("cycle,dcycle,sync,seg,k1,k2"));
    writeline(trace_fd, line_v);

    input_mode := INPUT_MODE_KEYS;

    if G_USE_EXTERNAL_EVENTS /= 0 then
      file_open(st, button_fd, "logs/virtual_buttons.txt", read_mode);
      if st = open_ok then
        while not endfile(button_fd) loop
          readline(button_fd, parse_line);
          read(parse_line, v0, ok);
          if not ok then
            next;
          end if;
          read(parse_line, v1, ok);
          if not ok then
            next;
          end if;
          read(parse_line, v2, ok);
          if not ok then
            next;
          end if;

          if button_count < MAX_BUTTON_EVENTS then
            if v0 < 0 then
              v0 := 0;
            end if;
            if (v1 >= 1) and (v1 <= 3) and (v2 >= 0) and (v2 <= 9) then
              button_cycle(button_count) := v0;
              button_row(button_count) := v1;
              button_col(button_count) := v2;
              button_count := button_count + 1;
            end if;
          end if;
        end loop;
        file_close(button_fd);
      end if;

      if button_count > 0 then
        input_mode := INPUT_MODE_BUTTONS;
        report "tb_mk61_vhdl: loaded button events=" & integer'image(button_count) severity note;
      else
        file_open(st, key_fd, "logs/virtual_keys.txt", read_mode);
        if st = open_ok then
          while not endfile(key_fd) loop
            readline(key_fd, parse_line);
            read(parse_line, v0, ok);
            if not ok then
              next;
            end if;
            read(parse_line, v1, ok);
            if not ok then
              next;
            end if;
            read(parse_line, v2, ok);
            if not ok then
              next;
            end if;

            if key_count < MAX_KEY_EVENTS then
              if v0 < 0 then
                v0 := 0;
              end if;
              key_cycle(key_count) := v0;
              key_k1(key_count) := '1' when v1 /= 0 else '0';
              key_k2(key_count) := '1' when v2 /= 0 else '0';
              key_count := key_count + 1;
            end if;
          end loop;
          file_close(key_fd);
        end if;
      end if;
    end if;

    if (input_mode = INPUT_MODE_BUTTONS) then
      null;
    elsif key_count > 0 then
      input_mode := INPUT_MODE_KEYS;
      report "tb_mk61_vhdl: loaded key events=" & integer'image(key_count) severity note;
    else
      for i in 0 to DEFAULT_EVENT_CYCLE'high loop
        key_cycle(i) := DEFAULT_EVENT_CYCLE(i);
        key_k1(i) := DEFAULT_EVENT_K1(i);
        key_k2(i) := DEFAULT_EVENT_K2(i);
      end loop;
      key_count := DEFAULT_EVENT_CYCLE'length;
      input_mode := INPUT_MODE_KEYS;
      report "tb_mk61_vhdl: using built-in key scenario" severity note;
    end if;

    mode <= mode_to_slv(G_MODE);
    rst <= '1';
    k1 <= '0';
    k2 <= '0';

    for i in 0 to RESET_CYCLES - 1 loop
      wait until rising_edge(clk);
      wait for 1 ns;
    end loop;
    rst <= '0';

    for cyc in 0 to G_SIM_CYCLES - 1 loop
      if input_mode = INPUT_MODE_BUTTONS then
        while (btnpressed_row = 0) and (button_idx < button_count) and (button_cycle(button_idx) <= cyc) loop
          btnpressed_row := button_row(button_idx);
          btnpressed_col := button_col(button_idx);
          button_idx := button_idx + 1;
        end loop;

        k1 <= '0';
        k2 <= '0';

        if dbg_phase = "000" then
          if is_display_window(dbg_u0_command) and (unsigned(dbg_u0_dcount) = to_unsigned(12, 4)) then
            k2 <= '1';
          end if;

          if btnpressed_row /= 0 then
            if is_display_window(dbg_u0_command) and
               (unsigned(dbg_u0_dcount) = to_unsigned(btnpressed_col + 1, 4)) then
              case btnpressed_row is
                when 1 =>
                  k1 <= '1';
                  k2 <= '0';
                when 2 =>
                  k1 <= '0';
                  k2 <= '1';
                when 3 =>
                  k1 <= '1';
                  k2 <= '1';
                when others =>
                  k1 <= '0';
                  k2 <= '0';
              end case;
              btnpressed_row := 0;
              btnpressed_col := 0;
            end if;
          end if;
        end if;
      else
        while (key_idx < key_count) and (key_cycle(key_idx) = cyc) loop
          k1 <= key_k1(key_idx);
          k2 <= key_k2(key_idx);
          key_idx := key_idx + 1;
        end loop;
      end if;

      wait until rising_edge(clk);
      wait for 1 ns;

      write(line_v, integer'image(cyc));
      write(line_v, string'(","));
      write(line_v, integer'image(to_integer(unsigned(dcycle))));
      write(line_v, string'(","));
      if syncout = '1' then
        write(line_v, integer'image(1));
      else
        write(line_v, integer'image(0));
      end if;
      write(line_v, string'(","));
      write(line_v, integer'image(to_integer(unsigned(segment))));
      write(line_v, string'(","));
      if k1 = '1' then
        write(line_v, integer'image(1));
      else
        write(line_v, integer'image(0));
      end if;
      write(line_v, string'(","));
      if k2 = '1' then
        write(line_v, integer'image(1));
      else
        write(line_v, integer'image(0));
      end if;
      writeline(trace_fd, line_v);
    end loop;

    report "tb_mk61_vhdl finished" severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
