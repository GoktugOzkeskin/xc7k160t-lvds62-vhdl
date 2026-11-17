set root [file normalize [file join [file dirname [info script]] ..]]
open_project $root/build/project/lvds62_vhdl.xpr
if {[llength [get_files -quiet logic_exceptions.xdc]]==0} {
 add_files -fileset constrs_1 -norecurse $root/constraints/logic_exceptions.xdc
 set_property PROCESSING_ORDER LATE [get_files logic_exceptions.xdc]
 set_property USED_IN_SYNTHESIS false [get_files logic_exceptions.xdc]
}
file mkdir $root/build/reports
set_param general.maxThreads 4
synth_design -top lvds_vhdl_bd_wrapper -part xc7k160tfbg676-1
report_utilization -file $root/build/reports/utilization_synth.txt
report_clocks -file $root/build/reports/clocks.txt
write_checkpoint -force $root/build/reports/synth.dcp
report_timing_summary -file $root/build/reports/timing_synth.txt
report_cdc -file $root/build/reports/cdc_synth.txt
set f [open $root/build/reports/cells.txt w]
foreach c [get_cells -hier -filter {REF_NAME =~ *ISERDES* || REF_NAME =~ *OSERDES* || REF_NAME =~ *IDELAY* || NAME =~ *sync*}] {puts $f "$c [get_property REF_NAME $c]"}
close $f
close_project
exit
