set radiant_contents ""
set radiant_build ""
set radiant_ips ""
proc create_lattice_top_radiant_tcl {} {
	global TOP DEVICE GRLIB_LATTICE_RADIANT_PERFORMANCE GRLIB_LATTICE_RADIANT_SYNTHESIS
  upvar radiant_contents rc
  upvar radiant_ips ri

	append rc "# Lattice Radiant project creation script for GRLIB"
	append rc "\n# Create a new project"
	append rc "\nprj_create -name \"$TOP\_radiant\" -impl \"$TOP\_radiant_impl_1\" -dev $DEVICE -performance \"$GRLIB_LATTICE_RADIANT_PERFORMANCE\" -impl_dir $TOP\_radiant_impl_1_dir -synthesis \"$GRLIB_LATTICE_RADIANT_SYNTHESIS\""
	append rc "\n# Add files for simulation and synthesis"

  append ri "# Lattice Radiant IPs generation script\n"

	return
}


proc append_file_lattice_top_radiant_tcl {f finfo} {
	global GRLIB_LATTICE_RADIANT GRLIB_LATTICE_RADIANT_PERFORMANCE PART PACKAGE ARCHITECTURE
	set i [dict get $finfo i]
	set bn [dict get $finfo bn]
	set q [dict get $finfo q]
	set fattr [dict get $finfo fattr]
	switch $i {
		"vhdlp1735" {
			upvar radiant_contents rc
			append rc "\nprj_add_source $f -work $bn"
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
			upvar radiant_contents rc
			append rc "\nprj_add_source $f -work $bn"
			return
		}
		"vlogsyn" {
			upvar radiant_contents rc
			append rc "\nprj_add_source $f -work $bn"
			return
		}
		"svlogsyn" {
			upvar radiant_contents rc
			append rc "\nprj_add_source $f -work $bn"
			return
		}
		"latticeipcfg" {
      upvar radiant_ips ri
      upvar radiant_contents rc
			append ri "\ntry {"
			append ri "\n\texec ipgen -o lattice_ips/$fattr/$q -ip $GRLIB_LATTICE_RADIANT/ip/$fattr -name $q -cfg lattice_ips/$fattr/$q/$q.cfg -p $PART -t $PACKAGE -sp $GRLIB_LATTICE_RADIANT_PERFORMANCE -a $ARCHITECTURE"
		  append ri "\n} on error ipgenerr {"
			append ri "\n\tputs \"IPGEN error caught:\n\$ipgenerr\"\n}"
			append rc "\nprj_add_source lattice_ips/$fattr/$q/$q.ipx -work $bn"
			return
		}
		"vhdlsim" {
			upvar radiant_contents rc
			append rc "\nprj_add_source -simulate_only $f -work $bn"
			return
		}
		"vlogsim" {
			upvar radiant_contents rc
			append rc "\nprj_add_source -simulate_only $f -work $bn"
			return
		}
		"svlogsim" {
			upvar rc
			append rc "\nprj_add_source -simulate_only $f -work $bn"
			return
		}
	}
	return
}

proc eof_lattice_top_radiant_tcl {} {
	global TOP PDC LDC SDCFILE FDC GRLIB_LATTICE_RADIANT_SYNTHESIS
	upvar radiant_contents rc
  upvar radiant_build rb
  upvar radiant_ips ri


  append ri "\nexit\n"
	set genipsfile [open "$TOP\_radiant_gen_ips.tcl" w]
	puts $genipsfile $ri
  close $genipsfile

	append rc "\n\n# Add constraint files"

	append rc "\nprj_add_source $PDC"

	if {[string equal $GRLIB_LATTICE_RADIANT_SYNTHESIS "lse"]} {
		append rc "\nprj_add_source $LDC"
        } else {
		append rc "\nprj_add_source $SDCFILE"
		if {![string equal $FDC ""]} {
			append rc "\nprj_add_source $FDC"
                }
	}
	append rc "\n\n# Set top level entity"
	append rc "\nprj_set_impl_opt -impl \"$TOP\_radiant_impl_1\" \"top\" \"$TOP\""

	append rc "\n\nprj_save"
	append rc "\nprj_close"
	append rc "\nexit\n"

	set projfile [open "$TOP\_radiant.tcl" w]
	puts $projfile $rc
	close $projfile

	append rb "# Building commands"
	append rb "\nprj_open $TOP\_radiant.rdf\n"
	append rb "\nprj_run_synthesis\n"
	append rb "\nprj_run_map\n"
	append rb "\nprj_run_par\n"
	append rb "\nprj_run_bitstream\n"
	append rb "\nprj_close"
	append rb "\nexit\n"
	set buildfile [open "$TOP\_radiant_build.tcl" w]
	puts $buildfile $rb
	close $buildfile

	return
}
