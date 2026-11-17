library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity lvds_rx_align is
  generic(TRAIN : std_logic_vector(7 downto 0):=x"D3";
    SETTLE:positive:=6;OBSERVE:positive:=12;MATCHES:positive:=4;MIN_EYE_TAPS:positive:=3);
  port(clk,reset,enable:in std_logic;rx_word:in std_logic_vector(7 downto 0);
    bitslip,delay_load:out std_logic;delay_value:out std_logic_vector(4 downto 0);
    done,failed:out std_logic;eye_mask:out std_logic_vector(31 downto 0);
    slip_count:out std_logic_vector(15 downto 0));
end;
architecture rtl of lvds_rx_align is
  type state_t is(a_idle,a_load,a_wait_tap,a_check,a_wait_slip,a_advance,a_pick,
    a_final_load,a_final_wait,a_final_check,a_final_slip_wait,a_finish,a_fail,a_pick_done);
  signal state:state_t:=a_idle;
  signal tap,scan_index,best_end:natural range 0 to 31:=0;
  signal streak,best_len:natural range 0 to 32:=0;
  signal trial:natural range 0 to 7:=0;
  signal wait_count:natural range 0 to SETTLE:=0;
  signal observe_count:natural range 0 to OBSERVE:=0;
  signal match_count:natural range 0 to MATCHES:=0;
  signal eye:std_logic_vector(31 downto 0):=(others=>'0');
  signal slips:unsigned(15 downto 0):=(others=>'0');
begin
  eye_mask<=eye;slip_count<=std_logic_vector(slips);
  process(clk)begin if rising_edge(clk)then
    if reset='1' or enable='0' then
      state<=a_idle;tap<=0;scan_index<=0;best_end<=0;streak<=0;best_len<=0;trial<=0;
      wait_count<=0;observe_count<=0;match_count<=0;eye<=(others=>'0');slips<=(others=>'0');
      bitslip<='0';delay_load<='0';delay_value<=(others=>'0');done<='0';failed<='0';
    else
      bitslip<='0';delay_load<='0';
      case state is
        when a_idle=>tap<=0;state<=a_load;
        when a_load=>delay_value<=std_logic_vector(to_unsigned(tap,5));delay_load<='1';
          wait_count<=SETTLE;trial<=0;match_count<=0;observe_count<=0;state<=a_wait_tap;
        when a_wait_tap|a_wait_slip=>
          if wait_count=0 then state<=a_check;observe_count<=0;match_count<=0;
          else wait_count<=wait_count-1;end if;
        when a_check|a_final_check=>
          observe_count<=observe_count+1;
          if rx_word=TRAIN then match_count<=match_count+1;else match_count<=0;end if;
          if rx_word=TRAIN and match_count=MATCHES-1 then
            if state=a_final_check then done<='1';state<=a_finish;
            else eye(tap)<='1';state<=a_advance;end if;
          elsif observe_count=OBSERVE-1 then
            if trial=7 then
              if state=a_final_check then failed<='1';state<=a_fail;else state<=a_advance;end if;
            else
              bitslip<='1';slips<=slips+1;trial<=trial+1;wait_count<=SETTLE;
              if state=a_final_check then state<=a_final_slip_wait;else state<=a_wait_slip;end if;
            end if;
          end if;
        when a_advance=>
          if tap=31 then scan_index<=0;streak<=0;best_len<=0;best_end<=0;state<=a_pick;
          else tap<=tap+1;state<=a_load;end if;
        when a_pick=>
          if eye(scan_index)='1' then streak<=streak+1;
            if streak+1>best_len then best_len<=streak+1;best_end<=scan_index;end if;
          else streak<=0;end if;
          if scan_index=31 then state<=a_pick_done;else scan_index<=scan_index+1;end if;
        when a_pick_done=>
          if best_len<MIN_EYE_TAPS then failed<='1';state<=a_fail;
          else delay_value<=std_logic_vector(to_unsigned(best_end-(best_len-1)/2,5));state<=a_final_load;end if;
        when a_final_load=>delay_load<='1';wait_count<=SETTLE;trial<=0;
          observe_count<=0;match_count<=0;state<=a_final_wait;
        when a_final_wait|a_final_slip_wait=>
          if wait_count=0 then state<=a_final_check;observe_count<=0;match_count<=0;
          else wait_count<=wait_count-1;end if;
        when a_finish=>done<='1';
        when a_fail=>failed<='1';
      end case;
    end if;
  end if;end process;
end;
