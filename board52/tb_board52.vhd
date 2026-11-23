library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use std.env.all;use work.lvds_pkg.all;
entity tb_board52 is end;
architecture test of tb_board52 is
 signal osc:std_logic:='0';signal osc_n:std_logic;signal reset:std_logic:='1';
 signal p,n:std_logic_vector(51 downto 0):=(others=>'Z');
 signal c125,cref,inject:std_logic:='0';signal ts:std_logic_vector(51 downto 0);
 signal ef,er,bf,br:std_logic_vector(63 downto 0);signal cf,cr:std_logic_vector(31 downto 0);
 signal state:std_logic_vector(3 downto 0);signal status:std_logic_vector(15 downto 0);
 signal compare_locked:std_logic_vector(25 downto 0);
begin
 osc<=not osc after 3.2 ns;osc_n<=not osc;
 dut:entity work.lvds52_core generic map(RUN_WORDS=>4096,HEARTBEAT_BITS=>8,WATCHDOG_BITS=>12)
  port map(refclk_p=>osc,refclk_n=>osc_n,reset=>reset,run_enable=>'1',restart=>'0',clear_errors=>'0',inject_error=>inject,
   clear_watchdog=>'0',lvds_p=>p,lvds_n=>n,clk125=>c125,clk_reference=>cref,
   data_out_from_device=>open,data_in_to_device=>open,tristate=>ts,bitslip=>open,delay_value=>open,
   aligned=>open,compare_locked=>compare_locked,error_mask=>open,bit_errors_forward=>ef,bit_errors_reverse=>er,
   checked_bits_forward=>bf,checked_bits_reverse=>br,completed_forward=>cf,completed_reverse=>cr,
   state_debug=>state,monitor=>open,status=>status);
 cables:for i in 0 to 25 generate
  constant FLIGHT:time:=50 ps+i*30 ps;
 begin
  p(i+26)<=transport p(i)after FLIGHT when ts(i)='0'else'Z'after FLIGHT;
  n(i+26)<=transport n(i)after FLIGHT when ts(i)='0'else'Z'after FLIGHT;
  p(i)<=transport p(i+26)after FLIGHT when ts(i+26)='0'else'Z'after FLIGHT;
  n(i)<=transport n(i+26)after FLIGHT when ts(i+26)='0'else'Z'after FLIGHT;
  process(c125)begin if falling_edge(c125)and reset='0'then
   assert not(ts(i)='0'and ts(i+26)='0')report "board52 cable contention" severity failure;
  end if;end process;
 end generate;
 process begin
  wait for 200 ns;reset<='0';wait until status(0)='1'or status(1)='1';
  assert status(0)='1'and status(1)='0'and unsigned(ef)=0 and unsigned(er)=0
   and unsigned(cf)>0 and unsigned(cr)>0 and unsigned(bf)>0 and unsigned(br)>0
   report "board52 clean forward/reverse test did not pass" severity failure;
  report "PASS: BOARD52 clean loopback, actual three-bank 17/11/24 PHY and MMCM, 52 bidirectional pairs, checked="&
   integer'image(to_integer(unsigned(bf)))&"/"&integer'image(to_integer(unsigned(br)))severity note;
  wait until state=x"3"and and_reduce(compare_locked)='1';wait until falling_edge(c125);inject<='1';
  wait until falling_edge(c125);inject<='0';wait until status(1)='1';wait for 100 ns;
  assert status(0)='0'and(unsigned(ef)>0 or unsigned(er)>0)report "board52 injected error escaped checker" severity failure;
  report "PASS: BOARD52 runtime direction reversal and global error-injection FAIL evaluation"severity note;
  stop;wait;
 end process;
 process begin wait for 500 us;assert false report "board52 timeout"severity failure;end process;
 process begin wait for 25 us;report "BOARD52 progress "&time'image(now)severity note;end process;
end;
