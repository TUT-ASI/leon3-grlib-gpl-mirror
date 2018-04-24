#####################################################################################
# Procedure to list all un-driven inout ports
#####################################################################################
proc showPortX {{top d3}} {
  set p_in [find signals /testbench/$top/* -in]
  set p_inout [find signals /testbench/$top/* -inout]

  echo "\nList un-driven IN/INOUT ports:"
  set count 0
  foreach x [concat $p_in $p_inout] {
    #echo $x
    set xx [examine $x]
    if {$xx == "X" || $xx == "StX" || $xx == "U"} {
      echo $x $xx
      incr count
    }
  }
  echo "Count: $count"
  if {$count != 0} {
    echo "***************************************************"
    echo "*** You should add drivers to un-driven ports!  ***"  
    echo "***************************************************"
  }
}

#####################################################################################
# Procedure to list all register with output driving X 
# and force the output to 0
#####################################################################################
proc showRegX {{remove ""} {top d3} {ports {Q QN}} {depth 10}} {
  echo "\nList all registers with value X:"
  set regs [list]
  foreach port $ports {
    set path ""
    for {set i 0} {$i < $depth} {incr i} {
      #echo "/testbench/$top/${path}$port"
      set regs [concat $regs [find nets /testbench/$top/${path}$port]]
      append path "*/"
    }
  }

  set count 0
  foreach x $regs {
    set xx [examine $x]
    if {$xx == "X" || $xx == "StX"} {
      echo $x $xx
      incr count
      if {$remove == "remove"} {
        force -deposit $x 1 0
      }
    }
  }
  echo "Count: $count"

  if {$remove == "remove"} {
    echo "***************************************************"
    echo "*** All registers with value X are forced to 0! ***"
    echo "***************************************************"
  }
}

# Determine environment 0: batch or 1: inside Libero (default) ######################

if {[info exists run_mode] == 0} {
  set run_mode 2
}

# batch mode
if { $run_mode == 1 } {

  # Add waveforms
  if { [file exists wave.do] == 1 } {
    do wave.do
  }
  
  # Setup simulation state (RTL or post-synth/layout)
  set post 1
  
  # Setup top-level instans name
  if {[info exists top] == 0} {
    set top d3
  }

# Run for Libero
} elseif { $run_mode == 2 } {

  # Add waveforms
  if { [file exists ../../wave.do] == 1 } {
    do ../../wave.do
  }

  # Copy PROM image
  if { [file exists ../../ENVM_init.mem] == 1 && [file exists ENVM_init.mem] == 0 } {
    echo "Copy /ENVM_init.mem to simulation directory."
    file copy ../../ENVM_init.mem .
  }

  # Setup simulation state (RTL or post-synth/layout)
  if {[info exists post] == 0} {
    set post [string match *post* $argv]
  }

  # Setup top-level instans name
  if {[info exists top] == 0} {
    set top d3
  }

} else {
  set post 0
}

# Run if post-synth/layout simulation ###############################################
if {$post == 1} {
  echo "POST: $post"
  echo "TOP: $top"
  echo "Post-synth/layout simulation: remove X from design"
  run 1 ns
  showRegX remove $top
  showPortX $top
  
  if { $run_mode == 1 } {
    run -a
    quit
  }
}
# ###################################################################################


