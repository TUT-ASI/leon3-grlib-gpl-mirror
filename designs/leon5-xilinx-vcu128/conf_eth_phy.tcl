# Script for configuring the ethernet PHY of a VCU118 board by Måns Arildsson.
# Edited to support any design.

# Example of usage:
# source conf_eth_phy.tcl
# setup_eth sgmii0_apb_start_address
#
# where sgmii0_apb_start_address is the start address (in the next example
# 0xff990000) of the XILINX SGMII Interface used in the vcu118 board:
# From info sys:
# sgmii0     Frontgrade Gaisler  XILINX SGMII Interface
#            APB: ff990000 - ff991000
#
# sgmii0_apb_start_address can be obtained through (in grmon):
# $sgmii0::pnp::apb::start

proc dec2bin i {
  set res {}
  while {$i>0} {
    set res [expr {$i%2}]$res
    set i [expr {$i/2}]
  }
  if {$res == {}} {set res 0}
  set res [format %016s $res]
  return $res
}

proc read_addr {addr} {

  set rev {}
  set dataBin [dec2bin [silent mdio 3 $addr]]
  for {set i 15} {$i >= 0} {incr i -1} {
    set rev $rev[string index $dataBin $i]
  }
  return $rev
}

proc read_extended_addr {addr} {

  set rev {}
  silent wmdio 3 0x0D 0x001F
  silent wmdio 3 0x0E $addr
  silent wmdio 3 0x0D 0x401F
  set dataBin [dec2bin [silent mdio 3 0x0E]]
  for {set i 15} {$i >= 0} {incr i -1} {
    set rev $rev[string index $dataBin $i]
  }
  return $rev
}

proc read_extended_addr_print {addr} {
  after 10
  silent wmdio 3 0x0D 0x001F
  after 10
  silent wmdio 3 0x0E $addr
  after 10
  silent wmdio 3 0x0D 0x401F
  after 10
  mdio 3 0x0E
}

proc write_extended_addr {addr data} {
  after 10
  silent wmdio 3 0x0D 0x001F
  after 10
  silent wmdio 3 0x0E $addr
  after 10
  silent wmdio 3 0x0D 0x401F
  after 10
  silent wmdio 3 0x0E $data
}



proc reset_phy {} {

  silent wmdio 3 0x00 0x8000
  silent mdio 3 0x00
  silent mdio 3 0x00
  silent wmdio 3 0x00 0x0
}

proc configure_phy {} {
  #  Write 0x4000 to SGMIICTL1 (0x00D3) to Enable differential SGMII clock to MAC.
  after 10
  write_extended_addr 0x00D3 0x4000
  after 10
  silent wmdio 3 0x0 0x1300
  after 10
  silent wmdio 3 0x10 0x5848

  after 10
  set greth [dec2bin [silent mem -dec 0xff940000 1]]
  if {[string index $greth 23] == 1} {
    # gbit
    silent wmdio 3 0x9 0x300
  } else {
    # 100/10 mbit
    silent wmdio 3 0x9 0x00
  }

  # Enabling SGMII autonegotiation and speed optimiztion(optional)
  after 10
  silent wmdio 3 0x14 0x2BC0

  #  Write 0x0070 to CFG4 (0x0031) to set SGMII Auto-Negotiation Timer Duration as 11 ms
  after 10
  write_extended_addr 0x0031 0x0030

  #  Write 0x0 to RGMIICTL (0x0032) to set Disable RGMII
  after 10
  write_extended_addr 0x0032 0x0

}


proc print_warning {} {
  return "\033\[1;31mWARNING: \033\[0m"
}

proc print_info {} {
  puts -nonewline "\033\[1;33mINFO: \033\[0m"
}

proc print_ok {} {
  return "\033\[1;32mOK: \033\[0m"
}

proc link_status {} {

  set resp0 [read_addr 0]
  set resp1 [read_addr 1]
  set resp6 [read_addr 6]
  set resp9 [read_addr 9]
  set respD3 [read_extended_addr 211]
  set resp10 [read_extended_addr 16]
  set resp31 [read_extended_addr 49]
  set resp32 [read_extended_addr 50]
  set resp17 [read_extended_addr 23]

  set warnings {}
  set ok {}

  set temp [string index $respD3 14]
  if {$temp == 1} {
    lappend ok [concat [print_ok] "SGMII 6-wire mode"]
  } else {
    lappend warnings [concat [print_warning] "SGMII 4-wire mode"]
  }
  set temp [string index $resp10 11]
  if {$temp == 1} {
    lappend ok [concat [print_ok] "SGMII Enabled"]
  } else {
    lappend "SGMII Disabled"
  }
  set temp [string index $resp0 12]
  if {$temp == 1} {
    lappend ok [concat [print_ok] "Auto-Negotiation is enabled"]
  } else {
    lappend warnings [concat [print_warning] "Auto-Negotiation is disabled"]
  }

  set temp [string index $resp0 8]
  if {$temp == 1} {
    lappend ok [concat [print_ok] "Full Duplex operation"]
  } else {
    lappend warnings [concat [print_warning] "Half Duplex operation"]
  }
  set temp [string index $resp31 7]
  if {$temp == 1} {
    lappend warnings [concat [print_warning] "Internal test mode enabled"]
  }
  set temp [string index $resp32 7]
  if {$temp == 1} {
    lappend warnings [concat [print_warning] "RGMII Enabled"]
  }
  set temp [string range $resp9 13 15]
  if {$temp != "000"} {
    lappend warnings [concat [print_warning] "PHY in Test Mode"]
  }
  set temp [string index $resp17 6]
  if {$temp == 0} {
    print_info
    puts "Core is in Power-Down or Sleep mode"
  }

  foreach item $ok {
    puts $item
  }

  set temp [string index $resp6 0]
  print_info
  puts "Remote Auto-Negotiation Capability: ${temp}"

  set temp [string index $resp1 5]
  print_info
  puts "Auto-Negotiation Complete: ${temp}"

  set temp [string index $resp1 2]
  print_info
  puts "Link status: ${temp}"

  set temp [string index $resp1 4]
  print_info
  puts "Remote Fault: ${temp}"

  foreach item $warnings {
    puts $item
  }

}

proc setup_eth {sgmii_apb_addr 0} {

  reset_phy
  puts "PHY status before configuration\n"
  link_status
  configure_phy
  puts "\n Configuring PHY \n"
  after 5000
  link_status

  #set sgmii_reset_addr [expr $sgmii_apb_addr + 0xC]

  #wmem $sgmii_reset_addr 1
  #after 200
  #wmem $sgmii_reset_addr 0

  #after 200
  #set sgmii [dec2bin [silent mem -dec $sgmii_apb_addr 1]]
  #if {( [string index $sgmii 15] == 1) && ([string index $sgmii 14] == 1) } {
   # puts "\nA link has been established"
  #} else {
   # puts "\nA link has not been established"
  #}
}

