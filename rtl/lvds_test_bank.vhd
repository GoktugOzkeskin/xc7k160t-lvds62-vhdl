library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lvds_pkg.all;
entity lvds_test_bank is
  generic(PAIRS:positive:=10;BANK_ID:positive:=32;RUN_WORDS:positive:=16777216;
    GUARD_WORDS:positive:=64;DRAIN_WORDS:positive:=16;HEARTBEAT_BITS:positive:=16);
  port(clk,reset,calibration_ready,run_enable,restart,clear_errors,inject_error:in std_logic;
    data_in_to_device:in std_logic_vector(PAIRS*16-1 downto 0);
    data_out_from_device:out std_logic_vector(PAIRS*16-1 downto 0);
    tristate,bitslip,delay_load:out std_logic_vector(PAIRS*2-1 downto 0);
    delay_value:out std_logic_vector(PAIRS*10-1 downto 0);
    direction:out std_logic;aligned,compare_locked,error_mask:out std_logic_vector(PAIRS-1 downto 0);
    bit_errors_forward,bit_errors_reverse,checked_bits_forward,checked_bits_reverse:out std_logic_vector(63 downto 0);
    completed_forward,completed_reverse:out std_logic_vector(31 downto 0);
    state_debug:out std_logic_vector(3 downto 0);fault,result_valid,test_pass,failed_sticky,heartbeat:out std_logic;
    monitor:out std_logic_vector(127 downto 0));
end;
architecture rtl of lvds_test_bank is
  attribute X_INTERFACE_INFO:string;attribute X_INTERFACE_PARAMETER:string;
  attribute X_INTERFACE_INFO of clk:signal is "xilinx.com:signal:clock:1.0 clk CLK";
  attribute X_INTERFACE_PARAMETER of clk:signal is "XIL_INTERFACENAME clk, FREQ_HZ 125000000, ASSOCIATED_RESET reset";

  type state_t is(s_stop,s_guard,s_training,s_run,s_swap,s_fault,s_drain);
  signal state:state_t:=s_stop;
  signal timer:natural range 0 to max_nat(RUN_WORDS,65536):=0;
  type prbs_t is array(0 to PAIRS-1)of unsigned(30 downto 0);
  signal prbs:prbs_t:=(others=>to_unsigned(1,31));
  signal tx_reference,rx_words:std_logic_vector(PAIRS*8-1 downto 0);
  signal align_done,align_failed,slips,loads,locked_s,mask_s:std_logic_vector(PAIRS-1 downto 0);
  signal taps:std_logic_vector(PAIRS*5-1 downto 0);
  signal error_delta,bit_delta:std_logic_vector(15 downto 0);
  signal all_locked,align_enable,align_reset,compare_run,compare_reset:std_logic;
  signal ready_sync:std_logic_vector(1 downto 0):=(others=>'0');
  attribute ASYNC_REG:string;attribute ASYNC_REG of ready_sync:signal is "TRUE";
  signal dir_s,fault_s,phase_error,passed_forward,passed_reverse,sticky_fail,pass_s,valid_s,calibration_seen:std_logic:='0';
  signal calibration_wait:unsigned(15 downto 0):=(others=>'0');
  signal heartbeat_count:unsigned(HEARTBEAT_BITS-1 downto 0):=(others=>'0');
  signal heartbeat_s:std_logic:='0';
  signal ef,er,bf,br:unsigned(63 downto 0):=(others=>'0');
  signal cf,cr:unsigned(31 downto 0):=(others=>'0');
begin
  assert DRAIN_WORDS>=clog2(PAIRS)+4 report "DRAIN_WORDS too short for comparison pipeline" severity failure;
  direction<=dir_s;fault<=fault_s;failed_sticky<=sticky_fail;heartbeat<=heartbeat_s;
  aligned<=align_done;compare_locked<=locked_s;error_mask<=mask_s;
  bit_errors_forward<=std_logic_vector(ef);bit_errors_reverse<=std_logic_vector(er);
  checked_bits_forward<=std_logic_vector(bf);checked_bits_reverse<=std_logic_vector(br);
  completed_forward<=std_logic_vector(cf);completed_reverse<=std_logic_vector(cr);
  state_debug<=std_logic_vector(to_unsigned(state_t'pos(state),4));
  valid_s<='1' when (cf/=0 and cr/=0) or sticky_fail='1' else '0';
  result_valid<=valid_s;test_pass<=pass_s;
  monitor<=std_logic_vector(ef(31 downto 0))&std_logic_vector(er(31 downto 0))&
    std_logic_vector(bf(23 downto 0))&std_logic_vector(br(23 downto 0))&x"00"&pass_s&valid_s&fault_s&dir_s&std_logic_vector(to_unsigned(state_t'pos(state),4));
  process(clk,reset)begin
    if reset='1'then ready_sync<=(others=>'0');elsif rising_edge(clk)then ready_sync<=ready_sync(0)&calibration_ready;end if;
  end process;
  process(clk)begin if rising_edge(clk)then
    if reset='1'then heartbeat_count<=(others=>'0');heartbeat_s<='0';
    else heartbeat_count<=heartbeat_count+1;if and_reduce(std_logic_vector(heartbeat_count))='1'then heartbeat_s<=not heartbeat_s;end if;end if;
    if reset='1' or clear_errors='1'then pass_s<='0';
    else pass_s<=valid_s and passed_forward and passed_reverse and not sticky_fail;end if;
  end if;end process;
  process(prbs,state,dir_s,data_in_to_device,run_enable,ready_sync,reset,restart,clear_errors)
    variable w:std_logic_vector(7 downto 0);
    variable txv:std_logic_vector(PAIRS*16-1 downto 0);
    variable refv,rxv:std_logic_vector(PAIRS*8-1 downto 0);
    variable tv:std_logic_vector(PAIRS*2-1 downto 0);
  begin
    txv:=(others=>'0');refv:=(others=>'0');rxv:=(others=>'0');tv:=(others=>'1');
    for i in 0 to PAIRS-1 loop
      if state=s_run then w:=prbs_word(prbs(i));else w:=x"D3";end if;
      refv(i*8+7 downto i*8):=w;
      if dir_s='0'then
        txv(i*8+7 downto i*8):=w;rxv(i*8+7 downto i*8):=data_in_to_device((i+PAIRS)*8+7 downto (i+PAIRS)*8);
        if (state=s_training or state=s_run)and run_enable='1'and ready_sync(1)='1'and reset='0'and restart='0'and clear_errors='0'then tv(i):='0';end if;
      else
        txv((i+PAIRS)*8+7 downto (i+PAIRS)*8):=w;rxv(i*8+7 downto i*8):=data_in_to_device(i*8+7 downto i*8);
        if (state=s_training or state=s_run)and run_enable='1'and ready_sync(1)='1'and reset='0'and restart='0'and clear_errors='0'then tv(i+PAIRS):='0';end if;
      end if;
    end loop;
    data_out_from_device<=txv;tx_reference<=refv;rx_words<=rxv;tristate<=tv;
  end process;
  align_enable<='1'when state=s_training or state=s_run else'0';align_reset<=reset or restart;
  g_align:for i in 0 to PAIRS-1 generate
    u_align:entity work.lvds_rx_align port map(clk=>clk,reset=>align_reset,enable=>align_enable,
      rx_word=>rx_words(i*8+7 downto i*8),bitslip=>slips(i),delay_load=>loads(i),delay_value=>taps(i*5+4 downto i*5),
      done=>align_done(i),failed=>align_failed(i),eye_mask=>open,slip_count=>open);
    bitslip(i)<=slips(i)when dir_s='1'else'0';bitslip(i+PAIRS)<=slips(i)when dir_s='0'else'0';
    delay_load(i)<=loads(i)when dir_s='1'else'0';delay_load(i+PAIRS)<=loads(i)when dir_s='0'else'0';
    delay_value(i*5+4 downto i*5)<=taps(i*5+4 downto i*5);
    delay_value((i+PAIRS)*5+4 downto (i+PAIRS)*5)<=taps(i*5+4 downto i*5);
  end generate;
  compare_run<='1'when state=s_run else'0';
  compare_reset<='1'when reset='1'or restart='1'or clear_errors='1'or(state/=s_run and state/=s_drain)else'0';
  u_compare:entity work.lvds_compare generic map(PAIRS=>PAIRS)port map(clk,compare_reset,compare_run,tx_reference,rx_words,
    inject_error,locked_s,mask_s,error_delta,bit_delta,all_locked);
  process(clk)
    variable offset:natural;
  begin if rising_edge(clk)then
    if reset='1'then
      state<=s_stop;timer<=0;dir_s<='0';fault_s<='0';phase_error<='0';passed_forward<='0';passed_reverse<='0';sticky_fail<='0';
      calibration_seen<='0';calibration_wait<=(others=>'0');ef<=(others=>'0');er<=(others=>'0');bf<=(others=>'0');br<=(others=>'0');cf<=(others=>'0');cr<=(others=>'0');
      prbs<=(others=>to_unsigned(1,31));
    else
      if clear_errors='1'then
        ef<=(others=>'0');er<=(others=>'0');bf<=(others=>'0');br<=(others=>'0');cf<=(others=>'0');cr<=(others=>'0');
        phase_error<='0';passed_forward<='0';passed_reverse<='0';sticky_fail<='0';calibration_seen<='0';calibration_wait<=(others=>'0');
      elsif state=s_run or state=s_drain or state=s_swap then
        if dir_s='0'then ef<=ef+resize(unsigned(error_delta),64);bf<=bf+resize(unsigned(bit_delta),64);
        else er<=er+resize(unsigned(error_delta),64);br<=br+resize(unsigned(bit_delta),64);end if;
        if unsigned(error_delta)/=0 then phase_error<='1';sticky_fail<='1';end if;
      end if;
      if dir_s='1'then offset:=1048576;else offset:=0;end if;
      for i in 0 to PAIRS-1 loop
        if state=s_run then prbs(i)<=prbs_next8(prbs(i));
        else prbs(i)<=to_unsigned(16#13579BD#,31)xor to_unsigned(BANK_ID*257+i*65537+offset,31);end if;
      end loop;
      if clear_errors='0'then
        if ready_sync(1)='1'then calibration_seen<='1';end if;
        if calibration_seen='1'and ready_sync(1)='0'and run_enable='1'and restart='0'then sticky_fail<='1';end if;
        if ready_sync(1)='1'or run_enable='0'or restart='1'then calibration_wait<=(others=>'0');
        elsif calibration_wait/=x"FFFF"then calibration_wait<=calibration_wait+1;else sticky_fail<='1';end if;
      end if;
      if run_enable='0'or restart='1'or clear_errors='1'or ready_sync(1)='0'then
        state<=s_stop;timer<=0;fault_s<='0';if clear_errors='1'then dir_s<='0';end if;
      else
        case state is
          when s_stop=>timer<=0;state<=s_guard;
          when s_guard=>if timer=GUARD_WORDS-1 then timer<=0;state<=s_training;else timer<=timer+1;end if;
          when s_training=>timer<=timer+1;
            if or_reduce(align_failed)='1'or timer=65535 then fault_s<='1';sticky_fail<='1';state<=s_fault;
            elsif and_reduce(align_done)='1'then timer<=0;phase_error<='0';state<=s_run;end if;
          when s_run=>timer<=timer+1;
            if timer=8191 and all_locked/='1'then fault_s<='1';sticky_fail<='1';state<=s_fault;
            elsif timer=RUN_WORDS-1 then timer<=0;state<=s_drain;end if;
          when s_drain=>if timer=DRAIN_WORDS-1 then timer<=0;state<=s_swap;else timer<=timer+1;end if;
          when s_swap=>
            if all_locked/='1'or phase_error='1'or unsigned(error_delta)/=0 then sticky_fail<='1';end if;
            if dir_s='0'then cf<=cf+1;passed_forward<=all_locked and not phase_error;
              if unsigned(error_delta)/=0 then passed_forward<='0';end if;
            else cr<=cr+1;passed_reverse<=all_locked and not phase_error;
              if unsigned(error_delta)/=0 then passed_reverse<='0';end if;end if;
            dir_s<=not dir_s;timer<=0;state<=s_guard;
          when s_fault=>fault_s<='1';
        end case;
      end if;
    end if;
  end if;end process;
end;
