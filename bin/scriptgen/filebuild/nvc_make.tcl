set make_nvc_contents ""
proc create_nvc_make {} {
	upvar make_nvc_contents mgc
	append mgc "# Import files in libraries\n"
	append mgc ".PHONY: nvc-import\n"
	append mgc "nvc-import:\n"
	append mgc "\tmkdir -p nvc"
	return
}

proc append_lib_nvc_make {k kinfo} {
	upvar make_nvc_contents mgc
	set bn [dict get $kinfo bn]
#	append mgc "\n\tmkdir -p gnu/$bn"
	return
}

proc append_file_nvc_make {f finfo} {
	set i [dict get $finfo i]
	set bn [dict get $finfo bn]
	switch $i {
		"vhdlp1735" {
			return
		}
		"vhdlnx" {
			return
		}
		"vhdlmtie" {
			return
		}
		"vhdlsynpe" {
			return
		}
		"vhdldce" {
			return
		}
		"vhdlcdse" {
			return
		}
		"vhdlxile" {
			return
		}
		"vhdlxise" {
			return
		}
		"vhdlfpro" {
			return
		}
		"vhdlprec" {
			return
		}
		"vhdlsyn" {
			global NVC NVCAOPT NVCOPT
			upvar make_nvc_contents mgc
			append mgc "\n\t$NVC $NVCOPT --work=$bn:nvc/$bn -L nvc -a $NVCAOPT $f"
			return
		}
		"vlogsyn" {
			global NVC NVCOPT NVCVOPT
			upvar make_nvc_contents mgc
	    set l [dict get $finfo l]
      if {[string equal $l "local"] && [string equal $bn "work"] } {
			  append mgc "\n\t$NVC $NVCOPT --work=$bn:nvc/$bn -L nvc -a $NVCVOPT $f"
	    } else {
	      set k [dict get $finfo k]
			  append mgc "\n\t$NVC $NVCOPT --work=$bn:nvc/$bn -L nvc -a $NVCVOPT -I $k/$l $f"
      }
			return
		}
		"svlogsyn" {
			return
		}
		"vhdlsim" {
			global NVC NVCOPT NVCAOPT
			upvar make_nvc_contents mgc
			append mgc "\n\t$NVC $NVCOPT --work=$bn:nvc/$bn -L nvc -a $NVCAOPT $f"
			return
		}
		"vlogsim" {
			global NVC NVCOPT NVCVOPT
			upvar make_nvc_contents mgc
			append mgc "\n\t$NVC $NVCOPT --work=$bn:nvc/$bn -L nvc -a $NVCVOPT $f"
			return
		}
		"svlogsim" {
			return
		}
	}
	return
}

proc eof_nvc_make {} {
	upvar make_nvc_contents mgc
	set nvcfile [open "make.nvc" w]
	puts $nvcfile $mgc
	close $nvcfile
	return
}
