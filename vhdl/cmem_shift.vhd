library ieee;
use ieee.std_logic_1164.all;

entity cmem_shift_vhdl is
  generic (
    LEN : integer := 1008
  );
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    tick_en : in  std_logic;
    in_bit  : in  std_logic;
    out_bit : out std_logic
  );
end entity cmem_shift_vhdl;

architecture rtl of cmem_shift_vhdl is
  signal mem     : std_logic_vector(LEN - 1 downto 0);
  signal out_reg : std_logic;
begin
  out_bit <= out_reg;

  process (clk, rst)
  begin
    if rst = '1' then
      mem     <= (others => '0');
      out_reg <= '0';
    elsif rising_edge(clk) then
      if tick_en = '1' then
        -- Emulate cMem::tick(): return old mem(0), then shift input in.
        out_reg <= mem(0);
        mem     <= in_bit & mem(LEN - 1 downto 1);
      end if;
    end if;
  end process;
end architecture rtl;
