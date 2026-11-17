library ieee;
use ieee.std_logic_1164.all;use std.env.all;
entity tb_result is end;
architecture test of tb_result is
  signal clk:std_logic:='0';signal reset:std_logic:='1';signal clear:std_logic:='0';
  signal passed,failed,hb:std_logic_vector(2 downto 0):=(others=>'0');
  signal hb_stop:boolean:=false;signal locked:std_logic:='1';signal status:std_logic_vector(15 downto 0);
begin
  clk<=not clk after 3.2 ns;
  dut:entity work.lvds_result_summary generic map(WATCHDOG_BITS=>8)port map(clk,reset,clear,
    passed(0),passed(1),passed(2),failed(0),failed(1),failed(2),hb(0),hb(1),hb(2),locked,status);
  process begin wait for 100 ns;hb(1 downto 0)<=not hb(1 downto 0);if not hb_stop then hb(2)<=not hb(2);end if;end process;
  process begin
    wait for 100 ns;reset<='0';wait for 200 ns;
    assert status(2 downto 0)="000" report "untested result is not pending" severity failure;
    passed<="111";wait for 100 ns;assert status(2 downto 0)="101" report "three banks did not PASS" severity failure;
    failed(1)<='1';wait for 100 ns;assert status(1 downto 0)="10" report "bank failure did not dominate PASS" severity failure;
    failed<="000";wait for 100 ns;hb_stop<=true;wait for 2 us;
    assert status(1)='1'and status(0)='0'and status(8)='1' report "missing heartbeat not detected" severity failure;
    hb_stop<=false;clear<='1';wait for 50 ns;clear<='0';wait for 200 ns;
    assert status(0)='1'and status(1)='0' report "watchdog recovery failed" severity failure;
    locked<='0';wait for 100 ns;assert status(0)='0'and status(1)='1'and status(12)='0' report "MMCM loss not detected" severity failure;
    report "PASS: VHDL global result, pending/PASS/FAIL, CDC, watchdog, recovery and MMCM loss" severity note;stop;wait;
  end process;
end;
