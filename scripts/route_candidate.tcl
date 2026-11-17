# Resource/timing experiment only; the user board pinout is unknown.
set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/build/reports/synth.dcp
set_param general.maxThreads 4
set cdc [get_cells -hier -regexp {.*/(sync1_reg\[[0-8]\]|lock_sync_reg\[0\]|ready_sync_reg\[0\])$}]
if {[llength $cdc] != 13} {error "Expected 13 first-stage CDC registers; found [llength $cdc]: $cdc"}
set_false_path -to [get_pins -of_objects $cdc -filter {REF_PIN_NAME == D}]
set count 0
foreach tx [get_cells -hier -filter {REF_NAME == OSERDESE2}] {
 set rx_name [regsub {u_oserdes$} $tx u_iserdes]
 set rx [get_cells -hier -filter "NAME == $rx_name"]
 if {[llength $rx]!=1} {error "Missing corresponding same-pad RX: $tx"}
 # The receiver on the SAME physical pad is ignored while that pad transmits.
 # The active receiver at the opposite end of the cable is NOT exempted.
 set buf_name [regsub {u_oserdes$} $tx u_iobuf/OBUFTDS]
 set buf [get_cells -hier -filter "NAME == $buf_name"]
 if {[llength $buf]!=1} {error "Missing same-pad output buffer: $buf_name"}
 set_false_path -through [get_pins -of_objects $buf -filter {REF_PIN_NAME == O || REF_PIN_NAME == OB}] -to [get_pins -of_objects $rx -filter {REF_PIN_NAME == DDLY}]
 incr count
}
if {$count!=62} {error "Expected 62 same-pad paths, got $count"}
report_exceptions -file $root/build/reports/exceptions_candidate.txt
source $root/constraints/verification_only_pins.tcl
opt_design
place_design -directive Explore
report_timing_summary -report_unconstrained -max_paths 10 -file $root/build/reports/timing_placed_candidate.txt
write_checkpoint -force $root/build/reports/placed_candidate.dcp
phys_opt_design -directive Explore
route_design -directive Explore
report_timing_summary -report_unconstrained -max_paths 10 -file $root/build/reports/timing_routed_candidate.txt
report_drc -file $root/build/reports/drc_routed_candidate.txt
report_cdc -details -file $root/build/reports/cdc_routed_candidate.txt
report_bus_skew -file $root/build/reports/bus_skew_routed_candidate.txt
report_utilization -file $root/build/reports/utilization_routed_candidate.txt
write_checkpoint -force $root/build/reports/routed_candidate.dcp
exit
