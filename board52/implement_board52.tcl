set root [file normalize [file join [file dirname [info script]] ..]]
set build $root/build/board52
file mkdir $build/reports
set_param general.maxThreads 2
if {[llength $argv]>0 && [lindex $argv 0] eq "resume"} {
 open_checkpoint $build/reports/synth.dcp
} else {
 open_project $build/project/lvds52.xpr
 synth_design -top lvds52_bd_wrapper -part xc7k160tfbg676-1
}
set pinlog [open $build/reports/pin_audit.txt w]
set used {}
foreach port [get_ports] {
 set pin [get_property PACKAGE_PIN $port]
 if {$pin eq ""} {error "Unconstrained board port $port"}
 if {[lsearch -exact $used $pin]>=0} {error "Duplicated package pin $pin"}
 lappend used $pin
 puts $pinlog "$port $pin [get_property PIN_FUNC [get_package_pins $pin]] [get_property IOSTANDARD $port]"
}
close $pinlog
if {[llength $used]!=107} {error "Expected 107 constrained physical ports; got [llength $used]"}
# First-stage D pins only. reset_pipe is intentionally not exempted wholesale.
set cdc [get_cells -hier -regexp {.*/(ready_meta_reg\[[0-2]\]|root_meta_reg\[[0-6]\]|ready_sync_reg\[0\])$}]
# Includes test52's ready_sync[0] but not the core ready_sync[0], which is second-stage.
set cdc_exact {}
foreach c $cdc {
 if {[string match */test52/ready_sync_reg* $c] || [regexp {/(ready_meta_reg|root_meta_reg)} $c]} {lappend cdc_exact $c}
}
if {[llength $cdc_exact]!=11} {error "Expected 11 first-stage CDC cells, found [llength $cdc_exact]: $cdc_exact"}
set_false_path -to [get_pins -of_objects $cdc_exact -filter {REF_PIN_NAME == D}]
set count 0
foreach tx [get_cells -hier -filter {REF_NAME == OSERDESE2}] {
 set rxname [regsub {u_oserdes$} $tx u_iserdes]
 set bufname [regsub {u_oserdes$} $tx u_iobuf/OBUFTDS]
 set rx [get_cells -hier -filter "NAME == $rxname"]
 set buf [get_cells -hier -filter "NAME == $bufname"]
 if {[llength $rx]!=1 || [llength $buf]!=1} {error "Same-pad primitive pair missing: $tx"}
 set_false_path -through [get_pins -of_objects $buf -filter {REF_PIN_NAME == O || REF_PIN_NAME == OB}] -to [get_pins -of_objects $rx -filter {REF_PIN_NAME == DDLY}]
 incr count
}
if {$count!=52} {error "Expected 52 scoped same-pad exceptions; got $count"}
report_utilization -file $build/reports/utilization_synth.txt
report_clocks -file $build/reports/clocks.txt
report_exceptions -file $build/reports/exceptions.txt
write_checkpoint -force $build/reports/synth.dcp
opt_design
place_design -directive Explore
report_timing_summary -report_unconstrained -max_paths 10 -file $build/reports/timing_placed.txt
write_checkpoint -force $build/reports/placed.dcp
phys_opt_design -directive Explore
route_design -directive Explore
report_route_status -file $build/reports/route_status.txt
report_timing_summary -report_unconstrained -max_paths 10 -file $build/reports/timing_routed.txt
report_drc -file $build/reports/drc.txt
report_cdc -details -file $build/reports/cdc.txt
report_bus_skew -file $build/reports/bus_skew.txt
report_utilization -file $build/reports/utilization_routed.txt
write_checkpoint -force $build/reports/routed.dcp
set f [open $build/IMPLEMENTATION_FINISHED.txt w]
puts $f "Implementation finished. Read timing_routed.txt and drc.txt for qualification; no bitstream generated."
close $f
close_project
exit
