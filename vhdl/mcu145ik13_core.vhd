library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mcu145ik13_core_vhdl is
  generic (
    CHIP       : integer := 1302;
    PRETICK_IN : integer := 0
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    tick_en  : in  std_logic;
    rin      : in  std_logic;
    rout     : out std_logic;
    k1       : in  std_logic;
    k2       : in  std_logic;
    dcycle   : out std_logic_vector(3 downto 0);
    syncout  : out std_logic;
    segment  : out std_logic_vector(7 downto 0);
    icount   : out std_logic_vector(5 downto 0);
    dcount   : out std_logic_vector(3 downto 0);
    ecount   : out std_logic_vector(1 downto 0);
    ucount   : out std_logic_vector(1 downto 0);
    cptr     : out std_logic_vector(7 downto 0);
    command  : out std_logic_vector(31 downto 0);
    cur_ucmd : out std_logic_vector(6 downto 0)
  );
end entity mcu145ik13_core_vhdl;

architecture rtl of mcu145ik13_core_vhdl is
  constant MCU_BITLEN : integer := 168;
  constant CONST_10   : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(10, 4));
  constant CONST_6    : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(6, 4));
  constant CONST_4    : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(4, 4));
  constant CONST_1    : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(1, 4));

  function boot_command_value(chip_id : integer) return std_logic_vector is
  begin
    case chip_id is
      when 1302 =>
        return x"00204E4E";
      when 1303 =>
        return x"00386050";
      when 1306 =>
        return x"00070000";
      when others =>
        return x"00000000";
    end case;
  end function;

  constant BOOT_COMMAND_C : std_logic_vector(31 downto 0) := boot_command_value(CHIP);

  function slv_to_unsigned01(slv : std_logic_vector) return unsigned is
    variable u : unsigned(slv'range);
  begin
    for i in slv'range loop
      if slv(i) = '1' then
        u(i) := '1';
      else
        u(i) := '0';
      end if;
    end loop;
    return u;
  end function;

  function u_to_integer01(u : unsigned) return integer is
  begin
    return to_integer(slv_to_unsigned01(std_logic_vector(u)));
  end function;

  component ik13_urom is
    generic (
      CHIP : integer := 1302
    );
    port (
      addr : in  std_logic_vector(6 downto 0);
      dout : out std_logic_vector(31 downto 0)
    );
  end component;

  component ik13_srom is
    generic (
      CHIP : integer := 1302
    );
    port (
      addr : in  std_logic_vector(6 downto 0);
      col0 : out std_logic_vector(7 downto 0);
      col1 : out std_logic_vector(7 downto 0);
      col2 : out std_logic_vector(7 downto 0);
      col3 : out std_logic_vector(7 downto 0);
      col4 : out std_logic_vector(7 downto 0);
      col5 : out std_logic_vector(7 downto 0);
      col6 : out std_logic_vector(7 downto 0);
      col7 : out std_logic_vector(7 downto 0);
      col8 : out std_logic_vector(7 downto 0)
    );
  end component;

  component ik13_mrom is
    generic (
      CHIP : integer := 1302
    );
    port (
      addr : in  std_logic_vector(7 downto 0);
      dout : out std_logic_vector(31 downto 0)
    );
  end component;

  function jrom_idx(i : unsigned(5 downto 0)) return unsigned is
    variable idx : unsigned(3 downto 0);
  begin
    case u_to_integer01(i) is
      when 0  => idx := to_unsigned(0, 4);
      when 1  => idx := to_unsigned(1, 4);
      when 2  => idx := to_unsigned(2, 4);
      when 3  => idx := to_unsigned(3, 4);
      when 4  => idx := to_unsigned(4, 4);
      when 5  => idx := to_unsigned(5, 4);
      when 6  => idx := to_unsigned(3, 4);
      when 7  => idx := to_unsigned(4, 4);
      when 8  => idx := to_unsigned(5, 4);
      when 9  => idx := to_unsigned(3, 4);
      when 10 => idx := to_unsigned(4, 4);
      when 11 => idx := to_unsigned(5, 4);
      when 12 => idx := to_unsigned(3, 4);
      when 13 => idx := to_unsigned(4, 4);
      when 14 => idx := to_unsigned(5, 4);
      when 15 => idx := to_unsigned(3, 4);
      when 16 => idx := to_unsigned(4, 4);
      when 17 => idx := to_unsigned(5, 4);
      when 18 => idx := to_unsigned(3, 4);
      when 19 => idx := to_unsigned(4, 4);
      when 20 => idx := to_unsigned(5, 4);
      when 21 => idx := to_unsigned(3, 4);
      when 22 => idx := to_unsigned(4, 4);
      when 23 => idx := to_unsigned(5, 4);
      when 24 => idx := to_unsigned(6, 4);
      when 25 => idx := to_unsigned(7, 4);
      when 26 => idx := to_unsigned(8, 4);
      when 27 => idx := to_unsigned(0, 4);
      when 28 => idx := to_unsigned(1, 4);
      when 29 => idx := to_unsigned(2, 4);
      when 30 => idx := to_unsigned(3, 4);
      when 31 => idx := to_unsigned(4, 4);
      when 32 => idx := to_unsigned(5, 4);
      when 33 => idx := to_unsigned(6, 4);
      when 34 => idx := to_unsigned(7, 4);
      when 35 => idx := to_unsigned(8, 4);
      when 36 => idx := to_unsigned(0, 4);
      when 37 => idx := to_unsigned(1, 4);
      when 38 => idx := to_unsigned(2, 4);
      when 39 => idx := to_unsigned(3, 4);
      when 40 => idx := to_unsigned(4, 4);
      when 41 => idx := to_unsigned(5, 4);
      when others => idx := to_unsigned(0, 4);
    end case;
    return idx;
  end function;

  signal rr     : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');
  signal rm     : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');
  signal rstreg : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');

  signal rs      : std_logic_vector(3 downto 0) := (others => '0');
  signal rs1     : std_logic_vector(3 downto 0) := (others => '0');
  signal rh      : std_logic_vector(3 downto 0) := (others => '0');
  signal dispout : std_logic_vector(3 downto 0) := (others => '0');

  signal sigma      : std_logic := '0';
  signal carry      : std_logic := '0';
  signal rl         : std_logic := '0';
  signal rt         : std_logic := '0';
  signal was_t_qrd  : std_logic := '0';
  signal latchk1    : std_logic := '0';
  signal latchk2    : std_logic := '0';
  signal asp        : unsigned(6 downto 0) := (others => '0');

  signal icount_r   : unsigned(5 downto 0) := (others => '0');
  signal dcount_r   : unsigned(3 downto 0) := (others => '0');
  signal ecount_r   : unsigned(1 downto 0) := (others => '0');
  signal ucount_r   : unsigned(1 downto 0) := (others => '0');
  signal cptr_r     : unsigned(7 downto 0) := (others => '0');
  signal command_r  : std_logic_vector(31 downto 0) := BOOT_COMMAND_C;
  signal cur_ucmd_r : unsigned(6 downto 0) := (others => '0');

  signal dcycle_r  : unsigned(3 downto 0) := (others => '0');
  signal syncout_r : std_logic := '0';
  signal segment_r : std_logic_vector(7 downto 0) := (others => '0');
  signal rout_reg  : std_logic := '0';

  signal rr_n      : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');
  signal rm_n      : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');
  signal rst_n     : std_logic_vector(MCU_BITLEN - 1 downto 0) := (others => '0');
  signal rs_n      : std_logic_vector(3 downto 0) := (others => '0');
  signal rs1_n     : std_logic_vector(3 downto 0) := (others => '0');
  signal rh_n      : std_logic_vector(3 downto 0) := (others => '0');
  signal dispout_n : std_logic_vector(3 downto 0) := (others => '0');

  signal sigma_n      : std_logic := '0';
  signal carry_n      : std_logic := '0';
  signal rl_n         : std_logic := '0';
  signal rt_n         : std_logic := '0';
  signal was_t_qrd_n  : std_logic := '0';
  signal latchk1_n    : std_logic := '0';
  signal latchk2_n    : std_logic := '0';
  signal asp_next     : unsigned(6 downto 0) := (others => '0');

  signal icount_n   : unsigned(5 downto 0) := (others => '0');
  signal dcount_n   : unsigned(3 downto 0) := (others => '0');
  signal ecount_n   : unsigned(1 downto 0) := (others => '0');
  signal ucount_n   : unsigned(1 downto 0) := (others => '0');
  signal cptr_n     : unsigned(7 downto 0) := (others => '0');
  signal command_n  : std_logic_vector(31 downto 0) := (others => '0');
  signal cur_ucmd_n : unsigned(6 downto 0) := (others => '0');

  signal dcycle_n  : unsigned(3 downto 0) := (others => '0');
  signal syncout_n : std_logic := '0';
  signal segment_n : std_logic_vector(7 downto 0) := (others => '0');
  signal ret_bit   : std_logic := '0';

  signal urom_word      : std_logic_vector(31 downto 0);
  signal mrom_word_next : std_logic_vector(31 downto 0);
  signal s0, s1, s2, s3, s4, s5, s6, s7, s8 : std_logic_vector(7 downto 0);

  signal asp_lookup_s   : std_logic_vector(6 downto 0) := (others => '0');
  signal asp_dec_s      : unsigned(6 downto 0) := (others => '0');
  signal cur_ucmd_dec_s : unsigned(6 downto 0) := (others => '0');
  signal spw_dec_s      : std_logic := '0';
  signal sp_rr1_dec_s   : std_logic := '0';
  signal sp_rr4_dec_s   : std_logic := '0';

  signal a_r_s    : std_logic := '0';
  signal a_m_s    : std_logic := '0';
  signal a_st_s   : std_logic := '0';
  signal a_nr_s   : std_logic := '0';
  signal a_10nl_s : std_logic := '0';
  signal a_s_s    : std_logic := '0';
  signal a_4_s    : std_logic := '0';

  signal b_s_s    : std_logic := '0';
  signal b_ns_s   : std_logic := '0';
  signal b_s1_s   : std_logic := '0';
  signal b_6_s    : std_logic := '0';
  signal b_1_s    : std_logic := '0';

  signal g_l_s    : std_logic := '0';
  signal g_nl_s   : std_logic := '0';
  signal g_nt_s   : std_logic := '0';

  signal r0_s     : std_logic_vector(2 downto 0) := (others => '0');
  signal r_1_s    : std_logic := '0';
  signal r_2_s    : std_logic := '0';
  signal m_bit_s  : std_logic := '0';
  signal l_bit_s  : std_logic := '0';

  signal s_op_s   : std_logic_vector(1 downto 0) := (others => '0');
  signal s1_op_s  : std_logic_vector(1 downto 0) := (others => '0');
  signal st_op_s  : std_logic_vector(1 downto 0) := (others => '0');
begin
  rout    <= rout_reg;
  dcycle  <= std_logic_vector(dcycle_r);
  syncout <= syncout_r;
  segment <= segment_r;

  icount  <= std_logic_vector(icount_r);
  dcount  <= std_logic_vector(dcount_r);
  ecount  <= std_logic_vector(ecount_r);
  ucount  <= std_logic_vector(ucount_r);
  cptr    <= std_logic_vector(cptr_r);
  command <= command_r;
  cur_ucmd <= std_logic_vector(cur_ucmd_r);

  urom_i : ik13_urom
    generic map (
      CHIP => CHIP
    )
    port map (
      addr => std_logic_vector(cur_ucmd_dec_s),
      dout => urom_word
    );

  asp_lookup_s <= command_r(6 downto 0) when icount_r < to_unsigned(27, 6) else
                  command_r(14 downto 8) when icount_r < to_unsigned(36, 6) else
                  "1011111" when slv_to_unsigned01(command_r(23 downto 16)) >= to_unsigned(16#20#, 8) else
                  '0' & command_r(21 downto 16);

  srom_i : ik13_srom
    generic map (
      CHIP => CHIP
    )
    port map (
      addr => asp_lookup_s,
      col0 => s0,
      col1 => s1,
      col2 => s2,
      col3 => s3,
      col4 => s4,
      col5 => s5,
      col6 => s6,
      col7 => s7,
      col8 => s8
    );

  mrom_next_i : ik13_mrom
    generic map (
      CHIP => CHIP
    )
    port map (
      addr => std_logic_vector(cptr_n),
      dout => mrom_word_next
    );

  a_r_s    <= urom_word(0);
  a_m_s    <= urom_word(1);
  a_st_s   <= urom_word(2);
  a_nr_s   <= urom_word(3);
  a_10nl_s <= urom_word(4);
  a_s_s    <= urom_word(5);
  a_4_s    <= urom_word(6);

  b_s_s    <= urom_word(7);
  b_ns_s   <= urom_word(8);
  b_s1_s   <= urom_word(9);
  b_6_s    <= urom_word(10);
  b_1_s    <= urom_word(11);

  g_l_s    <= urom_word(12);
  g_nl_s   <= urom_word(13);
  g_nt_s   <= urom_word(14);

  r0_s     <= urom_word(17 downto 15);
  r_1_s    <= urom_word(18);
  r_2_s    <= urom_word(19);
  m_bit_s  <= urom_word(20);
  l_bit_s  <= urom_word(21);

  s_op_s   <= urom_word(23 downto 22);
  s1_op_s  <= urom_word(25 downto 24);
  st_op_s  <= urom_word(27 downto 26);

  decode_proc : process (all)
    variable jidx_v     : unsigned(3 downto 0);
    variable ucmd_raw_v : unsigned(7 downto 0);
    variable asp_dec_v  : unsigned(6 downto 0);
    variable cur_ucmd_v : unsigned(6 downto 0);
    variable spw_v      : std_logic;
    variable sp_rr1_v   : std_logic;
    variable sp_rr4_v   : std_logic;
  begin
    asp_dec_v  := (others => '0');
    cur_ucmd_v := (others => '0');
    spw_v      := '0';
    sp_rr1_v   := '0';
    sp_rr4_v   := '0';
    ucmd_raw_v := (others => '0');

    jidx_v := jrom_idx(icount_r);

    if icount_r < to_unsigned(27, 6) then
      asp_dec_v := unsigned(command_r(6 downto 0));
    elsif icount_r < to_unsigned(36, 6) then
      asp_dec_v := unsigned(command_r(14 downto 8));
    else
      if slv_to_unsigned01(command_r(23 downto 16)) >= to_unsigned(16#20#, 8) then
        if icount_r = to_unsigned(36, 6) then
          spw_v := '1';
          sp_rr1_v := command_r(16 + to_integer(ucount_r));
          sp_rr4_v := command_r(20 + to_integer(ucount_r));
        end if;
        asp_dec_v := to_unsigned(16#5F#, 7);
      else
        asp_dec_v := unsigned('0' & command_r(21 downto 16));
      end if;
    end if;

    case to_integer(jidx_v) is
      when 0      => ucmd_raw_v := slv_to_unsigned01(s0);
      when 1      => ucmd_raw_v := slv_to_unsigned01(s1);
      when 2      => ucmd_raw_v := slv_to_unsigned01(s2);
      when 3      => ucmd_raw_v := slv_to_unsigned01(s3);
      when 4      => ucmd_raw_v := slv_to_unsigned01(s4);
      when 5      => ucmd_raw_v := slv_to_unsigned01(s5);
      when 6      => ucmd_raw_v := slv_to_unsigned01(s6);
      when 7      => ucmd_raw_v := slv_to_unsigned01(s7);
      when others => ucmd_raw_v := slv_to_unsigned01(s8);
    end case;

    ucmd_raw_v := ucmd_raw_v and to_unsigned(16#3F#, 8);
    if ucmd_raw_v > to_unsigned(16#3B#, 8) then
      ucmd_raw_v := (ucmd_raw_v - to_unsigned(16#3C#, 8)) sll 1;
      if rl = '0' then
        ucmd_raw_v := ucmd_raw_v + 1;
      end if;
      ucmd_raw_v := ucmd_raw_v + to_unsigned(16#3C#, 8);
    end if;
    cur_ucmd_v := ucmd_raw_v(6 downto 0);

    asp_dec_s      <= asp_dec_v;
    cur_ucmd_dec_s <= cur_ucmd_v;
    spw_dec_s      <= spw_v;
    sp_rr1_dec_s   <= sp_rr1_v;
    sp_rr4_dec_s   <= sp_rr4_v;
  end process;

  tick_comb : process (all)
    variable rr_n_v      : std_logic_vector(MCU_BITLEN - 1 downto 0);
    variable rm_n_v      : std_logic_vector(MCU_BITLEN - 1 downto 0);
    variable rst_n_v     : std_logic_vector(MCU_BITLEN - 1 downto 0);
    variable rs_n_v      : std_logic_vector(3 downto 0);
    variable rs1_n_v     : std_logic_vector(3 downto 0);
    variable rh_n_v      : std_logic_vector(3 downto 0);
    variable dispout_n_v : std_logic_vector(3 downto 0);

    variable sigma_n_v      : std_logic;
    variable carry_n_v      : std_logic;
    variable rl_n_v         : std_logic;
    variable rt_n_v         : std_logic;
    variable was_t_qrd_n_v  : std_logic;
    variable latchk1_n_v    : std_logic;
    variable latchk2_n_v    : std_logic;
    variable asp_next_v     : unsigned(6 downto 0);

    variable icount_n_v   : unsigned(5 downto 0);
    variable dcount_n_v   : unsigned(3 downto 0);
    variable ecount_n_v   : unsigned(1 downto 0);
    variable ucount_n_v   : unsigned(1 downto 0);
    variable cptr_n_v     : unsigned(7 downto 0);
    variable command_n_v  : std_logic_vector(31 downto 0);
    variable cur_ucmd_n_v : unsigned(6 downto 0);

    variable dcycle_n_v  : unsigned(3 downto 0);
    variable syncout_n_v : std_logic;
    variable segment_n_v : std_logic_vector(7 downto 0);
    variable ret_bit_v   : std_logic;

    variable keybits_now_v     : std_logic_vector(3 downto 0);
    variable keybits_latched_v : std_logic_vector(3 downto 0);

    variable newm0_v  : std_logic;
    variable newr0_v  : std_logic;
    variable a_v      : std_logic;
    variable b_v      : std_logic;
    variable g_v      : std_logic;
    variable x_v      : std_logic;
    variable y_v      : std_logic;
    variable z_v      : std_logic;
    variable temp_v   : std_logic;
    variable sum_i    : integer range 0 to 3;
    variable cptr_hi_v : unsigned(7 downto 0);
    variable seg_low_v : unsigned(7 downto 0);

  begin
    rr_n_v      := rr;
    rm_n_v      := rm;
    rst_n_v     := rstreg;
    rs_n_v      := rs;
    rs1_n_v     := rs1;
    rh_n_v      := rh;
    dispout_n_v := dispout;

    sigma_n_v      := sigma;
    carry_n_v      := carry;
    rl_n_v         := rl;
    rt_n_v         := rt;
    was_t_qrd_n_v  := was_t_qrd;
    latchk1_n_v    := latchk1;
    latchk2_n_v    := latchk2;

    icount_n_v   := icount_r;
    dcount_n_v   := dcount_r;
    ecount_n_v   := ecount_r;
    ucount_n_v   := ucount_r;
    cptr_n_v     := cptr_r;
    command_n_v  := command_r;
    cur_ucmd_n_v := cur_ucmd_r;

    dcycle_n_v  := (others => '0');
    syncout_n_v := '0';
    segment_n_v := (others => '0');
    ret_bit_v   := '0';

    keybits_now_v     := k2 & "00" & k1;
    keybits_latched_v := latchk2_n_v & "00" & latchk1_n_v;

    if PRETICK_IN /= 0 then
      rm_n_v(MCU_BITLEN - 1) := rin;
    end if;

    command_n_v  := command_r;
    asp_next_v   := asp_dec_s;
    cur_ucmd_n_v := cur_ucmd_dec_s;

    if spw_dec_s = '1' then
      rr_n_v(4)  := sp_rr1_dec_s;
      rr_n_v(16) := sp_rr4_dec_s;
    end if;

    case s1_op_s is
      when "10" | "11" =>
        rh_n_v(0)  := keybits_now_v(to_integer(ucount_r));
        rs1_n_v(0) := rs1_n_v(0) or rh_n_v(0);
      when others =>
        null;
    end case;

    if (k1 = '1') or (k2 = '1') then
      latchk1_n_v := k1;
      latchk2_n_v := k2;
    end if;
    keybits_latched_v := latchk2_n_v & "00" & latchk1_n_v;

    if g_nt_s = '1' then
      was_t_qrd_n_v := '1';
    end if;

    if (latchk1_n_v = '1') or (latchk2_n_v = '1') then
      rt_n_v := '1';
    else
      rt_n_v := '0';
    end if;

    if (g_nt_s = '1') or (was_t_qrd_n_v = '1') then
      rs1_n_v(0) := keybits_latched_v(to_integer(ucount_r));
    end if;

    a_v := '0';
    b_v := '0';
    g_v := '0';

    if a_r_s = '1' then
      a_v := a_v or rr_n_v(0);
    end if;
    if a_m_s = '1' then
      a_v := a_v or rm_n_v(0);
    end if;
    if a_st_s = '1' then
      a_v := a_v or rst_n_v(0);
    end if;
    if a_nr_s = '1' then
      a_v := a_v or (not rr_n_v(0));
    end if;
    if a_10nl_s = '1' then
      a_v := a_v or (CONST_10(to_integer(ucount_r)) and (not rl_n_v));
    end if;
    if a_s_s = '1' then
      a_v := a_v or rs_n_v(0);
    end if;
    if a_4_s = '1' then
      a_v := a_v or CONST_4(to_integer(ucount_r));
    end if;

    if b_1_s = '1' then
      b_v := b_v or CONST_1(to_integer(ucount_r));
    end if;
    if b_6_s = '1' then
      b_v := b_v or CONST_6(to_integer(ucount_r));
    end if;
    if b_s_s = '1' then
      b_v := b_v or rs_n_v(0);
    end if;
    if b_s1_s = '1' then
      b_v := b_v or rs1_n_v(0);
    end if;
    if b_ns_s = '1' then
      b_v := b_v or (not rs_n_v(0));
    end if;

    if g_l_s = '1' then
      g_v := g_v or rl_n_v;
    end if;
    if g_nl_s = '1' then
      g_v := g_v or (not rl_n_v);
    end if;
    if g_nt_s = '1' then
      g_v := g_v or (not rt_n_v);
    end if;

    if ucount_r /= to_unsigned(0, 2) then
      g_v := carry_n_v;
    end if;

    sum_i := 0;
    if a_v = '1' then
      sum_i := sum_i + 1;
    end if;
    if b_v = '1' then
      sum_i := sum_i + 1;
    end if;
    if g_v = '1' then
      sum_i := sum_i + 1;
    end if;

    if (sum_i mod 2) = 1 then
      sigma_n_v := '1';
    else
      sigma_n_v := '0';
    end if;

    if sum_i >= 2 then
      carry_n_v := '1';
    else
      carry_n_v := '0';
    end if;

    case u_to_integer01(slv_to_unsigned01(r0_s)) is
      when 0 => newr0_v := rr_n_v(0);
      when 1 => newr0_v := rr_n_v(12);
      when 2 => newr0_v := sigma_n_v;
      when 3 => newr0_v := rs_n_v(0);
      when 4 => newr0_v := rr_n_v(0) or rs_n_v(0) or sigma_n_v;
      when 5 => newr0_v := rs_n_v(0) or sigma_n_v;
      when 6 => newr0_v := rr_n_v(0) or rs_n_v(0);
      when others => newr0_v := rr_n_v(0) or sigma_n_v;
    end case;

    if r_1_s = '1' then
      if icount_r < to_unsigned(36, 6) then
        if (command_r and x"FF000000") = x"00000000" then
          rr_n_v(MCU_BITLEN - 4) := sigma_n_v;
        end if;
      else
        rr_n_v(MCU_BITLEN - 4) := sigma_n_v;
      end if;
    end if;

    if r_2_s = '1' then
      if icount_r < to_unsigned(36, 6) then
        if (command_r and x"FF000000") = x"00000000" then
          rr_n_v(MCU_BITLEN - 8) := sigma_n_v;
        end if;
      else
        rr_n_v(MCU_BITLEN - 8) := sigma_n_v;
      end if;
    end if;

    if (l_bit_s = '1') and (ucount_r = to_unsigned(3, 2)) then
      rl_n_v := carry_n_v;
    end if;

    if m_bit_s = '1' then
      newm0_v := rs_n_v(0);
    else
      newm0_v := rm_n_v(0);
    end if;

    case s_op_s is
      when "00" =>
        temp_v    := rs_n_v(0);
        rs_n_v(0) := rs_n_v(1);
        rs_n_v(1) := rs_n_v(2);
        rs_n_v(2) := rs_n_v(3);
        rs_n_v(3) := temp_v;
      when "01" =>
        rs_n_v(0) := rs_n_v(1);
        rs_n_v(1) := rs_n_v(2);
        rs_n_v(2) := rs_n_v(3);
        rs_n_v(3) := rs1_n_v(0);
      when "10" =>
        rs_n_v(0) := rs_n_v(1);
        rs_n_v(1) := rs_n_v(2);
        rs_n_v(2) := rs_n_v(3);
        rs_n_v(3) := sigma_n_v;
      when others =>
        temp_v     := rs1_n_v(0);
        rs1_n_v(0) := rs1_n_v(1);
        rs1_n_v(1) := rs1_n_v(2);
        rs1_n_v(2) := rs1_n_v(3);
        rs1_n_v(3) := sigma_n_v or temp_v;
    end case;

    case s1_op_s is
      when "00" =>
        temp_v     := rs1_n_v(0);
        rs1_n_v(0) := rs1_n_v(1);
        rs1_n_v(1) := rs1_n_v(2);
        rs1_n_v(2) := rs1_n_v(3);
        rs1_n_v(3) := temp_v;
      when "01" =>
        rs1_n_v(0) := rs1_n_v(1);
        rs1_n_v(1) := rs1_n_v(2);
        rs1_n_v(2) := rs1_n_v(3);
        rs1_n_v(3) := sigma_n_v;
      when "10" =>
        temp_v     := rs1_n_v(0);
        rs1_n_v(0) := rs1_n_v(1);
        rs1_n_v(1) := rs1_n_v(2);
        rs1_n_v(2) := rs1_n_v(3);
        rs1_n_v(3) := temp_v;
      when others =>
        temp_v     := rs1_n_v(0);
        rs1_n_v(0) := rs1_n_v(1);
        rs1_n_v(1) := rs1_n_v(2);
        rs1_n_v(2) := rs1_n_v(3);
        rs1_n_v(3) := temp_v or sigma_n_v;
    end case;

    case st_op_s is
      when "01" =>
        rst_n_v(8) := rst_n_v(4);
        rst_n_v(4) := rst_n_v(0);
        rst_n_v(0) := sigma_n_v;
      when "10" =>
        temp_v     := rst_n_v(0);
        rst_n_v(0) := rst_n_v(4);
        rst_n_v(4) := rst_n_v(8);
        rst_n_v(8) := temp_v;
      when "11" =>
        x_v := rst_n_v(0);
        y_v := rst_n_v(4);
        z_v := rst_n_v(8);
        rst_n_v(0) := sigma_n_v or y_v;
        rst_n_v(4) := x_v or z_v;
        rst_n_v(8) := x_v or y_v;
      when others =>
        null;
    end case;

    ret_bit_v := newm0_v;

    for i in 0 to MCU_BITLEN - 2 loop
      rm_n_v(i) := rm_n_v(i + 1);
    end loop;
    rm_n_v(MCU_BITLEN - 1) := rin;

    if (icount_r < to_unsigned(36, 6)) and ((command_r and x"FF000000") /= x"00000000") then
      newr0_v := rr_n_v(0);
    end if;

    for i in 0 to MCU_BITLEN - 2 loop
      rr_n_v(i) := rr_n_v(i + 1);
    end loop;
    rr_n_v(MCU_BITLEN - 1) := newr0_v;

    temp_v     := rh_n_v(0);
    rh_n_v(0)  := rh_n_v(1);
    rh_n_v(1)  := rh_n_v(2);
    rh_n_v(2)  := rh_n_v(3);
    rh_n_v(3)  := temp_v;

    if (dcount_r < to_unsigned(13, 4)) and (ecount_r = to_unsigned(0, 2)) then
      dispout_n_v(0) := dispout_n_v(1);
      dispout_n_v(1) := dispout_n_v(2);
      dispout_n_v(2) := dispout_n_v(3);
      dispout_n_v(3) := newr0_v;
    end if;

    temp_v := rst_n_v(0);
    for i in 0 to MCU_BITLEN - 2 loop
      rst_n_v(i) := rst_n_v(i + 1);
    end loop;
    rst_n_v(MCU_BITLEN - 1) := temp_v;

    if ucount_r = to_unsigned(3, 2) then
      ucount_n_v := to_unsigned(0, 2);
      icount_n_v := icount_r + 1;
      ecount_n_v := ecount_r + 1;
    else
      ucount_n_v := ucount_r + 1;
    end if;

    if icount_n_v >= to_unsigned(42, 6) then
      icount_n_v := (others => '0');
      cptr_hi_v := (others => '0');
      if rr_n_v(156) = '1' then
        cptr_hi_v(0) := '1';
      end if;
      if rr_n_v(157) = '1' then
        cptr_hi_v(1) := '1';
      end if;
      if rr_n_v(158) = '1' then
        cptr_hi_v(2) := '1';
      end if;
      if rr_n_v(159) = '1' then
        cptr_hi_v(3) := '1';
      end if;
      cptr_n_v := cptr_hi_v(3 downto 0) & rr_n_v(147) & rr_n_v(146) & rr_n_v(145) & rr_n_v(144);

      command_n_v := mrom_word_next;
      was_t_qrd_n_v := '0';
      rt_n_v := '0';
      latchk1_n_v := '0';
      latchk2_n_v := '0';
    end if;

    if ecount_n_v >= to_unsigned(3, 2) then
      ecount_n_v := (others => '0');
      dcount_n_v := dcount_r + 1;
    end if;

    if dcount_n_v >= to_unsigned(14, 4) then
      dcount_n_v := (others => '0');
    end if;

    if ((command_n_v and x"00FC0000") = x"00000000") and
       (ecount_n_v = to_unsigned(0, 2)) and
       (ucount_n_v = to_unsigned(0, 2)) then
      dcycle_n_v := resize(dcount_n_v + 1, 4);
    else
      dcycle_n_v := (others => '0');
    end if;

    if (dcount_n_v = to_unsigned(13, 4)) and
       (ecount_n_v = to_unsigned(2, 2)) and
       (ucount_n_v = to_unsigned(3, 2)) then
      syncout_n_v := '1';
    else
      syncout_n_v := '0';
    end if;

    segment_n_v := (others => '0');
    if ((command_n_v and x"00FC0000") = x"00000000") and
       (ecount_n_v = to_unsigned(0, 2)) and
       (ucount_n_v = to_unsigned(0, 2)) then
      seg_low_v := (others => '0');
      seg_low_v(0) := dispout_n_v(0);
      seg_low_v(1) := dispout_n_v(1);
      seg_low_v(2) := dispout_n_v(2);
      seg_low_v(3) := dispout_n_v(3);
      segment_n_v := std_logic_vector(seg_low_v);
    end if;

    if ((command_n_v and x"00FC0000") = x"00000000") and (rl_n_v = '1') then
      segment_n_v(7) := '1';
    end if;

    rr_n      <= rr_n_v;
    rm_n      <= rm_n_v;
    rst_n     <= rst_n_v;
    rs_n      <= rs_n_v;
    rs1_n     <= rs1_n_v;
    rh_n      <= rh_n_v;
    dispout_n <= dispout_n_v;

    sigma_n      <= sigma_n_v;
    carry_n      <= carry_n_v;
    rl_n         <= rl_n_v;
    rt_n         <= rt_n_v;
    was_t_qrd_n  <= was_t_qrd_n_v;
    latchk1_n    <= latchk1_n_v;
    latchk2_n    <= latchk2_n_v;
    asp_next     <= asp_next_v;

    icount_n   <= icount_n_v;
    dcount_n   <= dcount_n_v;
    ecount_n   <= ecount_n_v;
    ucount_n   <= ucount_n_v;
    cptr_n     <= cptr_n_v;
    command_n  <= command_n_v;
    cur_ucmd_n <= cur_ucmd_n_v;

    dcycle_n   <= dcycle_n_v;
    syncout_n  <= syncout_n_v;
    segment_n  <= segment_n_v;
    ret_bit    <= ret_bit_v;
  end process;

  tick_seq : process (clk, rst)
  begin
    if rst = '1' then
      rr      <= (others => '0');
      rm      <= (others => '0');
      rstreg  <= (others => '0');
      rs      <= (others => '0');
      rs1     <= (others => '0');
      rh      <= (others => '0');
      dispout <= (others => '0');

      sigma      <= '0';
      carry      <= '0';
      rl         <= '0';
      rt         <= '0';
      was_t_qrd  <= '0';
      latchk1    <= '0';
      latchk2    <= '0';
      asp        <= (others => '0');

      icount_r   <= (others => '0');
      dcount_r   <= (others => '0');
      ecount_r   <= (others => '0');
      ucount_r   <= (others => '0');
      cptr_r     <= (others => '0');
      command_r  <= BOOT_COMMAND_C;
      cur_ucmd_r <= (others => '0');

      rout_reg  <= '0';
      dcycle_r  <= (others => '0');
      syncout_r <= '0';
      segment_r <= (others => '0');
    elsif rising_edge(clk) then
      if tick_en = '1' then
        rr      <= rr_n;
        rm      <= rm_n;
        rstreg  <= rst_n;
        rs      <= rs_n;
        rs1     <= rs1_n;
        rh      <= rh_n;
        dispout <= dispout_n;

        sigma      <= sigma_n;
        carry      <= carry_n;
        rl         <= rl_n;
        rt         <= rt_n;
        was_t_qrd  <= was_t_qrd_n;
        latchk1    <= latchk1_n;
        latchk2    <= latchk2_n;
        asp        <= asp_next;

        icount_r   <= icount_n;
        dcount_r   <= dcount_n;
        ecount_r   <= ecount_n;
        ucount_r   <= ucount_n;
        cptr_r     <= cptr_n;
        command_r  <= command_n;
        cur_ucmd_r <= cur_ucmd_n;

        rout_reg  <= ret_bit;
        dcycle_r  <= dcycle_n;
        syncout_r <= syncout_n;
        segment_r <= segment_n;
      end if;
    end if;
  end process;
end architecture rtl;
