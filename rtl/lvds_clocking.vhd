library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
entity lvds_clocking is
  port(refclk_p,refclk_n,reset:in std_logic;clk500,clk125,clk200,clk_reference,locked:out std_logic);
end;
architecture rtl of lvds_clocking is
  attribute X_INTERFACE_INFO:string;attribute X_INTERFACE_PARAMETER:string;
  attribute X_INTERFACE_INFO of refclk_p:signal is "xilinx.com:interface:diff_clock:1.0 ref_clock CLK_P";
  attribute X_INTERFACE_INFO of refclk_n:signal is "xilinx.com:interface:diff_clock:1.0 ref_clock CLK_N";
  attribute X_INTERFACE_PARAMETER of refclk_p:signal is "XIL_INTERFACENAME ref_clock, FREQ_HZ 156250000";
  attribute X_INTERFACE_INFO of clk500:signal is "xilinx.com:signal:clock:1.0 clk500 CLK";
  attribute X_INTERFACE_PARAMETER of clk500:signal is "XIL_INTERFACENAME clk500, FREQ_HZ 500000000";
  attribute X_INTERFACE_INFO of clk125:signal is "xilinx.com:signal:clock:1.0 clk125 CLK";
  attribute X_INTERFACE_PARAMETER of clk125:signal is "XIL_INTERFACENAME clk125, FREQ_HZ 125000000";
  attribute X_INTERFACE_INFO of clk200:signal is "xilinx.com:signal:clock:1.0 clk200 CLK";
  attribute X_INTERFACE_PARAMETER of clk200:signal is "XIL_INTERFACENAME clk200, FREQ_HZ 200000000";
  attribute X_INTERFACE_INFO of clk_reference:signal is "xilinx.com:signal:clock:1.0 clk_reference CLK";
  attribute X_INTERFACE_PARAMETER of clk_reference:signal is "XIL_INTERFACENAME clk_reference, FREQ_HZ 156250000";

  signal raw,reference_s,fb,fb_buf,c0,c1,c2:std_logic;
begin
  u_ibuf:IBUFDS generic map(IOSTANDARD=>"LVDS",DIFF_TERM=>false,IBUF_LOW_PWR=>false)
    port map(I=>refclk_p,IB=>refclk_n,O=>raw);
  u_rawbuf:BUFG port map(I=>raw,O=>reference_s);clk_reference<=reference_s;
  -- 156.25 / 5 * 32 = 1000 MHz VCO; /2, /8, /5 => 500,125,200 MHz.
  u_mmcm:MMCME2_BASE generic map(BANDWIDTH=>"OPTIMIZED",CLKIN1_PERIOD=>6.4,DIVCLK_DIVIDE=>5,
    CLKFBOUT_MULT_F=>32.0,CLKFBOUT_PHASE=>0.0,CLKOUT0_DIVIDE_F=>2.0,
    CLKOUT1_DIVIDE=>8,CLKOUT2_DIVIDE=>5,REF_JITTER1=>0.01,STARTUP_WAIT=>false)
    port map(CLKIN1=>reference_s,CLKFBIN=>fb_buf,CLKFBOUT=>fb,CLKFBOUTB=>open,
      CLKOUT0=>c0,CLKOUT0B=>open,CLKOUT1=>c1,CLKOUT1B=>open,CLKOUT2=>c2,CLKOUT2B=>open,
      CLKOUT3=>open,CLKOUT3B=>open,CLKOUT4=>open,CLKOUT5=>open,CLKOUT6=>open,
      LOCKED=>locked,PWRDWN=>'0',RST=>reset);
  u_fb:BUFG port map(I=>fb,O=>fb_buf);
  u_fast:BUFG port map(I=>c0,O=>clk500);u_parallel:BUFG port map(I=>c1,O=>clk125);u_ref200:BUFG port map(I=>c2,O=>clk200);
end;
