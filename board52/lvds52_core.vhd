library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lvds_pkg.all;
entity lvds52_core is
  generic(RESET_ACTIVE_LOW:boolean:=false;RUN_WORDS:positive:=16777216;
    HEARTBEAT_BITS:positive:=16;WATCHDOG_BITS:positive:=20);
  port(refclk_p,refclk_n,reset:in std_logic;
    run_enable,restart,clear_errors,inject_error,clear_watchdog:in std_logic;
    lvds_p,lvds_n:inout std_logic_vector(51 downto 0);
    clk125,clk_reference:out std_logic;
    data_out_from_device,data_in_to_device:out std_logic_vector(415 downto 0);
    tristate,bitslip:out std_logic_vector(51 downto 0);
    delay_value:out std_logic_vector(259 downto 0);
    aligned,compare_locked,error_mask:out std_logic_vector(25 downto 0);
    bit_errors_forward,bit_errors_reverse,checked_bits_forward,checked_bits_reverse:out std_logic_vector(63 downto 0);
    completed_forward,completed_reverse:out std_logic_vector(31 downto 0);
    state_debug:out std_logic_vector(3 downto 0);
    monitor:out std_logic_vector(127 downto 0);status:out std_logic_vector(15 downto 0));
end;
architecture rtl of lvds52_core is
  attribute X_INTERFACE_INFO:string;attribute X_INTERFACE_PARAMETER:string;
  attribute X_INTERFACE_INFO of refclk_p:signal is "xilinx.com:interface:diff_clock:1.0 ref_clock CLK_P";
  attribute X_INTERFACE_INFO of refclk_n:signal is "xilinx.com:interface:diff_clock:1.0 ref_clock CLK_N";
  attribute X_INTERFACE_PARAMETER of refclk_p:signal is "XIL_INTERFACENAME ref_clock, FREQ_HZ 156250000";
  attribute X_INTERFACE_INFO of clk125:signal is "xilinx.com:signal:clock:1.0 clk125 CLK";
  attribute X_INTERFACE_PARAMETER of clk125:signal is "XIL_INTERFACENAME clk125, FREQ_HZ 125000000";
  attribute X_INTERFACE_INFO of clk_reference:signal is "xilinx.com:signal:clock:1.0 clk_reference CLK";
  attribute X_INTERFACE_PARAMETER of clk_reference:signal is "XIL_INTERFACENAME clk_reference, FREQ_HZ 156250000";
  signal reset_high,c500,c125,c200,cref,locked,reset125,reset_ref:std_logic;
  signal reset_pipe:std_logic_vector(3 downto 0):=(others=>'1');
  signal reset_ref_pipe:std_logic_vector(3 downto 0):=(others=>'1');
  signal ready,ready_meta,ready_sync:std_logic_vector(2 downto 0):=(others=>'0');
  signal tx,rx:std_logic_vector(415 downto 0);
  signal ts,slips,loads:std_logic_vector(51 downto 0);
  signal taps:std_logic_vector(259 downto 0);
  signal all_ready,pass_s,fail_s,hb,fault,valid,direction:std_logic;
  signal root_meta,root_sync:std_logic_vector(6 downto 0):=(others=>'0');
  signal hb_last,hb_seen,lock_seen,root_fail,pass_final,fail_final:std_logic:='0';
  signal age:unsigned(WATCHDOG_BITS-1 downto 0):=(others=>'0');
  attribute ASYNC_REG:string;
  attribute ASYNC_REG of reset_pipe,reset_ref_pipe,ready_meta,ready_sync,root_meta,root_sync:signal is "TRUE";
begin
  reset_high<=not reset when RESET_ACTIVE_LOW else reset;
  u_clock:entity work.lvds_clocking port map(refclk_p,refclk_n,reset_high,c500,c125,c200,cref,locked);
  clk125<=c125;clk_reference<=cref;
  process(cref,reset_high)begin
    if reset_high='1'then reset_ref_pipe<=(others=>'1');
    elsif rising_edge(cref)then reset_ref_pipe<=reset_ref_pipe(2 downto 0)&'0';end if;
  end process;
  reset_ref<=reset_ref_pipe(3);
  process(c125,reset_high,locked)begin
    if reset_high='1'or locked='0'then reset_pipe<=(others=>'1');
    elsif rising_edge(c125)then reset_pipe<=reset_pipe(2 downto 0)&'0';end if;
  end process;
  reset125<=reset_pipe(3);
  process(c125,reset125)begin
    if reset125='1'then ready_meta<=(others=>'0');ready_sync<=(others=>'0');
    elsif rising_edge(c125)then ready_meta<=ready;ready_sync<=ready_meta;end if;
  end process;
  all_ready<=and_reduce(ready_sync);
  -- Global lane index equals the schematic's LVDS_CONN2 suffix.
  -- 0..23: bank34; 24..34: bank33; 35..51: bank32.
  phy34:entity work.lvds_bidir_phy generic map(LANES=>24,GROUP_NAME=>"BOARD52_BANK34")
    port map(c500,c125,c200,reset125,tx(191 downto 0),rx(191 downto 0),ts(23 downto 0),
      slips(23 downto 0),loads(23 downto 0),taps(119 downto 0),lvds_p(23 downto 0),lvds_n(23 downto 0),ready(0));
  phy33:entity work.lvds_bidir_phy generic map(LANES=>11,GROUP_NAME=>"BOARD52_BANK33")
    port map(c500,c125,c200,reset125,tx(279 downto 192),rx(279 downto 192),ts(34 downto 24),
      slips(34 downto 24),loads(34 downto 24),taps(174 downto 120),lvds_p(34 downto 24),lvds_n(34 downto 24),ready(1));
  phy32:entity work.lvds_bidir_phy generic map(LANES=>17,GROUP_NAME=>"BOARD52_BANK32")
    port map(c500,c125,c200,reset125,tx(415 downto 280),rx(415 downto 280),ts(51 downto 35),
      slips(51 downto 35),loads(51 downto 35),taps(259 downto 175),lvds_p(51 downto 35),lvds_n(51 downto 35),ready(2));
  test52:entity work.lvds_test_bank generic map(PAIRS=>26,BANK_ID=>52,RUN_WORDS=>RUN_WORDS,HEARTBEAT_BITS=>HEARTBEAT_BITS)
    port map(clk=>c125,reset=>reset125,calibration_ready=>all_ready,run_enable=>run_enable,restart=>restart,
      clear_errors=>clear_errors,inject_error=>inject_error,data_in_to_device=>rx,data_out_from_device=>tx,
      tristate=>ts,bitslip=>slips,delay_load=>loads,delay_value=>taps,direction=>direction,
      aligned=>aligned,compare_locked=>compare_locked,error_mask=>error_mask,
      bit_errors_forward=>bit_errors_forward,bit_errors_reverse=>bit_errors_reverse,
      checked_bits_forward=>checked_bits_forward,checked_bits_reverse=>checked_bits_reverse,
      completed_forward=>completed_forward,completed_reverse=>completed_reverse,state_debug=>state_debug,
      fault=>fault,result_valid=>valid,test_pass=>pass_s,failed_sticky=>fail_s,heartbeat=>hb,monitor=>monitor);
  data_out_from_device<=tx;data_in_to_device<=rx;tristate<=ts;bitslip<=slips;delay_value<=taps;
  process(cref)begin if rising_edge(cref)then
    if reset_ref='1'then
      root_meta<=(others=>'0');root_sync<=(others=>'0');hb_last<='0';hb_seen<='0';lock_seen<='0';root_fail<='0';age<=(others=>'0');
    else
      root_meta<=ready_sync&locked&hb&fail_s&pass_s;root_sync<=root_meta;hb_last<=root_sync(2);
      if clear_watchdog='1'then root_fail<='0';hb_seen<='0';lock_seen<='0';age<=(others=>'0');
      else
        if root_sync(3)='1'then lock_seen<='1';end if;
        if lock_seen='1'and root_sync(3)='0'then root_fail<='1';end if;
        if root_sync(2)/=hb_last then hb_seen<='1';age<=(others=>'0');
        elsif lock_seen='1'then
          if and_reduce(std_logic_vector(age))='1'then root_fail<='1';else age<=age+1;end if;
        end if;
      end if;
    end if;
  end if;end process;
  fail_final<=root_sync(1)or root_fail;
  pass_final<=root_sync(0)and hb_seen and root_sync(3)and and_reduce(root_sync(6 downto 4))and not fail_final;
  status<="00000000"&root_sync(6 downto 4)&root_sync(3)&hb_seen&(pass_final or fail_final)&fail_final&pass_final;
end;
