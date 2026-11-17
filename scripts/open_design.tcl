set root [file normalize [file join [file dirname [info script]] ..]]
open_project $root/build/project/lvds62_vhdl.xpr
if {[llength [get_files -quiet logic_exceptions.xdc]]==0} {
 add_files -fileset constrs_1 -norecurse $root/constraints/logic_exceptions.xdc
 set_property PROCESSING_ORDER LATE [get_files logic_exceptions.xdc]
 set_property USED_IN_SYNTHESIS false [get_files logic_exceptions.xdc]
}
open_bd_design $root/build/project/lvds62_vhdl.srcs/sources_1/bd/lvds_vhdl_bd/lvds_vhdl_bd.bd
regenerate_bd_layout
