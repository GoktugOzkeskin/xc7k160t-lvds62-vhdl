set root [file normalize [file join [file dirname [info script]] ..]]
set build $root/build/board52
open_project $build/project/lvds52.xpr
archive_project -force -include_config_settings $build/LVDS52_BOARD_VIVADO_PROJECT.zip
close_project
exit
