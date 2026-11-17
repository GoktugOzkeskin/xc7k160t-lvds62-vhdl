library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use work.lvds_pkg.all;
use std.env.all;
entity tb_compare is end;
architecture test of tb_compare is
  constant P:positive:=11;
  signal clk:std_logic:='0';signal reset:std_logic:='1';signal run:std_logic:='1';
  signal tx,rx:std_logic_vector(P*8-1 downto 0):=(others=>'0');
  type history_t is array(0 to 7)of std_logic_vector(P*8-1 downto 0);
  signal cable:history_t:=(others=>(others=>'0'));
  type seeds_t is array(0 to P-1)of unsigned(30 downto 0);
  signal seeds:seeds_t:=(others=>to_unsigned(1,31));
  signal mode:natural range 0 to 3:=0;
  signal locked,mask:std_logic_vector(P-1 downto 0);signal errors,bits:std_logic_vector(15 downto 0);signal all_locked:std_logic;
  signal actual_bits,expected_bits,actual_errors,expected_errors:natural:=0;
begin
  clk<=not clk after 4 ns;
  dut:entity work.lvds_compare generic map(PAIRS=>P)port map(clk,reset,run,tx,rx,'0',locked,mask,errors,bits,all_locked);
  process(clk)begin if rising_edge(clk)then
    if reset='1'then
      for i in 0 to P-1 loop seeds(i)<=to_unsigned(1234567+i*65537,31);end loop;
      cable<=(others=>(others=>'0'));actual_bits<=0;actual_errors<=0;
    else
      for i in 0 to P-1 loop seeds(i)<=prbs_next8(seeds(i));end loop;
      cable(0)<=tx;for i in 1 to 7 loop cable(i)<=cable(i-1);end loop;
      actual_bits<=actual_bits+to_integer(unsigned(bits));actual_errors<=actual_errors+to_integer(unsigned(errors));
      if run='1'then
        for i in 0 to P-1 loop null;end loop;
      end if;
    end if;
  end if;end process;
  process(seeds,cable,mode)
    variable v,t:std_logic_vector(P*8-1 downto 0);
  begin
    for i in 0 to P-1 loop t(i*8+7 downto i*8):=prbs_word(seeds(i));v(i*8+7 downto i*8):=cable(3+i mod 4)(i*8+7 downto i*8);end loop;
    case mode is when 1=>v(0):=not v(0);when 2=>v(7 downto 0):=(others=>'X');when 3=>v(7 downto 0):=(others=>'Z');when others=>null;end case;
    tx<=t;rx<=v;
  end process;
  process
    variable eb,ee:natural:=0;
  begin
    wait until rising_edge(clk);
    if reset='1'then eb:=0;ee:=0;
    elsif run='1'then
      for i in 0 to P-1 loop if locked(i)='1'then
        eb:=eb+8;if i=0 then if mode=1 then ee:=ee+1;elsif mode=2 or mode=3 then ee:=ee+8;end if;end if;
      end if;end loop;
    end if;
    -- Reference uses admitted samples and known fault commands, not DUT deltas.
    expected_bits<=eb;expected_errors<=ee;
  end process;
  process begin
    wait for 40 ns;wait until falling_edge(clk);reset<='0';wait until all_locked='1';
    for i in 1 to 20 loop wait until falling_edge(clk);end loop;
    assert actual_errors=0 report "clean comparison failed" severity failure;
    mode<=1;for i in 1 to 9 loop wait until falling_edge(clk);end loop;
    mode<=2;for i in 1 to 3 loop wait until falling_edge(clk);end loop;
    mode<=3;for i in 1 to 2 loop wait until falling_edge(clk);end loop;
    mode<=0;for i in 1 to 20 loop wait until falling_edge(clk);end loop;
    assert all_locked='1' report "errors caused silent reacquisition" severity failure;
    mode<=1;wait until falling_edge(clk);run<='0';mode<=0;
    for i in 1 to 20 loop wait until falling_edge(clk);end loop;
    assert actual_bits=expected_bits report "pipeline lost counted bits" severity failure;
    assert actual_errors=expected_errors report "pipeline lost/corrupted errors" severity failure;
    report "PASS: VHDL compare, 11 latency searches, X/Z, errors, final sample and exact bit conservation; bits="&integer'image(actual_bits)&" errors="&integer'image(actual_errors) severity note;
    stop;wait;
  end process;
  process begin wait for 100 us;assert false report "compare timeout" severity failure;end process;
end;
