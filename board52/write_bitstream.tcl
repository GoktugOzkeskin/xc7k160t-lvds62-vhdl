set root [file normalize [file join [file dirname [info script]] ..]]
set build $root/build/board52
set target $build/bitstream
file mkdir $target
set_param general.maxThreads 2
open_checkpoint $build/reports/routed.dcp
if {[get_property PART [current_design]] ne "xc7k160tfbg676-1"} {error "Unexpected target part"}
if {[llength [get_ports]]!=107 || [llength [get_cells -hier -filter {REF_NAME == OSERDESE2}]]!=52} {
 error "Expected board52 routed design (107 ports / 52 serializers)"
}
report_route_status -file $target/route_status.txt
report_drc -ruledeck bitstream_checks -file $target/bitstream_drc.txt
set violations [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $violations]>0} {error "Bitstream DRC contains errors: $violations"}
# Keep all board/configuration assumptions visible; no DRC severity overrides.
# CFGBVS/CONFIG_VOLTAGE and reset polarity still require board-level confirmation.
write_debug_probes -force $target/lvds52_board.ltx
write_bitstream -force $target/lvds52_board.bit
if {![file exists $target/lvds52_board.bit] || [file size $target/lvds52_board.bit]==0} {error "Bitstream output missing"}
set f [open $target/RESULT.txt w]
puts $f "PASS: board52 .bit and .ltx generated from fully routed XC7K160T-FBG676-1 checkpoint."
puts $f "No hardware connection/programming performed. No DRC severity overrides."
puts $f "Board supply, reset polarity, termination and configuration voltage remain unverified."
close $f
close_project
exit
