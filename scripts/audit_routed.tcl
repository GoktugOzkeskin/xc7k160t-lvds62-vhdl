set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $root/build/reports/routed_candidate.dcp
set matches 0
set remaining 0
set false_pairs 0
foreach tx [get_cells -hier -filter {REF_NAME == OSERDESE2}] {
 set rx_name [regsub {u_oserdes$} $tx u_iserdes]
 set buf_name [regsub {u_oserdes$} $tx u_iobuf/OBUFTDS]
 set rx [get_cells -hier -filter "NAME == $rx_name"]
 set buf [get_cells -hier -filter "NAME == $buf_name"]
 incr matches
 set paths [get_timing_paths -quiet -through [get_pins -of_objects $buf -filter {REF_PIN_NAME == O || REF_PIN_NAME == OB}] -to [get_pins -of_objects $rx -filter {REF_PIN_NAME == DDLY}] -max_paths 1]
 # An explicitly queried false path is returned as an object with empty SLACK.
 # Counting returned objects alone incorrectly treats these as timed paths.
 if {[llength $paths]!=1} {error "Expected a self-readback path for $tx"}
 if {[get_property EXCEPTION $paths] eq "False Path" && [get_property SLACK $paths] eq ""} {incr false_pairs} else {incr remaining}
}
set timed_sync 0
foreach first [get_cells -hier -regexp {.*/(sync1_reg\[[0-8]\]|lock_sync_reg\[0\]|ready_sync_reg\[0\])$}] {
 set second [string map {sync1_reg sync2_reg {lock_sync_reg[0]} {lock_sync_reg[1]} {ready_sync_reg[0]} {ready_sync_reg[1]}} $first]
 set target [get_cells -hier -filter "NAME == $second"]
 set p [get_timing_paths -quiet -from $first -to $target -max_paths 1]
 if {[llength $p]==1 && [get_property SLACK $p] ne "" && [get_property EXCEPTION $p] ne "False Path"} {incr timed_sync}
}
set f [open $root/build/reports/exception_audit.txt w]
puts $f "Same-pad output-buffer to own DDLY pairs: $matches (expected 62)"
puts $f "Remaining timed unused self-readback paths: $remaining (expected 0)"
puts $f "Explicitly verified False Path objects with empty SLACK: $false_pairs (expected 62)"
puts $f "First-to-second synchronizer stages still timed: $timed_sync (expected 13)"
puts $f "External cable counterpart receivers and normal payload comparison paths are not covered by the same-pad exception."
close $f
if {$matches!=62 || $remaining!=0 || $false_pairs!=62 || $timed_sync!=13} {error "Scoped exception audit FAILED"}
puts "PASS: scoped exceptions, all 13 second stages remain timed"
exit
