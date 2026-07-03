
################################################################
# This is a generated script based on design: versal_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2025.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source versal_bd_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvc1902-vsva2197-2MP-e-S
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name versal_bd

variable project_name
set project_name [get_property NAME [current_project]]

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

# Remove previous occurence of design
#remove_files  vivado/$project_name/$project_name.srcs/sources_1/bd/$design_name/$design_name.bd

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:versal_cips:3.4\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name
  variable project_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports

  # Create ports
  set BSCAN_USER1_capture [ create_bd_port -dir O BSCAN_USER1_capture ]
  set BSCAN_USER1_drck [ create_bd_port -dir O BSCAN_USER1_drck ]
  set BSCAN_USER1_reset [ create_bd_port -dir O BSCAN_USER1_reset ]
  set BSCAN_USER1_runtest [ create_bd_port -dir O BSCAN_USER1_runtest ]
  set BSCAN_USER1_sel [ create_bd_port -dir O BSCAN_USER1_sel ]
  set BSCAN_USER1_shift [ create_bd_port -dir O BSCAN_USER1_shift ]
  set BSCAN_USER1_tck [ create_bd_port -dir O BSCAN_USER1_tck ]
  set BSCAN_USER1_tdi [ create_bd_port -dir O BSCAN_USER1_tdi ]
  set BSCAN_USER1_tdo [ create_bd_port -dir I BSCAN_USER1_tdo ]
  set BSCAN_USER1_tms [ create_bd_port -dir O BSCAN_USER1_tms ]
  set BSCAN_USER1_update [ create_bd_port -dir O BSCAN_USER1_update ]
  set BSCAN_USER2_capture [ create_bd_port -dir O BSCAN_USER2_capture ]
  set BSCAN_USER2_drck [ create_bd_port -dir O BSCAN_USER2_drck ]
  set BSCAN_USER2_reset [ create_bd_port -dir O BSCAN_USER2_reset ]
  set BSCAN_USER2_runtest [ create_bd_port -dir O BSCAN_USER2_runtest ]
  set BSCAN_USER2_sel [ create_bd_port -dir O BSCAN_USER2_sel ]
  set BSCAN_USER2_shift [ create_bd_port -dir O BSCAN_USER2_shift ]
  set BSCAN_USER2_tck [ create_bd_port -dir O BSCAN_USER2_tck ]
  set BSCAN_USER2_tdi [ create_bd_port -dir O BSCAN_USER2_tdi ]
  set BSCAN_USER2_tdo [ create_bd_port -dir I BSCAN_USER2_tdo ]
  set BSCAN_USER2_tms [ create_bd_port -dir O BSCAN_USER2_tms ]
  set BSCAN_USER2_update [ create_bd_port -dir O BSCAN_USER2_update ]
  set pl0_resetn [ create_bd_port -dir O -type rst pl0_resetn ]
  set pl0_ref_clk_0 [ create_bd_port -dir O -type clk pl0_ref_clk_0 ]

  # Create instance: cips, and set properties
  set cips [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 cips ]
  set_property -dict [list \
    CONFIG.BOOT_MODE {Custom} \
    CONFIG.DESIGN_MODE {0} \
    CONFIG.PS_PMC_CONFIG { \
      BOOT_MODE {Custom} \
      DDR_MEMORY_MODE {Custom} \
      DESIGN_MODE {0} \
      PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
      PMC_CRP_QSPI_REF_CTRL_FREQMHZ {300} \
      PMC_MIO40 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA low} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
      PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
      PMC_QSPI_PERIPHERAL_ENABLE {0} \
      PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
      PMC_REF_CLK_FREQMHZ {50.000} \
      PMC_SD0 {{CD_ENABLE 0} {CD_IO {PMC_MIO 24}} {POW_ENABLE 0} {POW_IO {PMC_MIO 17}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 17}} {WP_ENABLE 0} {WP_IO {PMC_MIO 25}}} \
      PMC_SD0_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x00} {CLK_50_DDR_ITAP_DLY 0x00} {CLK_50_DDR_OTAP_DLY 0x00} {CLK_50_SDR_ITAP_DLY 0x00} {CLK_50_SDR_OTAP_DLY 0x00} {ENABLE 0}\
{IO {PMC_MIO 13 .. 25}}} \
      PMC_SD0_SLOT_TYPE {SD 2.0} \
      PMC_SD1 {{CD_ENABLE 0} {CD_IO {PMC_MIO 2}} {POW_ENABLE 0} {POW_IO {PMC_MIO 12}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
      PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x00} {CLK_50_DDR_ITAP_DLY 0x00} {CLK_50_DDR_OTAP_DLY 0x00} {CLK_50_SDR_ITAP_DLY 0x00} {CLK_50_SDR_OTAP_DLY 0x00} {ENABLE 0}\
{IO {PMC_MIO 0 .. 11}}} \
      PMC_SD1_SLOT_TYPE {SD 2.0} \
      PMC_SMAP_PERIPHERAL {{ENABLE 0} {IO {32 Bit}}} \
      PMC_USE_PMC_NOC_AXI0 {0} \
      PS_BANK_2_IO_STANDARD {LVCMOS3.3} \
      PS_BANK_3_IO_STANDARD {LVCMOS3.3} \
      PS_BOARD_INTERFACE {Custom} \
      PS_GEN_IPI0_ENABLE {1} \
      PS_GEN_IPI1_ENABLE {1} \
      PS_GEN_IPI1_MASTER {R5_0} \
      PS_GEN_IPI2_ENABLE {1} \
      PS_GEN_IPI2_MASTER {R5_1} \
      PS_GEN_IPI3_ENABLE {1} \
      PS_GEN_IPI4_ENABLE {1} \
      PS_GEN_IPI5_ENABLE {1} \
      PS_GEN_IPI6_ENABLE {1} \
      PS_NUM_FABRIC_RESETS {1} \
      PS_TTC0_PERIPHERAL_ENABLE {1} \
      PS_TTC1_PERIPHERAL_ENABLE {1} \
      PS_TTC2_PERIPHERAL_ENABLE {1} \
      PS_TTC3_PERIPHERAL_ENABLE {1} \
      PS_UART1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
      PS_USE_BSCAN_USER1 {1} \
      PS_USE_BSCAN_USER2 {1} \
      PS_USE_PMCPL_CLK0 {1} \
      SMON_ALARMS {Set_Alarms_On} \
      SMON_ENABLE_TEMP_AVERAGING {0} \
      SMON_TEMP_AVERAGING_SAMPLES {0} \
    } \
  ] $cips


  # Create port connections
  connect_bd_net -net BSCAN_USER1_tdo_1 [get_bd_ports BSCAN_USER1_tdo] [get_bd_pins cips/BSCAN_USER1_tdo]
  connect_bd_net -net BSCAN_USER2_tdo_0_1 [get_bd_ports BSCAN_USER2_tdo] [get_bd_pins cips/BSCAN_USER2_tdo]
  connect_bd_net -net cips_BSCAN_USER1_capture [get_bd_pins cips/BSCAN_USER1_capture] [get_bd_ports BSCAN_USER1_capture]
  connect_bd_net -net cips_BSCAN_USER1_drck [get_bd_pins cips/BSCAN_USER1_drck] [get_bd_ports BSCAN_USER1_drck]
  connect_bd_net -net cips_BSCAN_USER1_reset [get_bd_pins cips/BSCAN_USER1_reset] [get_bd_ports BSCAN_USER1_reset]
  connect_bd_net -net cips_BSCAN_USER1_runtest [get_bd_pins cips/BSCAN_USER1_runtest] [get_bd_ports BSCAN_USER1_runtest]
  connect_bd_net -net cips_BSCAN_USER1_sel [get_bd_pins cips/BSCAN_USER1_sel] [get_bd_ports BSCAN_USER1_sel]
  connect_bd_net -net cips_BSCAN_USER1_shift [get_bd_pins cips/BSCAN_USER1_shift] [get_bd_ports BSCAN_USER1_shift]
  connect_bd_net -net cips_BSCAN_USER1_tck [get_bd_pins cips/BSCAN_USER1_tck] [get_bd_ports BSCAN_USER1_tck]
  connect_bd_net -net cips_BSCAN_USER1_tdi [get_bd_pins cips/BSCAN_USER1_tdi] [get_bd_ports BSCAN_USER1_tdi]
  connect_bd_net -net cips_BSCAN_USER1_tms [get_bd_pins cips/BSCAN_USER1_tms] [get_bd_ports BSCAN_USER1_tms]
  connect_bd_net -net cips_BSCAN_USER1_update [get_bd_pins cips/BSCAN_USER1_update] [get_bd_ports BSCAN_USER1_update]
  connect_bd_net -net cips_BSCAN_USER2_capture [get_bd_pins cips/BSCAN_USER2_capture] [get_bd_ports BSCAN_USER2_capture]
  connect_bd_net -net cips_BSCAN_USER2_drck [get_bd_pins cips/BSCAN_USER2_drck] [get_bd_ports BSCAN_USER2_drck]
  connect_bd_net -net cips_BSCAN_USER2_reset [get_bd_pins cips/BSCAN_USER2_reset] [get_bd_ports BSCAN_USER2_reset]
  connect_bd_net -net cips_BSCAN_USER2_runtest [get_bd_pins cips/BSCAN_USER2_runtest] [get_bd_ports BSCAN_USER2_runtest]
  connect_bd_net -net cips_BSCAN_USER2_sel [get_bd_pins cips/BSCAN_USER2_sel] [get_bd_ports BSCAN_USER2_sel]
  connect_bd_net -net cips_BSCAN_USER2_shift [get_bd_pins cips/BSCAN_USER2_shift] [get_bd_ports BSCAN_USER2_shift]
  connect_bd_net -net cips_BSCAN_USER2_tck [get_bd_pins cips/BSCAN_USER2_tck] [get_bd_ports BSCAN_USER2_tck]
  connect_bd_net -net cips_BSCAN_USER2_tdi [get_bd_pins cips/BSCAN_USER2_tdi] [get_bd_ports BSCAN_USER2_tdi]
  connect_bd_net -net cips_BSCAN_USER2_tms [get_bd_pins cips/BSCAN_USER2_tms] [get_bd_ports BSCAN_USER2_tms]
  connect_bd_net -net cips_BSCAN_USER2_update [get_bd_pins cips/BSCAN_USER2_update] [get_bd_ports BSCAN_USER2_update]
  connect_bd_net -net cips_pl0_ref_clk [get_bd_pins cips/pl0_ref_clk] [get_bd_ports pl0_ref_clk_0]
  connect_bd_net -net cips_pl0_resetn [get_bd_pins cips/pl0_resetn] [get_bd_ports pl0_resetn]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  generate_target all [get_files  vivado/$project_name/$project_name.srcs/sources_1/bd/$design_name/$design_name.bd]
  
  validate_bd_design
  save_bd_design

  add_files -fileset constrs_1 -norecurse noelv-ada-adm-pa100.xdc
  set_property used_in_synthesis false [get_files noelv-ada-adm-pa100.xdc]
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""
