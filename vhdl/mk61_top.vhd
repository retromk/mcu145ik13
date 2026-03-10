library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mk61_top_vhdl is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    k1      : in  std_logic;
    k2      : in  std_logic;
    mode    : in  std_logic_vector(1 downto 0); -- 0=RAD, 1=DEG, 2=GRD
    dcycle  : out std_logic_vector(3 downto 0);
    syncout : out std_logic;
    segment : out std_logic_vector(7 downto 0);
    dbg_phase      : out std_logic_vector(2 downto 0);
    dbg_u0_dcount  : out std_logic_vector(3 downto 0);
    dbg_u0_command : out std_logic_vector(31 downto 0)
  );
end entity mk61_top_vhdl;

architecture rtl of mk61_top_vhdl is
  signal d0, d1, d2, d3, d4, d5 : std_logic := '0';
  signal phase                  : unsigned(2 downto 0) := (others => '0');
  signal dcount_u1              : std_logic_vector(3 downto 0) := (others => '0');
  signal dcount_u0              : std_logic_vector(3 downto 0) := (others => '0');
  signal command_u0             : std_logic_vector(31 downto 0) := (others => '0');
  signal dcycle_u0              : std_logic_vector(3 downto 0) := (others => '0');
  signal syncout_u0             : std_logic := '0';
  signal segment_u0             : std_logic_vector(7 downto 0) := (others => '0');

  signal chain      : std_logic := '0';
  signal mode_k1_u1 : std_logic := '0';
  signal tick_u0    : std_logic := '0';
  signal tick_u1    : std_logic := '0';
  signal tick_u2    : std_logic := '0';
  signal tick_m0    : std_logic := '0';
  signal tick_m1    : std_logic := '0';
  signal u0_visible : std_logic := '0';
begin
  chain      <= d5;
  d0         <= chain;
  tick_u0    <= '1' when phase = to_unsigned(0, 3) else '0';
  tick_u1    <= '1' when phase = to_unsigned(1, 3) else '0';
  tick_u2    <= '1' when phase = to_unsigned(2, 3) else '0';
  tick_m0    <= '1' when phase = to_unsigned(3, 3) else '0';
  tick_m1    <= '1' when phase = to_unsigned(4, 3) else '0';
  u0_visible <= '1' when phase = to_unsigned(1, 3) else '0';

  dcycle  <= dcycle_u0 when u0_visible = '1' else (others => '0');
  syncout <= syncout_u0 when u0_visible = '1' else '0';
  segment <= segment_u0 when u0_visible = '1' else (others => '0');
  dbg_phase <= std_logic_vector(phase);
  dbg_u0_dcount <= dcount_u0;
  dbg_u0_command <= command_u0;

  mode_k1_u1 <=
    '1' when mode = "00" and dcount_u1 /= "1001" else
    '1' when mode = "01" and dcount_u1 /= "1010" else
    '1' when mode /= "00" and mode /= "01" and dcount_u1 /= "1011" else
    '0';

  process (clk, rst)
  begin
    if rst = '1' then
      phase <= (others => '0');
    elsif rising_edge(clk) then
      if phase = to_unsigned(4, 3) then
        phase <= (others => '0');
      else
        phase <= phase + 1;
      end if;
    end if;
  end process;

  u0 : entity work.mcu145ik13_core_vhdl
    generic map (
      CHIP       => 1302,
      PRETICK_IN => 1
    )
    port map (
      clk     => clk,
      rst     => rst,
      tick_en => tick_u0,
      rin     => d0,
      rout    => d1,
      k1      => k1,
      k2      => k2,
      dcycle  => dcycle_u0,
      syncout => syncout_u0,
      segment => segment_u0,
      icount  => open,
      dcount  => dcount_u0,
      ecount  => open,
      ucount  => open,
      cptr    => open,
      command => command_u0,
      cur_ucmd => open
    );

  u1 : entity work.mcu145ik13_core_vhdl
    generic map (
      CHIP       => 1303,
      PRETICK_IN => 0
    )
    port map (
      clk     => clk,
      rst     => rst,
      tick_en => tick_u1,
      rin     => d1,
      rout    => d2,
      k1      => mode_k1_u1,
      k2      => '0',
      dcycle  => open,
      syncout => open,
      segment => open,
      icount  => open,
      dcount  => dcount_u1,
      ecount  => open,
      ucount  => open,
      cptr    => open,
      command => open,
      cur_ucmd => open
    );

  u2 : entity work.mcu145ik13_core_vhdl
    generic map (
      CHIP       => 1306,
      PRETICK_IN => 0
    )
    port map (
      clk     => clk,
      rst     => rst,
      tick_en => tick_u2,
      rin     => d2,
      rout    => d3,
      k1      => '0',
      k2      => '0',
      dcycle  => open,
      syncout => open,
      segment => open,
      icount  => open,
      dcount  => open,
      ecount  => open,
      ucount  => open,
      cptr    => open,
      command => open,
      cur_ucmd => open
    );

  m0 : entity work.cmem_shift_vhdl
    generic map (
      LEN => 1008
    )
    port map (
      clk     => clk,
      rst     => rst,
      tick_en => tick_m0,
      in_bit  => d3,
      out_bit => d4
    );

  m1 : entity work.cmem_shift_vhdl
    generic map (
      LEN => 1008
    )
    port map (
      clk     => clk,
      rst     => rst,
      tick_en => tick_m1,
      in_bit  => d4,
      out_bit => d5
    );
end architecture rtl;
