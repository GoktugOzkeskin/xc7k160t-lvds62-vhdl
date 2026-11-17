library ieee;
use ieee.std_logic_1164.all;use ieee.numeric_std.all;use work.lvds_pkg.all;use std.env.all;
entity tb_bank is end;
architecture test of tb_bank is
  constant P:positive:=11;constant WORDS:positive:=9000;
  signal clk:std_logic:='0';signal reset:std_logic:='1';signal ready,enable:std_logic:='1';
  signal clear,restart:std_logic:='0';signal inject_enabled:boolean:=true;signal cable_missing:boolean:=false;
  signal tx,rx:std_logic_vector(P*16-1 downto 0):=(others=>'0');
  type cable_t is array(0 to 7)of std_logic_vector(P*16-1 downto 0);
  signal cable:cable_t:=(others=>(others=>'0'));
  type lane_t is array(0 to P*2-1)of natural range 0 to 31;
  type phase_t is array(0 to P*2-1)of natural range 0 to 7;
  signal tap:lane_t:=(others=>0);signal phase:phase_t:=(others=>0);
  signal ts,slip,load:std_logic_vector(P*2-1 downto 0);signal taps:std_logic_vector(P*10-1 downto 0);
  signal aligned,locked,emask:std_logic_vector(P-1 downto 0);
  signal ef,er,bf,br:std_logic_vector(63 downto 0);signal cf,cr:std_logic_vector(31 downto 0);
  signal state:std_logic_vector(3 downto 0);signal direction,fault,valid,pass,failed,hb,inject:std_logic;
  signal run_ticks:natural range 0 to WORDS:=0;signal expected_bits:natural:=0;
  function rotation(p:natural)return natural is
    type seq_t is array(0 to 7)of natural;constant seq:seq_t:=(0,1,6,7,4,5,2,3);
  begin return seq(p);end;
  function rotate(v:std_logic_vector(7 downto 0);n:natural)return std_logic_vector is
  begin return std_logic_vector(rotate_right(unsigned(v),n));end;
begin
  clk<=not clk after 4 ns;
  inject<='1'when inject_enabled and state=x"3"and direction='0'and run_ticks=WORDS-1 else'0';
  dut:entity work.lvds_test_bank generic map(PAIRS=>P,RUN_WORDS=>WORDS)port map(
    clk=>clk,reset=>reset,calibration_ready=>ready,run_enable=>enable,restart=>restart,clear_errors=>clear,inject_error=>inject,
    data_in_to_device=>rx,data_out_from_device=>tx,tristate=>ts,bitslip=>slip,delay_load=>load,delay_value=>taps,
    direction=>direction,aligned=>aligned,compare_locked=>locked,error_mask=>emask,
    bit_errors_forward=>ef,bit_errors_reverse=>er,checked_bits_forward=>bf,checked_bits_reverse=>br,
    completed_forward=>cf,completed_reverse=>cr,state_debug=>state,fault=>fault,result_valid=>valid,
    test_pass=>pass,failed_sticky=>failed,heartbeat=>hb,monitor=>open);
  process(clk)
    variable peer:natural;variable w:std_logic_vector(7 downto 0);variable eb:natural:=0;
    variable prev_slip:std_logic_vector(P*2-1 downto 0):=(others=>'0');
  begin if rising_edge(clk)then
    if reset='1'then
      cable<=(others=>(others=>'0'));rx<=(others=>'0');tap<=(others=>0);
      for i in 0 to P*2-1 loop phase(i)<=i mod 8;end loop;run_ticks<=0;eb:=0;prev_slip:=(others=>'0');
    else
      cable(0)<=tx;for i in 1 to 7 loop cable(i)<=cable(i-1);end loop;
      assert or_reduce(slip and prev_slip)='0' report "consecutive BITSLIP" severity failure;prev_slip:=slip;
      for i in 0 to P-1 loop assert not(ts(i)='0'and ts(i+P)='0')report "both cable ends driving" severity failure;end loop;
      if state/=x"2"and state/=x"3"then assert and_reduce(ts)='1' report "unsafe guard/drain/fault" severity failure;end if;
      if state=x"3"then
        run_ticks<=run_ticks+1;
        if direction='0'and inject_enabled then for i in 0 to P-1 loop if locked(i)='1'then eb:=eb+8;end if;end loop;end if;
      else run_ticks<=0;end if;
      for i in 0 to P*2-1 loop
        if load(i)='1'then tap(i)<=to_integer(unsigned(taps(i*5+4 downto i*5)));end if;
        if slip(i)='1'then phase(i)<=(phase(i)+1)mod 8;end if;
        if i<P then peer:=i+P;else peer:=i-P;end if;
        w:=cable(3+i mod 3)(peer*8+7 downto peer*8);
        if cable_missing or tap(i)<5+i mod 3 or tap(i)>25-i mod 3 then w:=x"00";else w:=rotate(w,rotation(phase(i)));end if;
        rx(i*8+7 downto i*8)<=w;
      end loop;
      if fault='1'then assert cable_missing report "unexpected bank fault" severity failure;end if;
    end if;
    expected_bits<=eb;
  end if;end process;
  process begin
    wait for 80 ns;wait until falling_edge(clk);reset<='0';
    wait until unsigned(cf)=1;for i in 1 to 3 loop wait until falling_edge(clk);end loop;
    assert unsigned(ef)=1 report "last-word error lost/doubled" severity failure;
    assert unsigned(bf)=expected_bits report "DRAIN bit conservation failed" severity failure;
    assert failed='1'and pass='0' report "last-word error did not FAIL" severity failure;
    wait until unsigned(cr)=1;for i in 1 to 3 loop wait until falling_edge(clk);end loop;
    assert valid='1'and pass='0' report "bad session incorrectly PASS" severity failure;
    enable<='0';clear<='1';for i in 1 to 4 loop wait until falling_edge(clk);end loop;clear<='0';inject_enabled<=false;
    assert unsigned(ef)=0 and unsigned(er)=0 and pass='0'and failed='0' report "clear did not reset session" severity failure;
    enable<='1';wait until unsigned(cf)=1 and unsigned(cr)=1;for i in 1 to 4 loop wait until falling_edge(clk);end loop;
    assert valid='1'and pass='1'and unsigned(ef)=0 and unsigned(er)=0 report "clean bidirectional session did not PASS" severity failure;
    ready<='0';for i in 1 to 10 loop wait until falling_edge(clk);end loop;
    assert failed='1'and pass='0'and and_reduce(ts)='1' report "calibration loss preserved stale PASS" severity failure;
    enable<='0';ready<='1';clear<='1';for i in 1 to 4 loop wait until falling_edge(clk);end loop;clear<='0';cable_missing<=true;enable<='1';
    wait until fault='1';wait until falling_edge(clk);assert pass='0'and failed='1'and and_reduce(ts)='1' report "missing cable not safe FAIL" severity failure;
    report "PASS: VHDL bank, 11 links, DDR alignment, both directions, last error/DRAIN counts, registered PASS, clear, RDY loss and missing cable" severity note;
    stop;wait;
  end process;
  process begin wait for 1 ms;assert false report "bank timeout" severity failure;end process;
end;
