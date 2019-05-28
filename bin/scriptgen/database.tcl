if { [catch {source scriptgen_variable_values.tcl}] } {
    puts stderr "File scriptgen_variable_values.tcl hasn't been generated"
    puts stderr "\n"
}

#Enables wildcards in lsearch
proc lsearchmatch {list pattern} {
    set i 0
    foreach a $list {
        if {[string match $a $pattern]} {
            return $i
        }
        incr i
    }
    return -1
}

# Return the value of an attribute in an attribute list. If the attribute isn't found
# defvalue is returned.
proc getattribute {attribute attributelist defvalue} {
    set a [regexp -inline $attribute=\\S+ $attributelist]
    if {[string equal $a ""]} {
        set a $defvalue
    } else {
        set a [string range $a [expr {[string length $attribute]+1}] end]
    }
    return $a
}

#Trims entries in a list
proc listtrim {inputlist} {
    set newlist [list]
    foreach listentry $inputlist {
        set newentry [string trim $listentry]
        if {[expr ![expr [string equal $newentry ""] || [string equal [string index $newentry 0] "#" ] ] ] } {
            lappend newlist $newentry
        }
    }
    return $newlist
}

#Extracts a list from a file for genereatefilelists
proc listinfile {filename} {
    set infofile [open $filename r]
    set info [split [read $infofile] "\n" ]
    set newinfo {}
    foreach i $info {
        if { [string first " " $i] > -1 } {
            set newinfo [concat $newinfo [split $i " "] ]
        } else {
            lappend newinfo $i
        }
    }
    set info $newinfo
    set info [listtrim $info]
    close $infofile
    return $info
}

# Convert a string into a list of name/attribute tuples
proc converttuples {information attributes} {
    set ret {}
    foreach i [regexp -all -inline {\S+} $information] {
        lappend ret [list $i $attributes]
    }
    return $ret
}

# Extracts file names and attributes from a file list
# Removes white spaces and comments
# A comment is marked with # and continues to the end of each line
# Each file with the corresponding attributes need to be on a single line
# File name and each attribute must be separated with space (or tab)
# Future expansions:
# - Allow global attributes for each file list
# - Allow white spaces in attributes by using escape
# Not tested with attributes containing characters used in tcl
proc readfilelist {filename attributes} {
    set infofile [open $filename r]
    set ret {}
    # Read the file line-by-line
    while {[gets $infofile line] >= 0} {
        # Remove everything after # on each line
        set line [regsub {[ \t]*#.*} $line ""]
        # Only add the line if it is non-empty
        if {[regexp {\S+} $line] > 0} {
            # Split each element into a list of two elements, one being the 
            # file name and the other the attributes
            set linelist [regexp -all -inline {\S+} $line]
            set linelist [concat $linelist $attributes]
            lappend ret [list [lindex $linelist 0] [lreplace $linelist 0 0]]
        }
    }
    close $infofile
    return $ret
}

proc rmvlinebreak {information} {
    if {[string length $information] > 0} {
        set information [string range $information 0 end-1]
    }
    return $information
}

#Generates the top level of the filesystem in which generetefilelists scans
proc librarieslist {} {
    global XTECHLIBS GRLIB LIBADD EXTRALIBS LIBADD
    set liblist {{grlib {}}}
    set liblist [concat $liblist [converttuples $XTECHLIBS {vhdlstd=93}]]
    set liblist [concat $liblist [readfilelist "$GRLIB/lib/libs.txt" {}]]
    foreach lib [glob -nocomplain -type f $GRLIB/lib/*/libs.txt] {
        set liblist [concat $liblist [readfilelist $lib {}]]
    }
    set extralib [expr {[string equal [glob -nocomplain "$EXTRALIBS/libs.txt"]\
                             "$EXTRALIBS/libs.txt" ] ? "$EXTRALIBS/libs.txt" : "$GRLIB/bin/libs.txt" }]
    set liblist [concat $liblist [readfilelist $extralib {}]]
    set liblist [concat $liblist [converttuples $LIBADD {}]]
    lappend liblist {work {}}
    return $liblist
}

#Scans filesystem for available libs dirs and files, then creates a dict for
#the filetree and fileinfo, a dict that stores information about each library/file.
#Files optionally added by the user, e.g. "VHDLOPTSYNFILES" are added in the
#back of the filetree/fileinfo dicts
#Also echoes to the user the settings and each library/directory scanned.
proc generatefilelists {filetree fileinfo} {
    global GRLIB EXTRALIBS DIRADD TECHLIBS XLIBSKIP GRLIB_LEON3_VERSION XDIRSKIP \
        FILEADD XFILESKIP GRLIB_CONFIG VHDLSYNFILES VHDLIPFILES VHDLOPTSYNFILES VHDLSIMFILES \
        VERILOGSYNFILES VERILOGOPTSYNFILES VERILOGSIMFILES GRLIB_SIMULATOR TOP SIMTOP
    upvar $filetree ft
    upvar $fileinfo fi

    puts "GRLIB settings:"
    puts {\n}
    puts " GRLIB = $GRLIB"
    puts {\n}
    if {[string equal $GRLIB_CONFIG "dummy"]} {
        puts " GRLIB_CONFIG is library default"
    } else {
        puts " GRLIB_CONFIG = $GRLIB_CONFIG"
    }
    puts {\n}
    puts " GRLIB_SIMULATOR = $GRLIB_SIMULATOR"
    puts {\n}
    puts " TECHLIBS setting = $TECHLIBS"
    puts {\n}
    puts " Top-level design = $TOP"
    puts {\n}
    puts " Simulation top-level = $SIMTOP"
    puts {\n}
    puts "Scanning libraries:"

    set GRLIB_real [file normalize $GRLIB]
    set GRLIB_CONFIG_real [file normalize $GRLIB_CONFIG]

    foreach j [librarieslist] {
        set lname [lindex $j 0]
        set lattr [lindex $j 1]
        set bn [exec basename $lname]
        set k "$GRLIB/lib/$lname"
        set k_real "$GRLIB_real/lib/$lname"
        set k [expr {[string equal [glob -nocomplain $k] $k] ? $k : "$EXTRALIBS/$lname"}]
        set tdirs [expr {[string equal $bn "techmap"] ? "$TECHLIBS maps" : $DIRADD}]
        if {[lsearch $XLIBSKIP $bn] < 0 && [file exists "$k/dirs.txt"]} {
            puts {\n}
            puts " $bn:"
            set libtree [dict create]
            foreach d [concat [readfilelist $k/dirs.txt $lattr] [converttuples $tdirs $lattr]] {
                set dname [lindex $d 0]
                set dattr [lindex $d 1]
                set realdir [expr {[expr [string equal $dname "leon3" ] && [expr \
                       ![string equal $GRLIB_LEON3_VERSION "3"]]] ? "leon3pkgv1v2" : $dname}]
                if {[lsearch $XDIRSKIP $dname] < 0 } {
                    set flist {}
                    foreach i {vlogsyn vhdlsyn svlogsyn vhdlmtie vhdlsynpe vhdldce\
                                   vhdlcdse vhdlxile vhdlprec vhdlprec vhdlfpro\
                                   vhdlp1735 vlogsim vhdlsim svlogsim } {
                        set m $k/$realdir/$i
                        if {[file exists $m.txt]} {
                            foreach q [concat [readfilelist $m.txt $dattr] [converttuples $FILEADD $dattr]] {
                                set fname [lindex $q 0]
                                set fattr [lindex $q 1]
                                set f $k/$realdir/$fname
                                set fx $realdir/$fname
                                set f_real $k_real/$realdir/$fname
                                if {[string equal $bn "grlib"] && \
                                        [string equal $realdir "stdlib"] && \
                                        [string equal $fname "config.vhd"] && \
                                        ![string equal $GRLIB_CONFIG "dummy"]} {
                                    set f $GRLIB_CONFIG
                                    set f_real $GRLIB_CONFIG_real
                                    set grcfg $f
                                }
                                if {[lsearch $XFILESKIP $fname] < 0  && [file exists $f]} {
                                    set conffiledict [dict create bn $bn f_real $f_real q $fname l $realdir i $i k $k fattr [join $fattr]]
                                    lappend flist $f
                                    dict set fi $f $conffiledict
                                }
                            }
                        }
                    }
                    if {[string equal [glob -nocomplain "$k/$dname" ] "$k/$dname" ] } {
                        puts "$dname"
                        dict set libtree $dname $flist
                    }
                }
            }
            set libdict [dict create k_real $k_real bn $bn]
            dict set ft $k $libtree
            dict set fi $k $libdict
        }
    }

    puts {\n}

    set flist {}
    foreach f [concat $VHDLOPTSYNFILES $VHDLSYNFILES]  {
	set info [regsub {[ \t]*#.*} $f ""]
	set infolist [regexp -all -inline {\S+} $info]
	set fname [lindex $infolist 0]
	set fattr [lreplace $infolist 0 0]
        if {[file exists $fname]} {
            lappend flist $fname
            set conffiledict [dict create bn "work" l "local" i "vhdlsyn" q $fname fattr $fattr]
            dict set fi $fname $conffiledict
        }
    }

    foreach f $VHDLSIMFILES  {
	set info [regsub {[ \t]*#.*} $f ""]
	set infolist [regexp -all -inline {\S+} $info]
	set fname [lindex $infolist 0]
	set fattr [lreplace $infolist 0 0]
        if {[file exists $fname] } {
            lappend flist $fname
            set conffiledict [dict create bn "work" l "local" i "vhdlsim" q $fname fattr $fattr]
            dict set fi $fname $conffiledict
        }
    }

    foreach f $VHDLIPFILES  {
	set info [regsub {[ \t]*#.*} $f ""]
	set infolist [regexp -all -inline {\S+} $info]
	set fname [lindex $infolist 0]
	set fattr [lreplace $infolist 0 0]
        if {[file exists $fname] } {
            lappend flist $fname
            set conffiledict [dict create bn "work" l "local" i "vhdlip" q $fname fattr $fattr]
            dict set fi $fname $conffiledict
        }
    }

    foreach f [concat $VERILOGOPTSYNFILES $VERILOGSYNFILES]  {
	set info [regsub {[ \t]*#.*} $f ""]
	set infolist [regexp -all -inline {\S+} $info]
	set fname [lindex $infolist 0]
	set fattr [lreplace $infolist 0 0]
        if {[file exists $fname] } {
            lappend flist $fname
            set conffiledict [dict create bn "work" l "local" i "vlogsyn" q $fname fattr $fattr]
            dict set fi $fname $conffiledict
        }
    }

    foreach f $VERILOGSIMFILES  {
	set info [regsub {[ \t]*#.*} $f ""]
	set infolist [regexp -all -inline {\S+} $info]
	set fname [lindex $infolist 0]
	set fattr [lreplace $infolist 0 0]
        if {[file exists $fname] } {
            lappend flist $fname
            set conffiledict [dict create bn "work" l "local" i "vlogsim" q $fname fattr $fattr]
            dict set fi $fname $conffiledict
        }
    }

    if {[dict exists $ft "$GRLIB/lib/work" ] } {
        set worklibdict [dict get $ft "$GRLIB/lib/work"]
    } else {
        set worklibdict [dict create]
        set libdict [dict create k_real "$GRLIB_real/lib/work" bn "work"]
        dict set fi "$GRLIB/lib/work" $libdict
    }

    dict set worklibdict "local" $flist
    set ft [dict remove $ft "work"]
    dict set ft "$GRLIB/lib/work" $worklibdict

}

proc mergefiletrees {filetree extrafiletree} {
    foreach extralib [dict keys $extrafiletree] {
        set foundlib 0
        foreach lib [dict keys $filetree] {
            if {[string equal $lib $extralib]} {
                set foundlib 1
                foreach extradir [dict keys [dict get $extrafiletree $lib] ] {
                    set founddir 0
                    foreach dir [dict keys [dict get $filetree $lib] ] {
                        if {[string equal $dir $extradir] } {
                            set founddir 1
                            foreach extrafile [dict get [dict get $extrafiletree $extralib] $extradir] {
                                set foundfile 0
                                foreach regularfile [dict get [dict get $filetree $lib] $dir] {
                                    if {[string equal $regularfile $extrafile] } {
                                        set foundfile 1
                                        break
                                    }
                                }
                                if {!$foundfile} {
                                    set libdict [dict get $filetree $lib]
                                    set dirlist [dict get $libdict $dir]
                                    lappend dirlist $extrafile
                                    set libdict [dict remove $libdict $dir]
                                    dict set libdict $dir $dirlist
                                    set filetree [dict remove $filetree $lib]
                                    dict set filetree $lib $libdict
                                }
                            }
                            break
                        }
                    }
                    if {!$founddir} {
                        set libdict [dict get $filetree $lib]
                        dict set libdict $extradir [dict get [dict get $extrafiletree $extralib] $extradir]
                        set filetree [dict remove $filetree $lib]
                        dict set filetree $lib $libdict
                    }
                }
                break
            }
        }
        if {!$foundlib} {
            dict set filetree $extralib [dict get $extrafiletree $extralib]
        }
    }
    return $filetree
}

proc mergefileinfos {fileinfo extrafileinfo} {
    foreach extrafile [dict keys $extrafileinfo] {
        set found 0
        foreach regularfile [dict keys $fileinfo] {
            if {[string equal $regularfile $extrafile] } {
                set fileinfo [dict remove $fileinfo $extrafile]
                dict set fileinfo $extrafile [dict get $extrafileinfo $extrafile]
                set found 1
            }
        }
        if {!$found} {
            dict set fileinfo $extrafile [dict get $extrafileinfo $extrafile]
        }
    }
    return $fileinfo
}

set varfile [open "$GRLIB/bin/scriptgen/scriptgen_variables.txt" r]
set envvars [split [read $varfile] "\n" ]

foreach envvar $envvars {
    if {$envvar != "" && ![info exists $envvar]} {
        puts "No value found for $envvar, setting it to {}"
        puts {\n}
        set $envvar {}
    }
}

set filetree [dict create]
set fileinfo [dict create]
set GRLIB  [file dirname $GRLIB/bin]
generatefilelists filetree fileinfo 
set filetree [mergefiletrees $filetree $extrafiletree]
set fileinfo [mergefileinfos $fileinfo $extrafileinfo]



set basenames {}
foreach f [dict keys $filetree] {
        lappend basenames [dict get [dict get $fileinfo $f] bn]
}
set libtxtfile [open "libs.txt" w]
puts $libtxtfile "$basenames "
close $libtxtfile

foreach tool $tools {
    switch $tool {
        "actel" - "aldec" - "altera" - "cdns" - "ghdl" -
        "lattice" - "mentor" - "microsemi" - "snps" - "nanoxplore" -
        "xlnx" {
            if { [ file exists "$GRLIB/bin/scriptgen/filebuild/$tool.tcl" ] } {
                source "$GRLIB/bin/scriptgen/filebuild/$tool.tcl"
            }
            continue
        }
        default {
            if { [catch {source "scriptgenwork/filebuild/$tool.tcl"} fid] } {
                puts stderr "Error with added tool: \"$tool\"!"
                puts stderr "$fid\n"
                puts stderr "Continuing:\n"
            }
            continue
        }
    }
}
