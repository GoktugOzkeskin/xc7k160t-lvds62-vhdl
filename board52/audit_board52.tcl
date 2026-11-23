set root [file normalize [file join [file dirname [info script]] ..]]
set build $root/build/board52
set_param general.maxThreads 2
open_checkpoint $build/reports/routed.dcp
set f [open $root/board52/logic_exceptions.xdc w]
puts $f "# Scoped exceptions generated and verified from board52 routed hierarchy."
puts $f "# First CDC stage only; second stages remain timed. Own-pad readback is unused during TX."
set sync_count 0
set timed_sync 0
foreach first [get_cells -hier -regexp {.*/(ready_meta_reg\[[0-2]\]|root_meta_reg\[[0-6]\]|ready_sync_reg\[0\])$}] {
 if {![string match */test52/ready_sync_reg* $first] && ![regexp {/(ready_meta_reg|root_meta_reg)} $first]} {continue}
 incr sync_count
 puts $f [format {set_false_path -to [get_pins {%s/D}]} $first]
 if {[string match */test52/* $first]} {
  set second [string map {{ready_sync_reg[0]} {ready_sync_reg[1]}} $first]
 } else {set second [string map {ready_meta_reg ready_sync_reg root_meta_reg root_sync_reg} $first]}
 set to [get_cells -hier -filter "NAME == $second"]
 set paths [get_timing_paths -quiet -from $first -to $to -max_paths 1]
 if {[llength $paths]==1 && [get_property SLACK $paths] ne "" && [get_property EXCEPTION $paths] ne "False Path"} {incr timed_sync}
}
set lanes 0
set false_lanes 0
foreach tx [get_cells -hier -filter {REF_NAME == OSERDESE2}] {
 set rxname [regsub {u_oserdes$} $tx u_iserdes]
 set bufname [regsub {u_oserdes$} $tx u_iobuf/OBUFTDS]
 set buf [get_cells -hier -filter "NAME == $bufname"]
 set rx [get_cells -hier -filter "NAME == $rxname"]
 puts $f [format {set_false_path -through [get_pins {%s/O %s/OB}] -to [get_pins {%s/DDLY}]} $bufname $bufname $rxname]
 incr lanes
 set paths [get_timing_paths -quiet -through [get_pins -of_objects $buf -filter {REF_PIN_NAME == O || REF_PIN_NAME == OB}] -to [get_pins -of_objects $rx -filter {REF_PIN_NAME == DDLY}] -max_paths 1]
 if {[llength $paths]==1 && [get_property EXCEPTION $paths] eq "False Path" && [get_property SLACK $paths] eq ""} {incr false_lanes}
}
close $f
set f [open $build/reports/exception_audit.txt w]
puts $f "Same-pad lanes: $lanes, verified False Path: $false_lanes (expected 52/52)."
puts $f "CDC first stages: $sync_count; second stages still timed: $timed_sync (expected 11/11)."
puts $f "Opposite cable endpoints and payload comparator paths are not exempted."
close $f
if {$lanes!=52 || $false_lanes!=52 || $sync_count!=11 || $timed_sync!=11} {error "Board52 exception audit failed"}
close_project
open_project $build/project/lvds52.xpr
if {[llength [get_files -quiet logic_exceptions.xdc]]==0} {add_files -fileset constrs_1 $root/board52/logic_exceptions.xdc}
set_property PROCESSING_ORDER LATE [get_files logic_exceptions.xdc]
set_property USED_IN_SYNTHESIS false [get_files logic_exceptions.xdc]
close_project
puts "PASS: board52 exception scope audit and persistent project XDC"
exit
