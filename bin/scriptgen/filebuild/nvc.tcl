proc nvc_create_tool {filetree fileinfo} {
	global GRLIB
	source "$GRLIB/bin/scriptgen/filebuild/nvc_make.tcl"
	create_nvc_make
	foreach k [dict keys $filetree] {
		set ktree [dict get $filetree $k]
		set kinfo [dict get $fileinfo $k]
		set bn [dict get $kinfo bn]
		append_lib_nvc_make $k $kinfo
		foreach l [dict keys $ktree] {
			set filelist [dict get $ktree $l]
			foreach f $filelist {
				set finfo [dict get $fileinfo $f]
				append_file_nvc_make $f $finfo
			}
		}
	}
	eof_nvc_make
}

nvc_create_tool $filetree $fileinfo
return
