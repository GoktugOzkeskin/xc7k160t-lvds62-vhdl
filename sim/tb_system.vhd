library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use work.lvds_pkg.all;
entity sim_bank is
  generic(PAIRS:positive:=10;BANK_ID:positive:=32);
  port(clk500,clk125,clk200,reset:in std_logic;
    finished,passed,failed,hb:out std_logic);
end;
architecture test of sim_bank is
  signal p,n:std_logic_vector(PAIRS*2-1 downto 0):=(others=>'Z');
  signal tx,rx:std_logic_vector(PAIRS*16-1 downto 0);
  signal ts,slips,loads:std_logic_vector(PAIRS*2-1 downto 0);
  signal taps:std_logic_vector(PAIRS*10-1 downto 0);
  signal ready,direction,fault,valid,pass_s,fail_s,hb_s:std_logic;
  signal ef,er,bf,br:std_logic_vector(63 downto 0);signal cf,cr:std_logic_vector(31 downto 0);
  signal state:std_logic_vector(3 downto 0);
begin
  passed<=pass_s;failed<=fail_s;hb<=hb_s;
  finished<='1'when unsigned(cf)>0 and unsigned(cr)>0 and pass_s='1'and unsigned(bf)>0 and unsigned(br)>0 else'0';
  g_cable:for i in 0 to PAIRS-1 generate
    constant FLIGHT:time:=50 ps+30 ps*i;
  begin
    p(i+PAIRS)<=transport p(i)after FLIGHT when ts(i)='0'else'Z'after FLIGHT;
    n(i+PAIRS)<=transport n(i)after FLIGHT when ts(i)='0'else'Z'after FLIGHT;
    p(i)<=transport p(i+PAIRS)after FLIGHT when ts(i+PAIRS)='0'else'Z'after FLIGHT;
    n(i)<=transport n(i+PAIRS)after FLIGHT when ts(i+PAIRS)='0'else'Z'after FLIGHT;
    process(clk125)begin if falling_edge(clk125)and reset='0'then
      assert not(ts(i)='0'and ts(i+PAIRS)='0')report "physical cable contention" severity failure;
    end if;end process;
  end generate;
  u_phy:entity work.lvds_bidir_phy generic map(LANES=>PAIRS*2,GROUP_NAME=>"SIM_BANK"&integer'image(BANK_ID))
    port map(clk500,clk125,clk200,reset,tx,rx,ts,slips,loads,taps,p,n,ready);
  u_test:entity work.lvds_test_bank generic map(PAIRS=>PAIRS,BANK_ID=>BANK_ID,RUN_WORDS=>4096,HEARTBEAT_BITS=>8)
    port map(clk=>clk125,reset=>reset,calibration_ready=>ready,run_enable=>'1',restart=>'0',clear_errors=>'0',inject_error=>'0',
      data_in_to_device=>rx,data_out_from_device=>tx,tristate=>ts,bitslip=>slips,delay_load=>loads,delay_value=>taps,
      direction=>direction,aligned=>open,compare_locked=>open,error_mask=>open,bit_errors_forward=>ef,bit_errors_reverse=>er,
      checked_bits_forward=>bf,checked_bits_reverse=>br,completed_forward=>cf,completed_reverse=>cr,state_debug=>state,
      fault=>fault,result_valid=>valid,test_pass=>pass_s,failed_sticky=>fail_s,heartbeat=>hb_s,monitor=>open);
  process(clk125)begin if falling_edge(clk125)and reset='0'then
    assert fault='0'and fail_s='0'and unsigned(ef)=0 and unsigned(er)=0 report "serial PHY bank failure "&integer'image(BANK_ID) severity failure;
  end if;end process;
  process begin wait until unsigned(cf)>0 and unsigned(cr)>0;wait until falling_edge(clk125);
    report "BANK "&integer'image(BANK_ID)&" checked="&integer'image(to_integer(unsigned(bf)))&"/"&integer'image(to_integer(unsigned(br)))&" error bits=0" severity note;wait;
  end process;
end;

library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use work.lvds_pkg.all;use std.env.all;
entity system_harness is generic(FULL:boolean:=true);end;
architecture test of system_harness is
  function pick(b:boolean;t,f:positive)return positive is begin if b then return t;else return f;end if;end;
  constant P32:positive:=pick(FULL,10,1);constant P33:positive:=pick(FULL,10,1);constant P34:positive:=pick(FULL,11,1);
  signal osc:std_logic:='0';signal osc_n:std_logic;signal reset_ext:std_logic:='1';
  signal c500,c125,c200,cref,locked,reset_phy:std_logic;
  signal hold_count:natural range 0 to 63:=0;
  signal done_s,passed,failed,hb:std_logic_vector(2 downto 0);
  signal status:std_logic_vector(15 downto 0);
begin
  osc<=not osc after 3.2 ns;osc_n<=not osc;
  clocking:entity work.lvds_clocking port map(osc,osc_n,reset_ext,c500,c125,c200,cref,locked);
  process(c125)begin if rising_edge(c125)then
    if reset_ext='1'or locked/='1'then hold_count<=0;elsif hold_count<63 then hold_count<=hold_count+1;end if;
  end if;end process;
  reset_phy<='1'when reset_ext='1'or locked/='1'or hold_count/=63 else'0';
  bank32:entity work.sim_bank generic map(PAIRS=>P32,BANK_ID=>32)port map(c500,c125,c200,reset_phy,done_s(0),passed(0),failed(0),hb(0));
  bank33:entity work.sim_bank generic map(PAIRS=>P33,BANK_ID=>33)port map(c500,c125,c200,reset_phy,done_s(1),passed(1),failed(1),hb(1));
  bank34:entity work.sim_bank generic map(PAIRS=>P34,BANK_ID=>34)port map(c500,c125,c200,reset_phy,done_s(2),passed(2),failed(2),hb(2));
  evaluator:entity work.lvds_result_summary port map(cref,reset_ext,'0',passed(0),passed(1),passed(2),failed(0),failed(1),failed(2),
    hb(0),hb(1),hb(2),locked,status);
  process begin
    wait for 200 ns;reset_ext<='0';wait until status(0)='1'or status(1)='1';
    assert status(0)='1'and status(1)='0'and and_reduce(done_s)='1'and status(12)='1' report "overall evaluator did not PASS all banks" severity failure;
    if FULL then report "PASS: VHDL SYSTEM ALL 62 bidirectional pairs, actual UNISIM MMCM 156.25 MHz to 500/125/200 MHz, 31 cables, runtime reversal, BITSLIP/IDELAY, PRBS comparison and overall PASS" severity note;
    else report "PASS: VHDL PHY smoke, three banks, actual MMCM/SerDes/IOBUFDS, runtime reversal and overall PASS" severity note;end if;
    stop;wait;
  end process;
  process
    variable stamp:time;
  begin
    wait until reset_phy='0';wait until rising_edge(c500);stamp:=now;wait until rising_edge(c500);
    assert abs((now-stamp)-2 ns)<=1 ps report "500 MHz frequency mismatch" severity failure;
    wait until rising_edge(c125);stamp:=now;wait until rising_edge(c125);
    assert abs((now-stamp)-8 ns)<=1 ps report "125 MHz frequency mismatch" severity failure;
    wait until rising_edge(c200);stamp:=now;wait until rising_edge(c200);
    assert abs((now-stamp)-5 ns)<=1 ps report "200 MHz frequency mismatch" severity failure;wait;
  end process;
  process begin wait for 25 us;report "PROGRESS VHDL serial t="&time'image(now) severity note;end process;
  process begin wait for 500 us;assert false report "system timeout" severity failure;end process;
end;

entity tb_phy is end;
architecture test of tb_phy is begin u:entity work.system_harness generic map(FULL=>false);end;
entity tb_system is end;
architecture test of tb_system is begin u:entity work.system_harness generic map(FULL=>true);end;
