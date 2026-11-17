set root [file normalize [file join [file dirname [info script]] ..]]
file mkdir $root/build
create_project lvds62_vhdl $root/build/project -part xc7k160tfbg676-1 -force
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
add_files [glob $root/rtl/*.vhd]
add_files -fileset sim_1 [glob $root/sim/*.vhd]
set_property file_type {VHDL 2008} [get_files $root/sim/*.vhd]
set_property top tb_system [get_filesets sim_1]
set_property xsim.simulate.runtime 500us [get_filesets sim_1]
update_compile_order -fileset sources_1
create_bd_design lvds_vhdl_bd
create_bd_port -dir I -type rst reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports reset]
create_bd_cell -type module -reference lvds_clocking CLOCK_156M25
make_bd_intf_pins_external [get_bd_intf_pins CLOCK_156M25/ref_clock]
set_property name sys_clk156 [get_bd_intf_ports ref_clock_0]
connect_bd_net [get_bd_ports reset] [get_bd_pins CLOCK_156M25/reset]
foreach value {0 1} {
 create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const$value
 set_property CONFIG.CONST_VAL $value [get_bd_cells const$value]
}
create_bd_cell -type module -reference lvds_result_summary RESULT_PASS_FAIL
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 RESULT_RST
connect_bd_net [get_bd_ports reset] [get_bd_pins RESULT_RST/ext_reset_in]
connect_bd_net [get_bd_pins const0/dout] [get_bd_pins RESULT_RST/aux_reset_in] [get_bd_pins RESULT_RST/mb_debug_sys_rst]
connect_bd_net [get_bd_pins const1/dout] [get_bd_pins RESULT_RST/dcm_locked]
connect_bd_net [get_bd_pins CLOCK_156M25/clk_reference] [get_bd_pins RESULT_RST/slowest_sync_clk] [get_bd_pins RESULT_PASS_FAIL/clk]
connect_bd_net [get_bd_pins RESULT_RST/peripheral_reset] [get_bd_pins RESULT_PASS_FAIL/reset]
connect_bd_net [get_bd_pins CLOCK_156M25/locked] [get_bd_pins RESULT_PASS_FAIL/clock_locked]
create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 RESULT_VIO
set_property -dict [list CONFIG.C_NUM_PROBE_IN 1 CONFIG.C_NUM_PROBE_OUT 1 CONFIG.C_PROBE_IN0_WIDTH 16] [get_bd_cells RESULT_VIO]
connect_bd_net [get_bd_pins CLOCK_156M25/clk_reference] [get_bd_pins RESULT_VIO/clk]
connect_bd_net [get_bd_pins RESULT_PASS_FAIL/status] [get_bd_pins RESULT_VIO/probe_in0]
connect_bd_net [get_bd_pins RESULT_VIO/probe_out0] [get_bd_pins RESULT_PASS_FAIL/clear_watchdog]
foreach bank {32 33 34} pairs {10 10 11} {
 set phy bank${bank}_PHY_BIDIR
 set ctrl bank${bank}_TEST
 set rst bank${bank}_RST
 set vio bank${bank}_VIO
 set ila bank${bank}_ILA
 create_bd_cell -type module -reference lvds_bidir_phy $phy
 set_property -dict [list CONFIG.LANES [expr {$pairs*2}] CONFIG.GROUP_NAME LVDS_BANK${bank}] [get_bd_cells $phy]
 create_bd_cell -type module -reference lvds_test_bank $ctrl
 set_property -dict [list CONFIG.PAIRS $pairs CONFIG.BANK_ID $bank] [get_bd_cells $ctrl]
 create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 $rst
 connect_bd_net [get_bd_ports reset] [get_bd_pins $rst/ext_reset_in]
 connect_bd_net [get_bd_pins const0/dout] [get_bd_pins $rst/aux_reset_in] [get_bd_pins $rst/mb_debug_sys_rst]
 connect_bd_net [get_bd_pins CLOCK_156M25/locked] [get_bd_pins $rst/dcm_locked]
 connect_bd_net [get_bd_pins CLOCK_156M25/clk125] [get_bd_pins $rst/slowest_sync_clk] [get_bd_pins $phy/clk125] [get_bd_pins $ctrl/clk]
 connect_bd_net [get_bd_pins CLOCK_156M25/clk500] [get_bd_pins $phy/clk500]
 connect_bd_net [get_bd_pins CLOCK_156M25/clk200] [get_bd_pins $phy/refclk200]
 connect_bd_net [get_bd_pins $rst/peripheral_reset] [get_bd_pins $phy/reset] [get_bd_pins $ctrl/reset]
 connect_bd_net [get_bd_pins $phy/calibration_ready] [get_bd_pins $ctrl/calibration_ready]
 foreach pin {data_out_from_device data_in_to_device tristate bitslip delay_load delay_value} {
  connect_bd_net [get_bd_pins $phy/$pin] [get_bd_pins $ctrl/$pin]
 }
 foreach pin {data_to_and_from_pins_p data_to_and_from_pins_n} {
  make_bd_pins_external [get_bd_pins $phy/$pin]
  set_property name b${bank}_${pin} [get_bd_ports ${pin}_0]
 }
 connect_bd_net [get_bd_pins $ctrl/test_pass] [get_bd_pins RESULT_PASS_FAIL/pass$bank]
 connect_bd_net [get_bd_pins $ctrl/failed_sticky] [get_bd_pins RESULT_PASS_FAIL/fail$bank]
 connect_bd_net [get_bd_pins $ctrl/heartbeat] [get_bd_pins RESULT_PASS_FAIL/hb$bank]
 create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 $vio
 set_property -dict [list CONFIG.C_NUM_PROBE_IN 8 CONFIG.C_NUM_PROBE_OUT 4 CONFIG.C_PROBE_IN0_WIDTH 128 \
  CONFIG.C_PROBE_IN1_WIDTH 64 CONFIG.C_PROBE_IN2_WIDTH 64 CONFIG.C_PROBE_IN3_WIDTH 64 CONFIG.C_PROBE_IN4_WIDTH 64 \
  CONFIG.C_PROBE_IN5_WIDTH 32 CONFIG.C_PROBE_IN6_WIDTH 32 CONFIG.C_PROBE_IN7_WIDTH $pairs CONFIG.C_PROBE_OUT0_INIT_VAL 0x1] [get_bd_cells $vio]
 connect_bd_net [get_bd_pins CLOCK_156M25/clk125] [get_bd_pins $vio/clk]
 foreach pin {run_enable restart clear_errors inject_error} index {0 1 2 3} {
  connect_bd_net [get_bd_pins $vio/probe_out$index] [get_bd_pins $ctrl/$pin]
 }
 foreach pin {monitor bit_errors_forward bit_errors_reverse checked_bits_forward checked_bits_reverse completed_forward completed_reverse compare_locked} index {0 1 2 3 4 5 6 7} {
  connect_bd_net [get_bd_pins $ctrl/$pin] [get_bd_pins $vio/probe_in$index]
 }
 create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 $ila
 set_property CONFIG.C_MONITOR_TYPE Native [get_bd_cells $ila]
 set_property -dict [list CONFIG.C_NUM_OF_PROBES 9 CONFIG.C_DATA_DEPTH 1024 CONFIG.C_PROBE0_WIDTH [expr {$pairs*16}] \
  CONFIG.C_PROBE1_WIDTH [expr {$pairs*16}] CONFIG.C_PROBE2_WIDTH [expr {$pairs*2}] CONFIG.C_PROBE3_WIDTH [expr {$pairs*2}] \
  CONFIG.C_PROBE4_WIDTH 4 CONFIG.C_PROBE5_WIDTH $pairs CONFIG.C_PROBE6_WIDTH [expr {$pairs*10}] \
  CONFIG.C_PROBE7_WIDTH $pairs CONFIG.C_PROBE8_WIDTH $pairs] [get_bd_cells $ila]
 connect_bd_net [get_bd_pins CLOCK_156M25/clk125] [get_bd_pins $ila/clk]
 foreach pin {data_out_from_device data_in_to_device bitslip tristate state_debug error_mask delay_value aligned compare_locked} index {0 1 2 3 4 5 6 7 8} {
  connect_bd_net [get_bd_pins $ctrl/$pin] [get_bd_pins $ila/probe$index]
 }
}
regenerate_bd_layout
validate_bd_design
save_bd_design
set bd [get_files */lvds_vhdl_bd.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
make_wrapper -files $bd -top
add_files -norecurse $root/build/project/lvds62_vhdl.gen/sources_1/bd/lvds_vhdl_bd/hdl/lvds_vhdl_bd_wrapper.vhd
set_property top lvds_vhdl_bd_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse $root/constraints/timing.xdc
add_files -fileset constrs_1 -norecurse $root/constraints/logic_exceptions.xdc
set_property PROCESSING_ORDER LATE [get_files logic_exceptions.xdc]
set_property USED_IN_SYNTHESIS false [get_files logic_exceptions.xdc]
update_compile_order -fileset sources_1
set f [open $root/build/BD_VALIDATION.txt w]
puts $f "PASSED: VHDL design and VHDL wrapper, 62 inout differential pairs, 156.25MHz reference, MMCM 500/125/200MHz, automatic alignment/comparison and PASS/FAIL, 4 VIO and 3 ILA."
close $f
close_project
exit
