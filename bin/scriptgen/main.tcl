if {[info exists ::env(GRLIB)]} {
	set GRLIB $::env(GRLIB)
}

  set script_path [ file dirname [ file normalize [ info script ] ] ]
  source "$script_path/tcl_dict.tcl"


source "scriptgenwork/tools.tcl"
source "scriptgenwork/extrafiles.tcl"

source "$GRLIB/bin/scriptgen/database.tcl"

close [open "scriptgendone" w]
