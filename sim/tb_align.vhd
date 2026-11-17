library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;
entity tb_align is end;
architecture test of tb_align is
  signal clk:std_logic:='0';signal reset:std_logic:='1';signal enable:std_logic:='0';
  signal rx:std_logic_vector(7 downto 0):=(others=>'0');signal slip,load,done,failed:std_logic;
  signal value:std_logic_vector(4 downto 0);signal eye:std_logic_vector(31 downto 0);signal slips:std_logic_vector(15 downto 0);
  signal phase:natural range 0 to 7:=6;signal tap:natural range 0 to 31:=0;signal mode:natural range 0 to 2:=0;
begin
  clk<=not clk after 4 ns;
  dut:entity work.lvds_rx_align port map(clk,reset,enable,rx,slip,load,value,done,failed,eye,slips);
  process(clk)
    variable gap:natural:=100;variable previous:std_logic:='0';variable valid_eye:boolean;
  begin if rising_edge(clk)then
    if load='1'then tap<=to_integer(unsigned(value));end if;
    if slip='1'then assert previous='0'and gap>=3 report "invalid DDR BITSLIP spacing" severity failure;phase<=(phase+1)mod 8;gap:=0;else gap:=gap+1;end if;previous:=slip;
    valid_eye:=(mode=0 and((tap>=2 and tap<=5)or(tap>=12 and tap<=23)))or(mode=1 and tap=13);
    if phase=4 and valid_eye then rx<=x"D3";else rx<=x"00";end if;
  end if;end process;
  process begin
    wait for 40 ns;wait until falling_edge(clk);reset<='0';enable<='1';
    wait until done='1'or failed='1';assert done='1'and unsigned(value)=18 report "wrong widest window center" severity failure;
    enable<='0';for i in 1 to 3 loop wait until falling_edge(clk);end loop;mode<=1;enable<='1';
    wait until done='1'or failed='1';assert failed='1'and done='0' report "marginal one-tap eye accepted" severity failure;
    enable<='0';for i in 1 to 3 loop wait until falling_edge(clk);end loop;mode<=2;enable<='1';
    wait until done='1'or failed='1';assert failed='1'and done='0' report "empty eye accepted" severity failure;
    report "PASS: VHDL BITSLIP spacing, widest disjoint eye, center, marginal and empty-eye rejection" severity note;stop;wait;
  end process;
  process begin wait for 500 us;assert false report "align timeout" severity failure;end process;
end;
