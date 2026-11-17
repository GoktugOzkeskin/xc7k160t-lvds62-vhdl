library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use work.lvds_pkg.all;use std.env.all;
entity tb_ready is end;
architecture test of tb_ready is
  signal clk:std_logic:='0';signal reset:std_logic:='1';signal enable:std_logic:='1';signal clear:std_logic:='0';
  signal ts:std_logic_vector(1 downto 0);signal valid,pass,failed:std_logic;
begin
  clk<=not clk after 4 ns;
  dut:entity work.lvds_test_bank generic map(PAIRS=>1)port map(clk=>clk,reset=>reset,calibration_ready=>'0',run_enable=>enable,
    restart=>'0',clear_errors=>clear,inject_error=>'0',data_in_to_device=>(others=>'0'),data_out_from_device=>open,
    tristate=>ts,bitslip=>open,delay_load=>open,delay_value=>open,direction=>open,aligned=>open,compare_locked=>open,error_mask=>open,
    bit_errors_forward=>open,bit_errors_reverse=>open,checked_bits_forward=>open,checked_bits_reverse=>open,
    completed_forward=>open,completed_reverse=>open,state_debug=>open,fault=>open,result_valid=>valid,test_pass=>pass,
    failed_sticky=>failed,heartbeat=>open,monitor=>open);
  process begin
    wait for 40 ns;wait until falling_edge(clk);reset<='0';wait for 526 us;
    assert failed='1'and valid='1'and pass='0'and ts="11" report "RDY timeout did not fail safely" severity failure;
    enable<='0';clear<='1';for i in 1 to 4 loop wait until falling_edge(clk);end loop;
    assert failed='0'and valid='0'and pass='0' report "RDY timeout clear failed" severity failure;
    report "PASS: VHDL startup calibration timeout, safe high-Z, valid FAIL and clear" severity note;stop;wait;
  end process;
end;
