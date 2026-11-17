library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package lvds_pkg is
  function clog2(n : positive) return natural;
  function max_nat(a,b : natural) return natural;
  function and_reduce(v : std_logic_vector) return std_logic;
  function or_reduce(v : std_logic_vector) return std_logic;
  function pop8(v : std_logic_vector(7 downto 0)) return unsigned;
  function checked_xor(a,b : std_logic_vector(7 downto 0)) return std_logic_vector;
  function prbs_next8(v : unsigned(30 downto 0)) return unsigned;
  function prbs_word(v : unsigned(30 downto 0)) return std_logic_vector;
end package;
package body lvds_pkg is
  function clog2(n : positive) return natural is
    variable k : natural := 0; variable x : positive := 1;
  begin while x<n loop x:=x*2; k:=k+1; end loop; return k; end;
  function max_nat(a,b : natural) return natural is
  begin if a>b then return a; else return b; end if; end;
  function and_reduce(v : std_logic_vector) return std_logic is
    variable r : std_logic := '1';
  begin for i in v'range loop r:=r and v(i); end loop; return r; end;
  function or_reduce(v : std_logic_vector) return std_logic is
    variable r : std_logic := '0';
  begin for i in v'range loop r:=r or v(i); end loop; return r; end;
  function pop8(v : std_logic_vector(7 downto 0)) return unsigned is
    variable a,b,c,d : unsigned(1 downto 0);
    variable e,f : unsigned(2 downto 0);
  begin
    a:=unsigned('0' & v(0 downto 0))+unsigned('0' & v(1 downto 1));
    b:=unsigned('0' & v(2 downto 2))+unsigned('0' & v(3 downto 3));
    c:=unsigned('0' & v(4 downto 4))+unsigned('0' & v(5 downto 5));
    d:=unsigned('0' & v(6 downto 6))+unsigned('0' & v(7 downto 7));
    e:=resize(a,3)+resize(b,3); f:=resize(c,3)+resize(d,3);
    return resize(e,4)+resize(f,4);
  end;
  function checked_xor(a,b : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 7 loop
      if (a(i)='0' or a(i)='1') and a(i)=b(i) then r(i):='0'; else r(i):='1'; end if;
    end loop; return r;
  end;
  function prbs_next8(v : unsigned(30 downto 0)) return unsigned is
    variable s : unsigned(30 downto 0) := v;
  begin for i in 0 to 7 loop s:=s(29 downto 0)&(s(30) xor s(27)); end loop; return s; end;
  function prbs_word(v : unsigned(30 downto 0)) return std_logic_vector is
    variable s : unsigned(30 downto 0) := v;
    variable r : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 7 loop r(i):=s(30);s:=s(29 downto 0)&(s(30) xor s(27));end loop;return r;
  end;
end package body;
