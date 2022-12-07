proc lattice_create_tool {filetree fileinfo} {
	global GRLIB
	source "$GRLIB/bin/scriptgen/filebuild/lattice_diamond_top_lct.tcl"
	source "$GRLIB/bin/scriptgen/filebuild/lattice_diamond_top_ldf.tcl"
	source "$GRLIB/bin/scriptgen/filebuild/lattice_diamond_top_syn.tcl"
	if { [ file exists "$GRLIB/bin/scriptgen/filebuild/lattice_top_radiant_tcl.tcl" ] } {
		source "$GRLIB/bin/scriptgen/filebuild/lattice_top_radiant_tcl.tcl"
	}

	if {[expr ![string equal [glob -nocomplain -type d lattice] lattice ] ] } {
		file mkdir lattice
	}

	create_lattice_diamond_top_ldf 
	create_lattice_diamond_top_lct 
	create_lattice_diamond_top_syn 
	if { [ file exists "$GRLIB/bin/scriptgen/filebuild/lattice_top_radiant_tcl.tcl" ] } {
		create_lattice_top_radiant_tcl
	}

	foreach k [dict keys $filetree] {
		set ktree [dict get $filetree $k]
		set kinfo [dict get $fileinfo $k]
		foreach l [dict keys $ktree] {
			set filelist [dict get $ktree $l]
			foreach f $filelist {
				set finfo [dict get $fileinfo $f]
				append_file_lattice_diamond_top_ldf $f $finfo 
				if { [ file exists "$GRLIB/bin/scriptgen/filebuild/lattice_top_radiant_tcl.tcl" ] } {
					append_file_lattice_top_radiant_tcl $f $finfo
				}
			}
		}
	}
	eof_lattice_diamond_top_ldf 
	if { [ file exists "$GRLIB/bin/scriptgen/filebuild/lattice_top_radiant_tcl.tcl" ] } {
		eof_lattice_top_radiant_tcl
	}
}

lattice_create_tool $filetree $fileinfo
return
