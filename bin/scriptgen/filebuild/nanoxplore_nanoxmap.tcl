set nanoxmap_contents ""
proc create_nanoxplore_nanoxmap {} {
    global  TOP DEVICE
    upvar nanoxmap_contents vc

    append vc "#Project File for Nanoxmap/Nanoxpython"
    append vc "\nimport os"
    append vc "\nimport sys"
    append vc "\nfrom os import path"
    append vc "\nfrom nanoxmap import *"
    append vc "\ndir = os.path.dirname(os.path.realpath(__file__))"
    append vc "\nsys.path.append(dir)"
    append vc "\nproject = createProject(dir)"
    if {$DEVICE == ""} {
	append vc "\nproject.setVariantName('NG-MEDIUM')"
    } else {
	append vc "\nproject.setVariantName('$DEVICE\')"
    }
    append vc "\nproject.setTopCellName('work', '$TOP')"
    append vc "\n"	
    append vc "\n"
    append vc "\n# Add files for synthesis"

    return
}
proc append_file_nanoxplore_nanoxmap {f finfo} {
    set i [dict get $finfo i]
    set bn [dict get $finfo bn]
    switch $i {
	"vhdlp1735" {
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
	"vhdlfpro" {
	    return
	}
	"vhdlprec" {
	    return
	}
	"vhdlsyn" {
	    upvar nanoxmap_contents vc
	    append vc "\nproject.addFile('$bn','$f')"
	    return
	}
	"vlogsyn" {
	    upvar nanoxmap_contents vc
	    append vc "\nproject.addFile('$bn','$f')"
	    return
	}
	"svlogsyn" {
	    upvar nanoxmap_contents vc
	    append vc "\nproject.addFile('$bn','$f')"
	    return
	}
	"vhdlsim" {

	}
	"vlogsim" {
	    return
	}
	"svlogsim" {
	    return
	}
    }
    return
}

proc eof_nanoxplore_nanoxmap {} {
    global TOP TIMING_DRIVEN MAPPING_EFFORT NXCONSTRAINTS
    upvar nanoxmap_contents vc
    append vc "\n"
    append vc "\n#Set project options"	
    append vc "\nproject.setOption('UseNxLibrary', 'Yes')"
    append vc "\nproject.setOption('MergeRegisterToPad', 'Always')"	
    append vc "\nproject.setOption('ManageUnconnectedOutputs', 'Ground')"
    append vc "\nproject.setOption('ManageUnconnectedSignals', 'Ground')"	
    append vc "\nproject.setOption('AdderToDSPMapThreshold', '0')"
    append vc "\nproject.setOption('DefaultRAMMapping', 'RAM')"	
    append vc "\nproject.setOption('MappingEffort', '$MAPPING_EFFORT\') "
    append vc "\nproject.setOption('ManageAsynchronousReadPort', 'Yes')"
    append vc "\nproject.setOption('TimingDriven', '$TIMING_DRIVEN\')"


    append vc "\n\n"
    set fexist [file exist $NXCONSTRAINTS]
    if {$fexist == 0} {
	append vc "\n# No user defined constraint file in variable NXCONSTRAINTS"
	append vc "\n\n"
    } else {
	append vc "\n#Copying from user defined constraints file"
	append vc "\n\n"
	set fp [open "$NXCONSTRAINTS" r]
	set file_data [read $fp]
	close $fp
	append vc $file_data
	append vc "\n\n"
    }

    append vc "\n# Read pin map"
    append vc "\nif path.exists(dir + '/$TOP\_pads.py'):"
    append vc "\n   from $TOP\_pads import pads"
    append vc "\n   project.addPads(pads)"
 
    append vc "\n#Generate Project file"
    append vc "\nproject.save('$TOP\_native.nxm')"
    
    set nanoxfile [open "$TOP\_nanoxmap.py" w]
    puts $nanoxfile $vc
    close $nanoxfile
    return
}
