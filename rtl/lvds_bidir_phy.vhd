library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
entity lvds_bidir_phy is
  generic(LANES:positive:=20;GROUP_NAME:string:="LVDS_BANK32");
  port(clk500,clk125,refclk200,reset:in std_logic;
    data_out_from_device:in std_logic_vector(LANES*8-1 downto 0);
    data_in_to_device:out std_logic_vector(LANES*8-1 downto 0);
    tristate,bitslip,delay_load:in std_logic_vector(LANES-1 downto 0);
    delay_value:in std_logic_vector(LANES*5-1 downto 0);
    data_to_and_from_pins_p,data_to_and_from_pins_n:inout std_logic_vector(LANES-1 downto 0);
    calibration_ready:out std_logic);
end;
architecture rtl of lvds_bidir_phy is
  attribute X_INTERFACE_INFO:string;attribute X_INTERFACE_PARAMETER:string;
  attribute X_INTERFACE_INFO of clk500:signal is "xilinx.com:signal:clock:1.0 clk500 CLK";
  attribute X_INTERFACE_PARAMETER of clk500:signal is "XIL_INTERFACENAME clk500, FREQ_HZ 500000000";
  attribute X_INTERFACE_INFO of clk125:signal is "xilinx.com:signal:clock:1.0 clk125 CLK";
  attribute X_INTERFACE_PARAMETER of clk125:signal is "XIL_INTERFACENAME clk125, FREQ_HZ 125000000, ASSOCIATED_RESET reset";
  attribute X_INTERFACE_INFO of refclk200:signal is "xilinx.com:signal:clock:1.0 refclk200 CLK";
  attribute X_INTERFACE_PARAMETER of refclk200:signal is "XIL_INTERFACENAME refclk200, FREQ_HZ 200000000";

  signal clk500_b:std_logic;
  attribute IODELAY_GROUP:string;
  attribute IODELAY_GROUP of u_idelayctrl:label is GROUP_NAME;
begin
  clk500_b<=not clk500;
  u_idelayctrl:IDELAYCTRL port map(REFCLK=>refclk200,RST=>reset,RDY=>calibration_ready);
  g_lane:for i in 0 to LANES-1 generate
    signal serial_out,serial_in,serial_delayed,tq,tri_guard:std_logic;
    signal q:std_logic_vector(7 downto 0);
    attribute IODELAY_GROUP of u_delay:label is GROUP_NAME;
  begin
    tri_guard<=tristate(i) or reset;
    u_iobuf:IOBUFDS generic map(IOSTANDARD=>"LVDS",DIFF_TERM=>false,IBUF_LOW_PWR=>false)
      port map(I=>serial_out,T=>tq,O=>serial_in,IO=>data_to_and_from_pins_p(i),IOB=>data_to_and_from_pins_n(i));
    u_delay:IDELAYE2 generic map(DELAY_SRC=>"IDATAIN",IDELAY_TYPE=>"VAR_LOAD",IDELAY_VALUE=>0,
      HIGH_PERFORMANCE_MODE=>"TRUE",REFCLK_FREQUENCY=>200.0,SIGNAL_PATTERN=>"DATA")
      port map(C=>clk125,CE=>'0',INC=>'0',LD=>delay_load(i),LDPIPEEN=>'0',
        CNTVALUEIN=>delay_value(i*5+4 downto i*5),CNTVALUEOUT=>open,IDATAIN=>serial_in,DATAIN=>'0',
        DATAOUT=>serial_delayed,CINVCTRL=>'0',REGRST=>reset);
    u_iserdes:ISERDESE2 generic map(DATA_RATE=>"DDR",DATA_WIDTH=>8,INTERFACE_TYPE=>"NETWORKING",
      NUM_CE=>2,IOBDELAY=>"IFD",SERDES_MODE=>"MASTER")
      port map(D=>'0',DDLY=>serial_delayed,CLK=>clk500,CLKB=>clk500_b,CLKDIV=>clk125,CLKDIVP=>'0',
        RST=>reset,CE1=>'1',CE2=>'1',BITSLIP=>bitslip(i),Q1=>q(7),Q2=>q(6),Q3=>q(5),Q4=>q(4),
        Q5=>q(3),Q6=>q(2),Q7=>q(1),Q8=>q(0),O=>open,OFB=>'0',OCLK=>'0',OCLKB=>'0',
        SHIFTIN1=>'0',SHIFTIN2=>'0',SHIFTOUT1=>open,SHIFTOUT2=>open,DYNCLKDIVSEL=>'0',DYNCLKSEL=>'0');
    data_in_to_device(i*8+7 downto i*8)<=q;
    u_oserdes:OSERDESE2 generic map(DATA_RATE_OQ=>"DDR",DATA_RATE_TQ=>"BUF",DATA_WIDTH=>8,
      TRISTATE_WIDTH=>1,SERDES_MODE=>"MASTER",INIT_TQ=>'1',SRVAL_TQ=>'1')
      port map(CLK=>clk500,CLKDIV=>clk125,RST=>reset,OCE=>'1',TCE=>'1',
        D1=>data_out_from_device(i*8),D2=>data_out_from_device(i*8+1),D3=>data_out_from_device(i*8+2),D4=>data_out_from_device(i*8+3),
        D5=>data_out_from_device(i*8+4),D6=>data_out_from_device(i*8+5),D7=>data_out_from_device(i*8+6),D8=>data_out_from_device(i*8+7),
        OQ=>serial_out,TQ=>tq,T1=>tri_guard,T2=>'1',T3=>'1',T4=>'1',SHIFTIN1=>'0',SHIFTIN2=>'0',
        SHIFTOUT1=>open,SHIFTOUT2=>open,OFB=>open,TFB=>open,TBYTEIN=>'0',TBYTEOUT=>open);
  end generate;
end;
