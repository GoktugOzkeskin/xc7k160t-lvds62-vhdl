# User supplied reference: exactly 156.250 MHz. No board package pins assumed.
create_clock -name ref156m25 -period 6.400 [get_ports sys_clk156_clk_p]
set_input_jitter [get_clocks ref156m25] 0.100
set_property IOSTANDARD LVDS [get_ports {sys_clk156_clk_p sys_clk156_clk_n}]
# External I/O and reset voltage/pin constraints require actual board information.
