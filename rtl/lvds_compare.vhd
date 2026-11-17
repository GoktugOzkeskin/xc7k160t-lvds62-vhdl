library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lvds_pkg.all;
entity lvds_compare is
  generic(PAIRS:positive:=10;HISTORY:positive:=32;CONFIRM:positive:=8);
  port(clk,reset,run:in std_logic;tx_reference,rx_words:in std_logic_vector(PAIRS*8-1 downto 0);
    inject_error:in std_logic;locked,error_mask:out std_logic_vector(PAIRS-1 downto 0);
    bit_errors,checked_bits:out std_logic_vector(15 downto 0);all_locked:out std_logic);
end;
architecture rtl of lvds_compare is
  constant LEVELS:natural:=clog2(PAIRS);constant LEAVES:positive:=2**LEVELS;
  type hist_t is array(0 to HISTORY-1)of std_logic_vector(PAIRS*8-1 downto 0);
  type cand_t is array(0 to PAIRS-1)of natural range 0 to HISTORY-1;
  type good_t is array(0 to PAIRS-1)of natural range 0 to CONFIRM;
  type byte_t is array(0 to PAIRS-1)of std_logic_vector(7 downto 0);
  type tree_t is array(1 to 2*LEAVES-1)of unsigned(15 downto 0);
  type mask_t is array(0 to LEVELS)of std_logic_vector(PAIRS-1 downto 0);
  signal hist:hist_t:=(others=>(others=>'0'));
  signal candidate:cand_t:=(others=>0);signal consecutive:good_t:=(others=>0);
  signal filled:natural range 0 to HISTORY:=0;
  signal locked_s,valid_pipe:std_logic_vector(PAIRS-1 downto 0):=(others=>'0');
  signal difference_pipe:byte_t:=(others=>(others=>'0'));
  signal errors_tree,bits_tree:tree_t:=(others=>(others=>'0'));
  signal masks:mask_t:=(others=>(others=>'0'));
begin
  locked<=locked_s;all_locked<=and_reduce(locked_s);
  process(clk)
    variable observed:std_logic_vector(7 downto 0);
  begin if rising_edge(clk)then
    if reset='1'then
      locked_s<=(others=>'0');valid_pipe<=(others=>'0');filled<=0;
      candidate<=(others=>0);consecutive<=(others=>0);difference_pipe<=(others=>(others=>'0'));
      errors_tree<=(others=>(others=>'0'));bits_tree<=(others=>(others=>'0'));masks<=(others=>(others=>'0'));
      error_mask<=(others=>'0');bit_errors<=(others=>'0');checked_bits<=(others=>'0');
    else
      if run='1'then
        hist(0)<=tx_reference;for j in 1 to HISTORY-1 loop hist(j)<=hist(j-1);end loop;
        if filled<HISTORY then filled<=filled+1;end if;
      end if;
      for i in 0 to PAIRS-1 loop
        observed:=rx_words(i*8+7 downto i*8);
        if inject_error='1' and i=0 then observed(0):=not observed(0);end if;
        valid_pipe(i)<=run and locked_s(i);
        if run='1' and locked_s(i)='1'then
          difference_pipe(i)<=checked_xor(observed,hist(candidate(i))(i*8+7 downto i*8));
        else difference_pipe(i)<=(others=>'0');end if;
        if run='1' and locked_s(i)='0' and filled=HISTORY then
          if observed=hist(candidate(i))(i*8+7 downto i*8)then
            if consecutive(i)=CONFIRM-1 then locked_s(i)<='1';else consecutive(i)<=consecutive(i)+1;end if;
          else
            consecutive(i)<=0;
            if candidate(i)=HISTORY-1 then candidate(i)<=0;else candidate(i)<=candidate(i)+1;end if;
          end if;
        end if;
      end loop;
      for i in 0 to LEAVES-1 loop
        if i<PAIRS then
          if valid_pipe(i)='1'then errors_tree(LEAVES+i)<=resize(pop8(difference_pipe(i)),16);bits_tree(LEAVES+i)<=to_unsigned(8,16);
          else errors_tree(LEAVES+i)<=(others=>'0');bits_tree(LEAVES+i)<=(others=>'0');end if;
        else errors_tree(LEAVES+i)<=(others=>'0');bits_tree(LEAVES+i)<=(others=>'0');end if;
      end loop;
      for i in 1 to LEAVES-1 loop
        errors_tree(i)<=errors_tree(2*i)+errors_tree(2*i+1);bits_tree(i)<=bits_tree(2*i)+bits_tree(2*i+1);
      end loop;
      for i in 0 to PAIRS-1 loop masks(0)(i)<=valid_pipe(i) and or_reduce(difference_pipe(i));end loop;
      for i in 1 to LEVELS loop masks(i)<=masks(i-1);end loop;
      error_mask<=masks(LEVELS);bit_errors<=std_logic_vector(errors_tree(1));checked_bits<=std_logic_vector(bits_tree(1));
    end if;
  end if;end process;
end;
