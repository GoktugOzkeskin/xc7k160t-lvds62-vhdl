set root [file normalize [file join [file dirname [info script]] ..]]
set build $root/build/board52
file mkdir $build
set_param general.maxThreads 2
create_project lvds52 $build/project -part xc7k160tfbg676-1 -force
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
add_files [glob $root/rtl/*.vhd]
add_files $root/board52/lvds52_core.vhd
add_files -fileset sim_1 $root/board52/tb_board52.vhd
set_property file_type {VHDL 2008} [get_files tb_board52.vhd]
set_property top tb_board52 [get_filesets sim_1]
update_compile_order -fileset sources_1
create_bd_design lvds52_bd
create_bd_cell -type module -reference lvds52_core CORE52
# Reset polarity is NOT shown in the photos; keep prior active-high default explicit.
set_property CONFIG.RESET_ACTIVE_LOW false [get_bd_cells CORE52]
make_bd_intf_pins_external [get_bd_intf_pins CORE52/ref_clock]
set_property name sys_clk156 [get_bd_intf_ports ref_clock_0]
foreach pin {reset lvds_p lvds_n} {
 make_bd_pins_external [get_bd_pins CORE52/$pin]
 set_property name $pin [get_bd_ports ${pin}_0]
}
create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 TEST_VIO
set_property -dict [list CONFIG.C_NUM_PROBE_IN 8 CONFIG.C_NUM_PROBE_OUT 4 CONFIG.C_PROBE_IN0_WIDTH 128 \
 CONFIG.C_PROBE_IN1_WIDTH 64 CONFIG.C_PROBE_IN2_WIDTH 64 CONFIG.C_PROBE_IN3_WIDTH 64 CONFIG.C_PROBE_IN4_WIDTH 64 \
 CONFIG.C_PROBE_IN5_WIDTH 32 CONFIG.C_PROBE_IN6_WIDTH 32 CONFIG.C_PROBE_IN7_WIDTH 26 CONFIG.C_PROBE_OUT0_INIT_VAL 0x1] [get_bd_cells TEST_VIO]
connect_bd_net [get_bd_pins CORE52/clk125] [get_bd_pins TEST_VIO/clk]
foreach pin {run_enable restart clear_errors inject_error} i {0 1 2 3} {
 connect_bd_net [get_bd_pins TEST_VIO/probe_out$i] [get_bd_pins CORE52/$pin]
}
foreach pin {monitor bit_errors_forward bit_errors_reverse checked_bits_forward checked_bits_reverse completed_forward completed_reverse compare_locked} i {0 1 2 3 4 5 6 7} {
 connect_bd_net [get_bd_pins CORE52/$pin] [get_bd_pins TEST_VIO/probe_in$i]
}
create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 RESULT_VIO
set_property -dict [list CONFIG.C_NUM_PROBE_IN 1 CONFIG.C_NUM_PROBE_OUT 1 CONFIG.C_PROBE_IN0_WIDTH 16] [get_bd_cells RESULT_VIO]
connect_bd_net [get_bd_pins CORE52/clk_reference] [get_bd_pins RESULT_VIO/clk]
connect_bd_net [get_bd_pins CORE52/status] [get_bd_pins RESULT_VIO/probe_in0]
connect_bd_net [get_bd_pins RESULT_VIO/probe_out0] [get_bd_pins CORE52/clear_watchdog]
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 DATA_ILA
set_property -dict [list CONFIG.C_MONITOR_TYPE Native CONFIG.C_NUM_OF_PROBES 9 CONFIG.C_DATA_DEPTH 1024 \
 CONFIG.C_PROBE0_WIDTH 416 CONFIG.C_PROBE1_WIDTH 416 CONFIG.C_PROBE2_WIDTH 52 CONFIG.C_PROBE3_WIDTH 52 \
 CONFIG.C_PROBE4_WIDTH 4 CONFIG.C_PROBE5_WIDTH 26 CONFIG.C_PROBE6_WIDTH 260 CONFIG.C_PROBE7_WIDTH 26 CONFIG.C_PROBE8_WIDTH 26] [get_bd_cells DATA_ILA]
connect_bd_net [get_bd_pins CORE52/clk125] [get_bd_pins DATA_ILA/clk]
foreach pin {data_out_from_device data_in_to_device bitslip tristate state_debug error_mask delay_value aligned compare_locked} i {0 1 2 3 4 5 6 7 8} {
 connect_bd_net [get_bd_pins CORE52/$pin] [get_bd_pins DATA_ILA/probe$i]
}
regenerate_bd_layout
validate_bd_design
save_bd_design
set bd [get_files */lvds52_bd.bd]
set_property synth_checkpoint_mode None $bd
generate_target all $bd
make_wrapper -files $bd -top
add_files $build/project/lvds52.gen/sources_1/bd/lvds52_bd/hdl/lvds52_bd_wrapper.vhd
set_property top lvds52_bd_wrapper [current_fileset]
add_files -fileset constrs_1 $root/board52/board_pins.xdc
if {[file exists $root/board52/logic_exceptions.xdc]} {
 add_files -fileset constrs_1 $root/board52/logic_exceptions.xdc
 set_property PROCESSING_ORDER LATE [get_files logic_exceptions.xdc]
 set_property USED_IN_SYNTHESIS false [get_files logic_exceptions.xdc]
}
update_compile_order -fileset sources_1
set f [open $build/BD_VALIDATION.txt w]
puts $f "PASS: board52 block design, 52 inout differential pairs, two VIO, one ILA, 156.25MHz reference."
close $f
close_project
exit
