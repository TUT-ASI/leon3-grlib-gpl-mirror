set nanoxpython_contents ""
proc create_nanoxplore_nanoxpython {} {
    global  TOP 
    upvar nanoxpython_contents vp
    
    append vp "# NanoXPython script for synthesis,place,route and generation of bitstream"
    append vp "\nimport os"
    append vp "\nimport sys"
    append vp "\nfrom os import path"
    append vp "\nfrom nxmap import *"
    append vp "\n"
    append vp "\ndir = os.path.dirname(os.path.realpath(__file__))"
    append vp "\nsys.path.append(dir)"
    
    append vp "\nproject = createProject(dir)"
    append vp "\nproject.load('$TOP\_native.nym')"

    append vp "\nif not project.synthesize():"
    append vp "\n    sys.exit(1)"
    append vp "\nproject.save('$TOP\_synthesized.nym')"
    append vp "\n"
    append vp "\nif not project.place():"
    append vp "\n    sys.exit(1)"
    append vp "\nproject.save('$TOP\_placed.nym')"
    append vp "\n"
    append vp "\nif not os.path.exists(os.path.join(dir, '$TOP\_pads.py')):"
    append vp "\n    project.savePorts('$TOP\_generated_pads.py')"
    append vp "\n"
    append vp "\nif not project.route():"
    append vp "\n    sys.exit(1)"
    append vp "\nproject.save('$TOP\_routed.nym')"
    append vp "\n"

    append vp "\n# Reports"
    append vp "\nproject.reportInstances()"
    append vp "\n"
    append vp "\n# Analyzer"
    append vp "\nanalyzer = project.createAnalyzer()"
    append vp "\nanalyzer.launch()"
    append vp "\n"

    append vp "\n# Generate Bitstream"
    append vp "\nproject.generateBitstream('$TOP\_bitfile.nxb')"
    append vp "\n"
    append vp "\nproject.destroy()"
    #append vp "\nprint 'Errors: ', getErrorCount()"
    #append vp "\nprint 'Warnings: ' getWarningCount()"

    return
}

proc append_file_nanoxplore_nanoxpython{f finfo} {
    # Empty procedure. Maybe it will needed for future versions of the tool.
    return
}

proc eof_nanoxplore_nanoxpython {} {
    global TOP 
    upvar nanoxpython_contents vp
     
    set nanoxpythonfile [open "$TOP\_nanoxpython.py" w]
    puts $nanoxpythonfile $vp
    close $nanoxpythonfile
    return
}
