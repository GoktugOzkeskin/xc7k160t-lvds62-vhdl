library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lvds_pkg.all;
entity lvds_result_summary is
  generic(WATCHDOG_BITS:positive:=20);
  port(clk,reset,clear_watchdog:in std_logic;pass32,pass33,pass34,fail32,fail33,fail34,hb32,hb33,hb34,clock_locked:in std_logic;
    status:out std_logic_vector(15 downto 0));
end;
architecture rtl of lvds_result_summary is
  attribute X_INTERFACE_INFO:string;attribute X_INTERFACE_PARAMETER:string;
  attribute X_INTERFACE_INFO of clk:signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_PARAMETER of clk:signal is "XIL_INTERFACENAME clk, FREQ_HZ 156250000, ASSOCIATED_RESET reset";

  attribute X_INTERFACE_IGNORE:string;
  attribute X_INTERFACE_IGNORE of clock_locked:signal is "TRUE";
  signal sync1,sync2:std_logic_vector(8 downto 0):=(others=>'0');
  signal lock_sync:std_logic_vector(1 downto 0):=(others=>'0');
  signal heartbeat_last,seen,timeout_sticky:std_logic_vector(2 downto 0):=(others=>'0');
  signal lock_seen:std_logic:='0';
  type age_t is array(0 to 2)of unsigned(WATCHDOG_BITS-1 downto 0);
  signal age:age_t:=(others=>(others=>'0'));
  signal bank_pass,bank_fail,valid:std_logic_vector(2 downto 0);
  attribute ASYNC_REG:string;
  attribute ASYNC_REG of sync1,sync2,lock_sync:signal is "TRUE";
begin
  bank_fail<=sync2(5 downto 3)or timeout_sticky;
  g_status:for i in 0 to 2 generate
    bank_pass(i)<=sync2(i)and seen(i)and not timeout_sticky(i)and lock_sync(1)and not bank_fail(i);
  end generate;
  valid<=bank_pass or bank_fail;
  status<="000"&lock_sync(1)&valid&bank_fail&bank_pass&and_reduce(valid)&or_reduce(bank_fail)&and_reduce(bank_pass);
  process(clk)begin if rising_edge(clk)then
    if reset='1'then
      sync1<=(others=>'0');sync2<=(others=>'0');lock_sync<=(others=>'0');lock_seen<='0';
      heartbeat_last<=(others=>'0');seen<=(others=>'0');timeout_sticky<=(others=>'0');age<=(others=>(others=>'0'));
    else
      sync1<=hb34&hb33&hb32&fail34&fail33&fail32&pass34&pass33&pass32;sync2<=sync1;lock_sync<=lock_sync(0)&clock_locked;
      if clear_watchdog='1'then lock_seen<='0';elsif lock_sync(1)='1'then lock_seen<='1';end if;
      for i in 0 to 2 loop
        if clear_watchdog='1'then age(i)<=(others=>'0');seen(i)<='0';timeout_sticky(i)<='0';heartbeat_last(i)<=sync2(6+i);
        elsif sync2(6+i)/=heartbeat_last(i)then heartbeat_last(i)<=sync2(6+i);age(i)<=(others=>'0');seen(i)<='1';
        elsif and_reduce(std_logic_vector(age(i)))/='1'then age(i)<=age(i)+1;else timeout_sticky(i)<='1';end if;
      end loop;
      if lock_seen='1'and lock_sync(1)='0'and clear_watchdog='0'then timeout_sticky<=(others=>'1');end if;
    end if;
  end if;end process;
end;
