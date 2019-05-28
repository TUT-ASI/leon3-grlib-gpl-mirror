proc nanoxplore_create_tool {filetree fileinfo} {
    global GRLIB
    source "$GRLIB/bin/scriptgen/filebuild/nanoxplore_nanoxmap.tcl"
    source "$GRLIB/bin/scriptgen/filebuild/nanoxplore_nanoxpython.tcl"
    create_nanoxplore_nanoxmap
    create_nanoxplore_nanoxpython
    foreach k [dict keys $filetree] {
	set ktree [dict get $filetree $k]
	set kinfo [dict get $fileinfo $k]
	foreach l [dict keys $ktree] {
	    set filelist [dict get $ktree $l]
	    foreach f $filelist {
		set finfo [dict get $fileinfo $f]
		append_file_nanoxplore_nanoxmap $f $finfo
		#No need of this procedure for nanoxpython file generation.
		#append_file_nanoxplore_nanoxpython $f $finfo 
	    }
	}
    }
    eof_nanoxplore_nanoxmap
    eof_nanoxplore_nanoxpython
}

nanoxplore_create_tool $filetree $fileinfo
return
