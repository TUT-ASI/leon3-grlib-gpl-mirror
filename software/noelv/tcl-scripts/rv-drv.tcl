#####################################################################################
# Usage: grmon --ucmd rv-drv.tcl
#####################################################################################
#
#
#####################################################################################
# Risc-V Debug Module driver
#####################################################################################

namespace eval drivers::rv64gc {
# These variables are required
  variable vendor 0x1
  variable device 0xbd
  variable version_min 0
  variable version_max 1
  variable description "RV64GC RISC-V Processor"

# Proc init
# Args devname: Device name
#      level : Which stage of initialization
# Return -
#
# Optional procedure that will be called during initialization. The procedure
# will be called with level argmuent set to 1-9, this way drivers that depend
# on another driver can be initialized in a safe way. Normally
# initialization is done in level 7.
#
# Commands wmem and mem can be used to access the registers. Use the driver procedure
# regaddr to calculate addresses or use static addresses.
  proc init {devname level} {
    #puts "init $devname $level"
    if {$level == 7} {
      #puts "Hello $devname!"
      #puts "Reg1 = mem [regaddr $devname myreg1] 4"
    }
  }

# Proc restart
# Args devname: Device name
# Return -
#
# Optional procedure to reinit the device. This is called when GRMON start,
# when commands 'run' or 'reset' is issued.
  proc restart devname {
    #puts "restart $devname"
  }

# Proc info
# Args devname: Device name
# Return A newline-separated string
#
# Optional procedure that may be used to present parsed information when
# 'info sys' is called.
  proc info devname {
    #set str "Some extra information about $devname"
    #append str "\nSome more information about $devname"
    #set str "Version: [mem -hex [regaddr $devname VER] 4]"
    set str ""
    return $str
  }

};

#####################################################################################
# Risc-V Debug Module driver
#####################################################################################

namespace eval drivers::rvdm {
# These variables are required
  variable vendor 0x1
  variable device 0xbe
  variable version_min 0
  variable version_max 1
  variable description "RISC-V Debug Module"

# Proc init
# Args devname: Device name
#      level : Which stage of initialization
# Return -
#
# Optional procedure that will be called during initialization. The procedure
# will be called with level argmuent set to 1-9, this way drivers that depend
# on another driver can be initialized in a safe way. Normally
# initialization is done in level 7.
#
# Commands wmem and mem can be used to access the registers. Use the driver procedure
# regaddr to calculate addresses or use static addresses.
  proc init {devname level} {
    #puts "init $devname $level"
    if {$level == 7} {
      #puts "Hello $devname!"
      #puts "Reg1 = mem [regaddr $devname myreg1] 4"
      wmem [regaddr $devname dmcontrol] 0x80000001
      wmem [regaddr $devname dmcontrol] 0x80000001
    }
  }

# Proc restart
# Args devname: Device name
# Return -
#
# Optional procedure to reinit the device. This is called when GRMON start,
# when commands 'run' or 'reset' is issued.
  proc restart devname {
    #puts "restart $devname"
  }

# Proc info
# Args devname: Device name
# Return A newline-separated string
#
# Optional procedure that may be used to present parsed information when
# 'info sys' is called.
  proc info devname {
    #set str "Some extra information about $devname"
    #append str "\nSome more information about $devname"
    #set str "Version: [mem -hex [regaddr $devname VER] 4]"
    set str ""
    return $str
  }

# Proc regaddr
# Args devname: Device name,
#      regname: Register name
# Return Address of requested register
#
# Required only if any registers have been defined.
# This is a suggestion how the procedure could be implemented
  proc regaddr {devname regname} {
    array set offsets {\
      data0 0x10 \
      data1 0x14 \
      data2 0x18 \
      data3 0x1c \
      data4 0x20 \
      data5 0x24 \
      data6 0x28 \
      data7 0x2c \
      data8 0x30 \
      data9 0x34 \
      data10 0x38 \
      data11 0x3c \
      dmcontrol 0x40 \
      dmstatus 0x44 \
      hartinfo 0x48 \
      haltsum1 0x4c \
      hawindowsel 0x50 \
      hawindow 0x54 \
      abstractcs 0x58 \
      command 0x5c \
      abstractauto 0x60 \
      confstrptr0 0x64 \
      confstrptr1 0x68 \
      confstrptr2 0x6c \
      confstrptr3 0x70 \
      nextdm 0x74 \
      custom 0x7c \
      progbuf0 0x80 \
      progbuf1 0x84 \
      progbuf2 0x88 \
      progbuf3 0x8c \
      progbuf4 0x90 \
      progbuf5 0x94 \
      progbuf6 0x98 \
      progbuf7 0x9c \
      progbuf8 0xa0 \
      progbuf9 0xa4 \
      progbuf10 0xa8 \
      progbuf11 0xac \
      progbuf12 0xb0 \
      progbuf13 0xb4 \
      progbuf14 0xb8 \
      progbuf15 0xbc \
      authdata 0xc0 \
      dmcs2 0xc8 \
      haltsum2 0xd0 \
      haltsum3 0xd4 \
      haltsum0 0x100 \
    }

    if {[namespace exists ::[set devname]::pnp::apb]} {
      set start [set ::[set devname]::pnp::apb::start]
    } elseif {[namespace exists ::[set devname]::pnp::ahb]} {
      set start [set ::[set devname]::pnp::ahb::0::start]
    } else {
      error "Unknown register adress for $devnam::$regname"
    }
    return [format 0x%08x [expr ($start + $offsets($regname)) & 0xFFFFFFFF]]
  }

# Register descriptions
#
# All description must be put in the regs-namespace. Each register concist
# of a name, description and an optional list of fields.
# The fields are quadruple of the format {name pos bits description}
#
# Registers and fields can be added, removed or changed up to initialization
# level 8. After level 8 TCL variables are created and the regs variable
# should be considered to a constant.
  variable regs {
    {"data0" "Abstract Data 0"
    }
    {"data1" "Abstract Data 1"
    }
    {"data2" "Abstract Data 2"
    }
    {"data3" "Abstract Data 3"
    }
    {"data4" "Abstract Data 4"
    }
    {"data5" "Abstract Data 5"
    }
    {"data6" "Abstract Data 6"
    }
    {"data7" "Abstract Data 7"
    }
    {"data8" "Abstract Data 8"
    }
    {"data9" "Abstract Data 9"
    }
    {"data10" "Abstract Data 10"
    }
    {"data11" "Abstract Data 11"
    }
    {"dmcontrol" "Debug Module Control"
      {"haltreq" 31 1 "Halt currently selected harts"}
      {"resumereq" 30 1 "Resume currently selected harts"}
      {"hartreset" 29 1 "Reset bit for all the currently selected harts"}
      {"ackhavereset " 28 1 "Clears havereset for any selected harts"}
      {"hasel" 26 1 "Definition of currently selected harts"}
      {"hartsello" 16 10 "The low 10 bits of hartsel"}
      {"hartselhi" 6 10 "The high 10 bits of hartsel"}
      {"setresethaltreq" 3 1 "Halt-on-reset request all selected harts"}
      {"clrresethaltreq" 2 1 "Halt-on-reset request selexted hart"}
      {"ndmreset" 1 1 "Debug module reset signal"}
      {"dmactive" 0 1 "Debug module active"}
    }
    {"dmstatus" "Debug Module Status"
      {"impebreak" 22 1 "Implicit ebreak instruction"}
      {"allhavereset" 19 1 "All currently selected harts have been reset (no ACK)"}
      {"anyhavereset" 18 1 "At least one currently selected hart has been reset (no ACK)"}
      {"allresumeack" 17 1 "All currently selected harts resumed"}
      {"anyresumeack" 16 1 "Any of currently selected hart resumed"}
      {"allnonexistent" 15 1 "All currently selected harts do not exist"}
      {"anynonexistent" 14 1 "Any of currently selected harts do not exist"}
      {"allunavail" 13 1 "All currently selected harts are unavailable"}
      {"anyunavail" 12 1 "Any of currently selected harts are unavailable"}
      {"allrunning" 11 1 "All currently selected harts are running"}
      {"anyrunning" 10 1 "Any of currently selected harts are running"}
      {"allhalted" 9 1 "All currently selected hart is halted"}
      {"anyhalted" 8 1 "Any of currently selected hart is halted"}
      {"authenticated" 7 1 "Authentication is required before using the DM"}
      {"authbusy" 6 1 "The authentication module is busy"}
      {"hasresethaltreq" 5 1 "Debug Module supports halt-on-reset functionality"}
      {"confstrptrvalid" 4 1 "1: CONFSTRPTR hold the address of the configuration string"}
      {"version" 0 4 "Debug Module implementation"}
    }
    {"hartinfo" "Hart Info"
    }
    {"haltsum1" "Halt Summary 1"
    }
    {"hawindowsel" "Hart Array Window Select"
    }
    {"hawindow" "Hart Array Window"
    }
    {"abstractcs" "Abstract Control and Status"
      {"progbufsize" 24 5 "Size of the Program Buffer, in 32-bit words"}
      {"busy" 12 1 "An abstract command is currently being executed"}
      {"cmderr" 8 3 "abstract command error status"}
      {"datacount" 0 4 "Number of data registers that are implemented"}
    }
    {"command" "Abstract Command"
    }
    {"abstractauto" "Abstract Command Autoexec"
    }
    {"confstrptr0" "Configuration String Pointer 0"
    }
    {"confstrptr1" "Configuration String Pointer 1"
    }
    {"confstrptr2" "Configuration String Pointer 2"
    }
    {"confstrptr3" "Configuration String Pointer 3"
    }
    {"nextdm" "Next Debug Module"
    }
    {"custom" "Custom Features"
    }
    {"progbuf0" "Program Buffer 0"
    }
    {"progbuf1" "Program Buffer 1"
    }
    {"progbuf2" "Program Buffer 2"
    }
    {"progbuf3" "Program Buffer 3"
    }
    {"progbuf4" "Program Buffer 4"
    }
    {"progbuf5" "Program Buffer 5"
    }
    {"progbuf6" "Program Buffer 6"
    }
    {"progbuf7" "Program Buffer 7"
    }
    {"progbuf8" "Program Buffer 8"
    }
    {"progbuf9" "Program Buffer 9"
    }
    {"progbuf10" "Program Buffer 10"
    }
    {"progbuf11" "Program Buffer 11"
    }
    {"progbuf12" "Program Buffer 12"
    }
    {"progbuf13" "Program Buffer 13"
    }
    {"progbuf14" "Program Buffer 14"
    }
    {"progbuf15" "Program Buffer 15"
    }
    {"authdata" "Authentication Data"
    }
    {"dmcs2" "Debug Module Control and Status 2"
    }
    {"haltsum2" "Halt Summary 2"
    }
    {"haltsum3" "Halt Summary 3"
    }
    {"haltsum0" "Halt Summary 0"
    }
  }
};

#####################################################################################
# Risc-V command
#####################################################################################

namespace eval rv {
  variable dbg 0
  variable dev 
  variable reset_pc 0x00010000
  variable exec0 {}
    
  variable gprs [dict create \
    zero 0x1000 \
    ra 0x1001 \
    sp 0x1002 \
    gp 0x1003 \
    tp 0x1004 \
    t0 0x1005 \
    t1 0x1006 \
    t2 0x1007 \
    fp 0x1008 \
    s1 0x1009 \
    a0 0x100a \
    a1 0x100b \
    a2 0x100c \
    a3 0x100d \
    a4 0x100e \
    a5 0x100f \
    a6 0x1010 \
    a7 0x1011 \
    s2 0x1012 \
    s3 0x1013 \
    s4 0x1014 \
    s5 0x1015 \
    s6 0x1016 \
    s7 0x1017 \
    s8 0x1018 \
    s9 0x1019 \
    s10 0x101a \
    s11 0x101b \
    t3 0x101c \
    t4 0x101d \
    t5 0x101e \
    t6 0x101f \
  ]
    
  variable csrs [dict create \
    cycle 0xc00 \
    time 0xc01 \
    instret 0xc02 \
    mhartid 0xf14 \
    sstatus 0x100 \
    sie 0x104 \
    stvec 0x105 \
    scounteren 0x106 \
    sscratch 0x140 \
    sepc 0x141 \
    scause 0x142 \
    stval 0x143 \
    sip 0x144 \
    satp 0x180 \
    sedeleg 0x102 \
    sideleg 0x103  \
    sbadaddr 0x143 \
    mstatus 0x300 \
    misa 0x301 \
    medeleg 0x302 \
    mideleg 0x303 \
    mie 0x304 \
    mtvec 0x305 \
    mcounteren 0x306 \
    mscratch 0x340 \
    mbadaddr 0x343 \
    mepc 0x341 \
    mcause 0x342 \
    mtval 0x343 \
    mip 0x344 \
    spbtr 0x180 \
    tselect 0x7a0 \
    tdata1 0x7a1 \
    tdata2 0x7a2 \
    tdata3 0x7a3 \
    dpc 0x7b1 \
    dcsr 0x7b0 \
    dscratch 0x7b2 \
    dfeaturesen 0x7c0 \
    mcycle 0xb00 \
    minstret 0xb02 \
    pmpcfg0   0x3A0 \
    pmpcfg1   0x3A1 \
    pmpcfg2   0x3A2 \
    pmpcfg3   0x3A3 \
    pmpaddr0  0x3B0 \
    pmpaddr1  0x3B1 \
    pmpaddr2  0x3B2 \
    pmpaddr3  0x3B3 \
    pmpaddr4  0x3B4 \
    pmpaddr5  0x3B5 \
    pmpaddr6  0x3B6 \
    pmpaddr7  0x3B7 \
    pmpaddr8  0x3B8 \
    pmpaddr9  0x3B9 \
    pmpaddr10 0x3BA \
    pmpaddr11 0x3BB \
    pmpaddr12 0x3BC \
    pmpaddr13 0x3BD \
    pmpaddr14 0x3BE \
    pmpaddr15 0x3BF \
  ]

  proc enable {} {
    variable dev 
    variable csrs
    set ::[subst $dev]::dmcontrol::dmactive 1

    # Halt on ebreak
    set regaddr [dict get $csrs dcsr]
    set tmp [expr {[reg_read $regaddr] | (0xB << 12)}]
    reg_write $regaddr $tmp
  }
  
  proc abs_cmd {cmdtype aarsize aarpostincrement postexec transfer write regno data0} {
    variable dbg 
    variable dev 

    if {$write == 1} {
      set ::[subst $dev]::data0 [expr {$data0 & 0xFFFFFFFF}]
      if {$aarsize > 2} {
        set ::[subst $dev]::data1 [expr {($data0 >> 32) & 0xFFFFFFFF}]
      }
      if {$aarsize == 4} {
        set ::[subst $dev]::data2 [expr {($data0 >> 64) & 0xFFFFFFFF}]
        set ::[subst $dev]::data3 [expr {($data0 >> 96) & 0xFFFFFFFF}]
      }
    }

    set cmd [expr {(($cmdtype & 0x3) << 24) | (($aarsize & 0x7) << 20) | \
                   (($aarpostincrement & 0x1) << 19) | (($postexec & 0x1) << 18) | \
                   (($transfer & 0x1) << 17) | (($write & 0x1) << 16) | ($regno & 0xFFFF)}]
  
    if {$dbg} {puts "CMD: [format 0x%08X $cmd]"}
    set ::[subst $dev]::command $cmd

    set tmp 1
    while {$::grmon::interrupt == 0 && $tmp == 1} {
      catch {
        set tmp [set ::[subst $dev]::abstractcs::busy]
      }
    }
    
    set res 0
    if {$write == 0} {
      if {$aarsize == 2} {
        set res [set ::[subst $dev]::data0]
      } elseif {$aarsize == 3} {
        set res [expr {(([set ::[subst $dev]::data1] & 0xFFFFFFFF) << 32) | \
                       (([set ::[subst $dev]::data0] & 0xFFFFFFFF))}]
      } elseif {$aarsize == 4} {
        set res [expr {(([set ::[subst $dev]::data3] & 0xFFFFFFFF) << 96) | \
                       (([set ::[subst $dev]::data2] & 0xFFFFFFFF) << 64) | \
                       (([set ::[subst $dev]::data1] & 0xFFFFFFFF) << 32) | \
                       (([set ::[subst $dev]::data0] & 0xFFFFFFFF))}]
      }
    }
    return $res
  }

  proc reg_read {regno} {
    variable dbg 
    variable dev 

    if {$dbg} {puts "Read register: \[$regno\]"}
    return [abs_cmd 0 3 0 0 1 0 $regno 0]
  }
  
  proc reg_write {regno data} {
    variable dbg 
    variable dev 

    if {$dbg} {puts "Write register: \[$regno\] = [format 0x%016x $data]"}
    return [abs_cmd 0 3 0 0 1 1 $regno $data]
  }

  proc get_pc {} {
    variable dbg
    variable dev 
    variable csrs

	  set regaddr [dict get $csrs dpc]
    set tmp [reg_read $regaddr]
    
    ## FIXME: add command proc
    #set ::[subst $dev]::command 0x003207b1
    #
    #set tmp 1
    #while {$::grmon::interrupt == 0 && $tmp == 1} {
    #  catch {
    #    set tmp [set ::[subst $dev]::abstractcs::busy]
    #  }
    #}

    #set tmp [set ::[subst $dev]::data0]
    #if {$dbg} {puts [format "PC: 0x%08X" $tmp]}
    return $tmp
  }

  proc set_pc {{addr ""}} {
    variable dev 
    variable reset_pc
    variable csrs

    if {$addr != ""} {
      set reset_pc $addr
    }

	  set regaddr [dict get $csrs dpc]
    reg_write $regaddr $reset_pc

    #set ::[subst $dev]::data0 $reset_pc
    ## FIXME: add command proc
    #set ::[subst $dev]::command 0x003307b1
  }

  proc resume {} {
    variable dbg
    variable dev 
    
    set ::[subst $dev]::dmcontrol::resumereq 1

    if {$dbg} {puts "Wait for resume..."}
    # FIXME: resume ack still cleared
    set tmp 0
    while {$::grmon::interrupt == 0 && $tmp == 0} {
      set tmp [set ::[subst $dev]::dmstatus::allresumeack]
    }
    if {$dbg} {puts "Resumed"}
  }

  proc halt {} {
    variable dbg
    variable dev 

    set ::[subst $dev]::dmcontrol::haltreq 1

    if {$dbg} {puts "Wait for halt..."}
    set tmp 0
    while {$::grmon::interrupt == 0 && $tmp == 0} {
      catch {
        set tmp [set ::[subst $dev]::dmstatus::allhalted]
      }
    }
    if {$dbg} {puts "Halted"}
  }
  
  proc running {} {
    variable dbg
    variable dev 
    variable exec0

    set first 1
    set tmp 1
    while {$::grmon::interrupt == 0 && $tmp == 1} {
      eval $exec0
      catch {
        set tmp [set ::[subst $dev]::dmstatus::allrunning]
        if {$first == 1 && $tmp == 1} {
          set first 0
          if {$dbg} {puts "Running..."}
        }
      }
    }
    if {$dbg} {puts "Running...done"}
  }
  
  proc test {} {
    puts "Test start"
    set tmp 0
    while {$::grmon::interrupt == 0} {
      if {$tmp == 0} {puts "Test while"}
      set tmp 1 
    }
    puts "Test done"
  }

  proc step {} {
    variable dbg
    variable dev
    variable csrs

    enable

	  set regaddr [dict get $csrs dcsr]
    set tmp [expr {[reg_read $regaddr] | 0x4}]
    reg_write $regaddr $tmp

    resume
    running
    halt

	  set regaddr [dict get $csrs dcsr]
    set tmp [expr {[reg_read $regaddr] & 0xFFFFFFFB}]
    reg_write $regaddr $tmp

    reg dpc
  }
  
  proc reg {{name ""} {data ""}} {
    variable dbg
    variable dev 
    variable gprs
    variable csrs
    
    set res 0

    if {$name == "" | $name == "gprs"} {
      if {$dbg} {puts "Print all GPRs"}
      dict for {name regaddr} $gprs {
        set res [reg_read $regaddr]
        puts "$name =  [format 0x%016x $res]"
      }
    } elseif {[dict exists $gprs $name]} {
      set regaddr [dict get $gprs $name]

      if {$data == ""} {
        if {$dbg} {puts "Read register: $name"}
        set res [reg_read $regaddr]
        puts "$name =  [format 0x%016x $res]"
      } else {
        if {$dbg} {puts "Write register: $name = [format 0x%016X $data]"}
        reg_write $regaddr $data
        puts "$name =  [format 0x%016x $data]"
      }
    } elseif {[dict exists $csrs $name]} {
      set regaddr [dict get $csrs $name]

      if {$data == ""} {
        if {$dbg} {puts "Read CSR register: $name\[$regaddr\]"}
        set res [reg_read $regaddr]
        puts "$name =  [format 0x%016x $res]"
      } else {
        if {$dbg} {puts "Write CSR register: $name\[$regaddr\] = [format 0x%016x $data]"}
        reg_write $regaddr $data
        puts "$name =  [format 0x%016x $data]"
      }
   } elseif {$name == "csrs"} {
      if {$dbg} {puts "Print all CSRs"}
      dict for {name regaddr} $csrs {
        set res [reg_read $regaddr]
        puts "$name =  [format 0x%016x $res]"
      }
    } else {
      error "Invalid register name" "invalid register name" -1
    }
    
    return $res
  }

  proc cont {} {
    variable dbg
    variable dev 

    enable

    resume
    running
    halt

    puts [format "PC: 0x%08X" [get_pc]]
  }
  
  proc run {{ep ""}} {
    variable dbg
    variable dev 

    enable
    set_pc $ep

    resume
    running
    halt

    puts [format "PC: 0x%08X" [get_pc]]
  }

  proc install {} {
    set ::rv::dev rvdm0

    rename ::run ::_sparc_run
    interp alias {} ::run {} ::rv::run
    
    rename ::step ::_sparc_step
    interp alias {} ::step {} ::rv::step

    rename ::reg ::_sparc_reg
    interp alias {} ::reg {} ::rv::reg

    rename ::cont ::_sparc_cont
    interp alias {} ::cont {} ::rv::cont
    
    rename ::disassemble ::_sparc_disassemble
    interp alias {} ::disassemble {} ::rv_dis::disassemble

    rename ::inst ::_sparc_inst
    interp alias {} ::inst {} ::rv_tbuf::print_trace
  }
}

namespace eval rv_dis {
  variable dbg 0

  proc get_base {inst} {
    return [expr {($inst >> 0) & 0x3}]  
  }
  
  proc get_op {inst} {
    return [expr {($inst >> 2) & 0x1F}]  
  }
  
  proc get_func2 {inst} {
    return [expr {($inst >> 25) & 0x3}]  
  }
  
  proc get_func3 {inst} {
    return [expr {($inst >> 12) & 0x7}]  
  }
  
  proc get_func5 {inst} {
    return [expr {($inst >> 27) & 0x1F}]  
  }
  
  proc get_func6 {inst} {
    return [expr {($inst >> 26) & 0x3F}]  
  }
  
  proc get_func7 {inst} {
    return [expr {($inst >> 25) & 0x7F}]  
  }
  
  proc get_rs1 {inst} {
    return [expr {($inst >> 15) & 0x1F}]  
  }
  
  proc get_rs2 {inst} {
    return [expr {($inst >> 20) & 0x1F}]  
  }
  
  proc get_rs3 {inst} {
    return [expr {($inst >> 27) & 0x1F}]  
  }
  
  proc get_rd {inst} {
    return [expr {($inst >> 7) & 0x1F}]  
  }
  
  proc get_imm_i {inst} {
    set imm [expr {($inst >> 20) & 0xFFF}]  

    if {[expr {($imm & (1 << 11)) >> 11}] == 1} {
      set imm [expr {-(((~$imm) & 0xFFF)+1)}]
    }
    return $imm
  }
  
  proc get_imm_s {inst} {
    set imm [expr {((($inst >> 25) & 0x7F) << 5) | \
                   ((($inst >> 7) & 0x1F) << 0) \
                  }]  
    if {[expr {($imm & (1 << 11)) >> 11}] == 1} {
      set imm [expr {-(((~$imm) & 0xFFF)+1)}]
    }
    return $imm
  }
  
  proc get_imm_b {inst} {
    set imm [expr {((($inst >> 31) & 0x1) << 12) | \
                   ((($inst >> 7) & 0x1) << 11) | \
                   ((($inst >> 25) & 0x3F) << 5) | \
                   ((($inst >> 8) & 0xF) << 1) \
                  }]  
    if {[expr {($imm & (1 << 11)) >> 11}] == 1} {
      set imm [expr {-(((~$imm) & 0xFFF)+1)}]
    }
    return $imm
  }
  
  proc get_imm_u {inst} {
    return [format 0x%05X [expr {($inst >> 12) & 0xFFFFF}]]  
  }
  
  proc get_imm_j {inst} {
    set imm [expr {((($inst >> 31) & 0x1) << 20) | \
                   ((($inst >> 12) & 0xFF) << 12) | \
                   ((($inst >> 20) & 0x1) << 11) | \
                   ((($inst >> 21) & 0x3FF) << 1) \
                  }]
    if {[expr {($imm & (1 << 20)) >> 20}] == 1} {
      set imm [expr {-(((~$imm) & 0x1FFFFF)+1)}]
    }
    return $imm
  }
  
  proc get_shamt32 {inst} {
    return [expr {($inst >> 20) & 0x1F}]  
  }
  
  proc get_shamt64 {inst} {
    return [expr {($inst >> 20) & 0x3F}]  
  }
 
  proc bin_decode { bitstream } {
    binary scan [binary format B* [format %032s $bitstream]] I value
    return $value
  }

  proc i_m {s} {
    variable dbg
    set base_v {2 0x3}
    set op_v {0 0x7F}
    set func2_v {25 0x3}
    set func3_v {12 0x7}
    set func4_v {28 0xF}
    set func5_v {27 0x1F}
    set func6_v {26 0x3F}
    set func7_v {25 0x7F}
    set imm_i_v {20 0xFFF}
    set imm_u_v {12 0xFFFFF}
    set rd_v {7 0x1F}
    set rs1_v {15 0x1F}
    set rs2_v {20 0x1F}
  
    set inst 0
    set mask 0
    set pesudo 0
  
    foreach {f vbits} $s {
      # tcl 8.6
      #set v [expr "0b$vbits"]
      set v [bin_decode $vbits]
      if       {$f == "op"} {
        if {$dbg} {puts "op: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $op_v 1]) << [lindex $op_v 0])}]
        set mask [expr {$mask | ([lindex $op_v 1] << [lindex $op_v 0])}]
      } elseif {$f == "func2"} {
        if {$dbg} {puts "func2: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func2_v 1]) << [lindex $func2_v 0])}]
        set mask [expr {$mask | ([lindex $func2_v 1] << [lindex $func2_v 0])}]
      } elseif {$f == "func3"} {
        if {$dbg} {puts "func3: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func3_v 1]) << [lindex $func3_v 0])}]
        set mask [expr {$mask | ([lindex $func3_v 1] << [lindex $func3_v 0])}]
      } elseif {$f == "func4"} {
        if {$dbg} {puts "func4: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func4_v 1]) << [lindex $func4_v 0])}]
        set mask [expr {$mask | ([lindex $func4_v 1] << [lindex $func4_v 0])}]
      } elseif {$f == "func5"} {
        if {$dbg} {puts "func5: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func5_v 1]) << [lindex $func5_v 0])}]
        set mask [expr {$mask | ([lindex $func5_v 1] << [lindex $func5_v 0])}]
      } elseif {$f == "func6"} {
        if {$dbg} {puts "func6: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func6_v 1]) << [lindex $func6_v 0])}]
        set mask [expr {$mask | ([lindex $func6_v 1] << [lindex $func6_v 0])}]
      } elseif {$f == "func7"} {
        if {$dbg} {puts "func7: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $func7_v 1]) << [lindex $func7_v 0])}]
        set mask [expr {$mask | ([lindex $func7_v 1] << [lindex $func7_v 0])}]
      } elseif {$f == "imm_i"} {
        if {$dbg} {puts "imm_i: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $imm_i_v 1]) << [lindex $imm_i_v 0])}]
        set mask [expr {$mask | ([lindex $imm_i_v 1] << [lindex $imm_i_v 0])}]
      } elseif {$f == "imm_u"} {
        if {$dbg} {puts "imm_u: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $imm_u_v 1]) << [lindex $imm_u_v 0])}]
        set mask [expr {$mask | ([lindex $imm_u_v 1] << [lindex $imm_u_v 0])}]
      } elseif {$f == "rd"} {
        if {$dbg} {puts "rd: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $rd_v 1]) << [lindex $rd_v 0])}]
        set mask [expr {$mask | ([lindex $rd_v 1] << [lindex $rd_v 0])}]
      } elseif {$f == "rs1"} {
        if {$dbg} {puts "rs1: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $rs1_v 1]) << [lindex $rs1_v 0])}]
        set mask [expr {$mask | ([lindex $rs1_v 1] << [lindex $rs1_v 0])}]
      } elseif {$f == "rs2"} {
        if {$dbg} {puts "rs2: $f, $v"}
        set inst [expr {$inst | (($v & [lindex $rs2_v 1]) << [lindex $rs2_v 0])}]
        set mask [expr {$mask | ([lindex $rs2_v 1] << [lindex $rs2_v 0])}]
      } elseif {$f == "inst"} {
        if {$dbg} {puts "inst: $f, $v"}
        set inst $v
        set mask 0xffffffff
      } elseif {$f == "pesudo"} {
        if {$dbg} {puts "pesudo: $f, $v"}
        set pesudo 1
      }
    }
    return [list $inst $mask $pesudo]
  }
  
  proc regs {regno} {
    variable dbg
    switch $regno {
      0  { return "zero" }
      1  { return "ra" }
      2  { return "sp" }
      3  { return "gp" }
      4  { return "tp" }
      5  { return "t0" }
      6  { return "t1" }
      7  { return "t2" }
      8  { return "fp" }
      9  { return "s1" }
      10 { return "a0" }
      11 { return "a1" }
      12 { return "a2" }
      13 { return "a3" }
      14 { return "a4" }
      15 { return "a5" }
      16 { return "a6" }
      17 { return "a7" }
      18 { return "s2" }
      19 { return "s3" }
      20 { return "s4" }
      21 { return "s5" }
      22 { return "s6" }
      23 { return "s7" }
      24 { return "s8" }
      25 { return "s9" }
      26 { return "s10" }
      27 { return "s11" }
      28 { return "t3" }
      29 { return "t4" }
      30 { return "t5" }
      31 { return "t6" }
    }
  }
  
  proc csrs {regno} {
    variable dbg
    if {$dbg} {puts "CSRS: $regno [format %03X $regno]"}
    switch $regno {
      0xF11 { return "mvendorid" }
      0xF12 { return "marchid" }
      0xF13 { return "mimpid" }
      0xF14 { return "mhartid" }
      0x300 { return "mstatus" }
      0x301 { return "misa" }
      0x302 { return "medeleg" }
      0x303 { return "mideleg" }
      0x304 { return "mie" }
      0x305 { return "mtvec" }
      0x306 { return "mcounteren" }
      0x340 { return "mscratch" }
      0x341 { return "mepc" }
      0x342 { return "mcause" }
      0x343 { return "mtval" } 
      0x344 { return "mip" }
      0x3A0 { return "pmpcfg0" }
      0x3A1 { return "pmpcfg1" }
      0x3A2 { return "pmpcfg2" }
      0x3A3 { return "pmpcfg3" }
      0x3B0 { return "pmpaddr0" }
      0x3B1 { return "pmpaddr1" }
      0x3B2 { return "pmpaddr2" }
      0x3B3 { return "pmpaddr3" }
      0x3B4 { return "pmpaddr4" }
      0x3B5 { return "pmpaddr5" }
      0x3B6 { return "pmpaddr6" }
      0x3B7 { return "pmpaddr7" }
      0x3B8 { return "pmpaddr8" }
      0x3B9 { return "pmpaddr9" }
      0x3BA { return "pmpaddr10" }
      0x3BB { return "pmpaddr11" }
      0x3BC { return "pmpaddr12" }
      0x3BD { return "pmpaddr13" }
      0x3BE { return "pmpaddr14" }
      0x3BF { return "pmpaddr15" }
      0xB00 { return "mcycle" }
      0xB02 { return "minstret" }
      0xB03 { return "mhpmcounter3" }
      0xB04 { return "mhpmcounter4" }
      0xB05 { return "mhpmcounter5" }
      0xB06 { return "mhpmcounter6" }
      0xB07 { return "mhpmcounter7" }
      0xB08 { return "mhpmcounter8" }
      0xB09 { return "mhpmcounter9" }
      0xB0A { return "mhpmcounter10" }
      0xB0B { return "mhpmcounter11" }
      0xB0C { return "mhpmcounter12" }
      0xB0D { return "mhpmcounter13" }
      0xB0E { return "mhpmcounter14" }
      0xB0F { return "mhpmcounter15" }
      0xB10 { return "mhpmcounter16" }
      0xB11 { return "mhpmcounter17" }
      0xB12 { return "mhpmcounter18" }
      0xB13 { return "mhpmcounter19" }
      0xB14 { return "mhpmcounter20" }
      0xB15 { return "mhpmcounter21" }
      0xB16 { return "mhpmcounter22" }
      0xB17 { return "mhpmcounter23" }
      0xB18 { return "mhpmcounter24" }
      0xB19 { return "mhpmcounter25" }
      0xB1A { return "mhpmcounter26" }
      0xB1B { return "mhpmcounter27" }
      0xB1C { return "mhpmcounter28" }
      0xB1D { return "mhpmcounter29" }
      0xB1E { return "mhpmcounter30" }
      0xB1F { return "mhpmcounter31" }
      0xB80 { return "mcycleh" }
      0xB82 { return "minstreth" }
      0xB83 { return "mhpmcounter3h" }
      0xB84 { return "mhpmcounter4h" }
      0xB85 { return "mhpmcounter5h" }
      0xB86 { return "mhpmcounter6h" }
      0xB87 { return "mhpmcounter7h" }
      0xB88 { return "mhpmcounter8h" }
      0xB89 { return "mhpmcounter9h" }
      0xB8A { return "mhpmcounter10h" }
      0xB8B { return "mhpmcounter11h" }
      0xB8C { return "mhpmcounter12h" }
      0xB8D { return "mhpmcounter13h" }
      0xB8E { return "mhpmcounter14h" }
      0xB8F { return "mhpmcounter15h" }
      0xB90 { return "mhpmcounter16h" }
      0xB91 { return "mhpmcounter17h" }
      0xB92 { return "mhpmcounter18h" }
      0xB93 { return "mhpmcounter19h" }
      0xB94 { return "mhpmcounter20h" }
      0xB95 { return "mhpmcounter21h" }
      0xB96 { return "mhpmcounter22h" }
      0xB97 { return "mhpmcounter23h" }
      0xB98 { return "mhpmcounter24h" }
      0xB99 { return "mhpmcounter25h" }
      0xB9A { return "mhpmcounter26h" }
      0xB9B { return "mhpmcounter27h" }
      0xB9C { return "mhpmcounter28h" }
      0xB9D { return "mhpmcounter29h" }
      0xB9E { return "mhpmcounter30h" }
      0xB9F { return "mhpmcounter31h" }
      0x323 { return "mhpmevent3" }
      0x324 { return "mhpmevent4" }
      0x325 { return "mhpmevent5" }
      0x326 { return "mhpmevent6" }
      0x327 { return "mhpmevent7" }
      0x328 { return "mhpmevent8" }
      0x329 { return "mhpmevent9" }
      0x32A { return "mhpmevent10" }
      0x32B { return "mhpmevent11" }
      0x32C { return "mhpmevent12" }
      0x32D { return "mhpmevent13" }
      0x32E { return "mhpmevent14" }
      0x32F { return "mhpmevent15" }
      0x330 { return "mhpmevent16" }
      0x331 { return "mhpmevent17" }
      0x332 { return "mhpmevent18" }
      0x333 { return "mhpmevent19" }
      0x334 { return "mhpmevent20" }
      0x335 { return "mhpmevent21" }
      0x336 { return "mhpmevent22" }
      0x337 { return "mhpmevent23" }
      0x338 { return "mhpmevent24" }
      0x339 { return "mhpmevent25" }
      0x33A { return "mhpmevent26" }
      0x33B { return "mhpmevent27" }
      0x33C { return "mhpmevent28" }
      0x33D { return "mhpmevent29" }
      0x33E { return "mhpmevent30" }
      0x33F { return "mhpmevent31" }
      0x7A0 { return "tselect" }
      0x7A1 { return "tdata1" }
      0x7A2 { return "tdata2" }
      0x7A3 { return "tdata3" }
      0x7B0 { return "dcsr" }
      0x7B1 { return "dpc" }
      0x7B2 { return "dscratch" }
      default { return "unknown" }
    }
  }
  
  set inst_list_32i [list \
    {lui $rd, $imm_u}           {*}[i_m {op 0110111}] \
    \
    {auipc $rd, $imm_u}         {*}[i_m {op 0010111}] \
    \
    {j $imm_j}                  {*}[i_m {op 1101111 rd 00000 pesudo 1}] \
    {jal $rd, $imm_j}           {*}[i_m {op 1101111}] \
    \
    {jalr $rd, $imm_i\($rs1)}   {*}[i_m {op 1100111 func3 000}] \
    \
    {beq $rs1, $rs2, $imm_b}    {*}[i_m {op 1100011 func3 000}] \
    {bne $rs1, $rs2, $imm_b}    {*}[i_m {op 1100011 func3 001}] \
    {blt $rs1, $rs2, $imm_b}    {*}[i_m {op 1100011 func3 100}] \
    {bge $rs1, $rs2, $imm_b}    {*}[i_m {op 1100011 func3 101}] \
    {bltu $rs1, $rs2, $imm_b}   {*}[i_m {op 1100011 func3 110}] \
    {bgeu $rs1, $rs2, $imm_b}   {*}[i_m {op 1100011 func3 111}] \
    \
    {lb $rd, $imm_i\($rs1)}     {*}[i_m {op 0000011 func3 000}] \
    {lh $rd, $imm_i\($rs1)}     {*}[i_m {op 0000011 func3 001}] \
    {lw $rd, $imm_i\($rs1)}     {*}[i_m {op 0000011 func3 010}] \
    {lbu $rd, $imm_i\($rs1)}    {*}[i_m {op 0000011 func3 100}] \
    {lhu $rd, $imm_i\($rs1)}    {*}[i_m {op 0000011 func3 101}] \
    \
    {sb $rs2, $imm_s\($rs1)}    {*}[i_m {op 0100011 func3 000}] \
    {sh $rs2, $imm_s\($rs1)}    {*}[i_m {op 0100011 func3 001}] \
    {sw $rs2, $imm_s\($rs1)}    {*}[i_m {op 0100011 func3 010}] \
    \
    {nop}                       {*}[i_m {op 0010011 func3 000 rd 00000 rs1 00000 imm_i 000000000000 pesudo 1}] \
    {li $rd, $imm_i}            {*}[i_m {op 0010011 func3 000 rs1 00000 pesudo 1}] \
    {mv $rd, $rs1}              {*}[i_m {op 0010011 func3 000 imm_i 000000000000 pesudo 1}] \
    {addi $rd, $rs1, $imm_i}    {*}[i_m {op 0010011 func3 000}] \
    {slti $rd, $rs1, $imm_i}    {*}[i_m {op 0010011 func3 010}] \
    {seqz $rd, $rs1}            {*}[i_m {op 0010011 func3 011 imm_i 000000000001 pesudo 1}] \
    {sltiu $rd, $rs1, $imm_i}   {*}[i_m {op 0010011 func3 011}] \
    {not $rd, $rs1}             {*}[i_m {op 0010011 func3 100 imm_i 111111111111 pesudo 1}] \
    {xori $rd, $rs1, $imm_i}    {*}[i_m {op 0010011 func3 100}] \
    {ori  $rd, $rs1, $imm_i}    {*}[i_m {op 0010011 func3 110}] \
    {andi $rd, $rs1, $imm_i}    {*}[i_m {op 0010011 func3 111}] \
    {slli $rd, $rs1, $shamt32}  {*}[i_m {op 0010011 func3 001 func7 0000000}] \
    {srli $rd, $rs1, $shamt32}  {*}[i_m {op 0010011 func3 101 func7 0000000}] \
    {srai $rd, $rs1, $shamt32}  {*}[i_m {op 0010011 func3 101 func7 0100000}] \
    \
    {add $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 000 func7 0000000}] \
    {sub $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 000 func7 0100000}] \
    {sll $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 001 func7 0000000}] \
    {slt $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 010 func7 0000000}] \
    {sltu $rd, $rs1, $rs2}      {*}[i_m {op 0110011 func3 011 func7 0000000}] \
    {xor $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 100 func7 0000000}] \
    {srl $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 101 func7 0000000}] \
    {sra $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 101 func7 0100000}] \
    {or $rd, $rs1, $rs2}        {*}[i_m {op 0110011 func3 110 func7 0000000}] \
    {and $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 111 func7 0000000}] \
    \
    {fence}                     {*}[i_m {op 0001111 func3 000 rd 00000 rs1 00000 func4 0000}] \
    {fence.i}                   {*}[i_m {op 0001111 func3 001 rd 00000 rs1 00000 imm_i 000000000000}] \
    \
    {ecall}                     {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 000000000000}] \
    {ebreak}                    {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 000000000001}] \
    {csrrw $rd, $csr, $rs1}     {*}[i_m {op 1110011 func3 001}] \
    {csrrs $rd, $csr, $rs1}     {*}[i_m {op 1110011 func3 010}] \
    {csrrc $rd, $csr, $rs1}     {*}[i_m {op 1110011 func3 011}] \
    {csrrwi $rd, $csr, $zimm}   {*}[i_m {op 1110011 func3 101}] \
    {csrrsi $rd, $csr, $zimm}   {*}[i_m {op 1110011 func3 110}] \
    {csrrci $rd, $csr, $zimm}   {*}[i_m {op 1110011 func3 111}] \
  ]
  
  set inst_list_64i [list \
    {lwu $rd, $imm_i\($rs1)}    {*}[i_m {op 0000011 func3 110}] \
    {ld $rd, $imm_i\($rs1)}     {*}[i_m {op 0000011 func3 011}] \
    \
    {sd $rs2, $imm_s\($rs1)}    {*}[i_m {op 0100011 func3 011}] \
    \
    {slli $rd, $rs1, $shamt64}  {*}[i_m {op 0010011 func3 001 func6 000000}] \
    {srli $rd, $rs1, $shamt64}  {*}[i_m {op 0010011 func3 101 func6 000000}] \
    {srai $rd, $rs1, $shamt64}  {*}[i_m {op 0010011 func3 101 func6 010000}] \
    \
    {addiw $rd, $rs1, $imm_i}   {*}[i_m {op 0011011 func3 000}] \
    {slliw $rd, $rs1, $shamt32} {*}[i_m {op 0010011 func3 001 func7 0000000}] \
    {srliw $rd, $rs1, $shamt32} {*}[i_m {op 0010011 func3 101 func7 0000000}] \
    {sraiw $rd, $rs1, $shamt32} {*}[i_m {op 0010011 func3 101 func7 0100000}] \
    \
    {addw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 000 func7 0000000}] \
    {subw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 000 func7 0100000}] \
    {sllw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 001 func7 0000000}] \
    {srlw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 101 func7 0000000}] \
    {sraw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 101 func7 0100000}] \
  ]
  
  set inst_list_32m [list \
    {mul $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 000 func7 0000001}] \
    {mulh $rd, $rs1, $rs2}      {*}[i_m {op 0110011 func3 001 func7 0000001}] \
    {mulhsu $rd, $rs1, $rs2}    {*}[i_m {op 0110011 func3 010 func7 0000001}] \
    {mulhu $rd, $rs1, $rs2}     {*}[i_m {op 0110011 func3 011 func7 0000001}] \
    {div $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 100 func7 0000001}] \
    {divu $rd, $rs1, $rs2}      {*}[i_m {op 0110011 func3 101 func7 0000001}] \
    {rem $rd, $rs1, $rs2}       {*}[i_m {op 0110011 func3 110 func7 0000001}] \
    {remu $rd, $rs1, $rs2}      {*}[i_m {op 0110011 func3 111 func7 0000001}] \
  ]
  
  set inst_list_64m [list \
    {mulw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 000 func7 0000001}] \
    {divw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 100 func7 0000001}] \
    {divu $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 101 func7 0000001}] \
    {remw $rd, $rs1, $rs2}      {*}[i_m {op 0111011 func3 110 func7 0000001}] \
    {remuw $rd, $rs1, $rs2}     {*}[i_m {op 0111011 func3 111 func7 0000001}] \
  ]
  
  set inst_list_32a [list \
    {lr.w $rd, ($rs1)}          {*}[i_m {op 0101111 func3 010 func5 00010 rs2 00000}] \
    {sc.w $rd, ($rs1)}          {*}[i_m {op 0101111 func3 010 func5 00011}] \
    {amoswap.w $rd, ($rs1)}     {*}[i_m {op 0101111 func3 010 func5 00001}] \
    {amoadd.w $rd, ($rs1)}      {*}[i_m {op 0101111 func3 010 func5 00000}] \
    {amoxor.w $rd, ($rs1)}      {*}[i_m {op 0101111 func3 010 func5 00100}] \
    {amoand.w $rd, ($rs1)}      {*}[i_m {op 0101111 func3 010 func5 01100}] \
    {amoor.w $rd, ($rs1)}       {*}[i_m {op 0101111 func3 010 func5 01000}] \
    {amomin.w $rd, ($rs1)}      {*}[i_m {op 0101111 func3 010 func5 10000}] \
    {amomax.w $rd, ($rs1)}      {*}[i_m {op 0101111 func3 010 func5 10100}] \
    {amominu.w $rd, ($rs1)}     {*}[i_m {op 0101111 func3 010 func5 11000}] \
    {amomaxu.w $rd, ($rs1)}     {*}[i_m {op 0101111 func3 010 func5 11100}] \
  ]
  
  set inst_list_64a [list \
    {lr.d $rd, ($rs1)}          {*}[i_m {op 0101111 func3 011 func5 00010 rs2 00000}] \
    {sc.d $rd, ($rs1)}          {*}[i_m {op 0101111 func3 011 func5 00011}] \
    {amoswap.d $rd, ($rs1)}     {*}[i_m {op 0101111 func3 011 func5 00001}] \
    {amoadd.d $rd, ($rs1)}      {*}[i_m {op 0101111 func3 011 func5 00000}] \
    {amoxor.d $rd, ($rs1)}      {*}[i_m {op 0101111 func3 011 func5 00100}] \
    {amoand.d $rd, ($rs1)}      {*}[i_m {op 0101111 func3 011 func5 01100}] \
    {amoor.d $rd, ($rs1)}       {*}[i_m {op 0101111 func3 011 func5 01000}] \
    {amomin.d $rd, ($rs1)}      {*}[i_m {op 0101111 func3 011 func5 10000}] \
    {amomax.d $rd, ($rs1)}      {*}[i_m {op 0101111 func3 011 func5 10100}] \
    {amominu.d $rd, ($rs1)}     {*}[i_m {op 0101111 func3 011 func5 11000}] \
    {amomaxu.d $rd, ($rs1)}     {*}[i_m {op 0101111 func3 011 func5 11100}] \
  ]
  
  set inst_list_32f [list \
    {flw $rd, $imm_i\($rs1)}          {*}[i_m {op 0000111 func3 010}] \
    {fsw $rs2, $imm_s\($rs1)}         {*}[i_m {op 0100111 func3 010}] \
    {fmadd.s $rd, $rs1, $rs2, $rs3}   {*}[i_m {op 1000011           func2 00}] \
    {fmsub.s $rd, $rs1, $rs2, $rs3}   {*}[i_m {op 1000111           func2 00}] \
    {fnmsub.s $rd, $rs1, $rs2, $rs3}  {*}[i_m {op 1001011           func2 00}] \
    {fnmadd.s $rd, $rs1, $rs2, $rs3}  {*}[i_m {op 1001111           func2 00}] \
    {fadd.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0000000}] \
    {fsub.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0000100}] \
    {fmul.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0001000}] \
    {fdiv.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0001100}] \
    {fsqrt.s $rd, $rs1}               {*}[i_m {op 1010011           func7 0101100 rs2 00000}] \
    {fsgnj.s $rd, $rs1, $rs2}         {*}[i_m {op 1010011 func3 000 func7 0010000}] \
    {fsgnjn.s $rd, $rs1, $rs2}        {*}[i_m {op 1010011 func3 001 func7 0010000}] \
    {fsgnjx.s $rd, $rs1, $rs2}        {*}[i_m {op 1010011 func3 010 func7 0010000}] \
    {fmin.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011 func3 000 func7 0010100}] \
    {fmax.s $rd, $rs1, $rs2}          {*}[i_m {op 1010011 func3 001 func7 0010100}] \
    {fcvt.w.s $rd, $rs1}              {*}[i_m {op 1010011           func7 1100000 rs2 00000}] \
    {fcvt.wu.s $rd, $rs1}             {*}[i_m {op 1010011           func7 1100000 rs2 00001}] \
    {fmv.x.w $rd, $rs1}               {*}[i_m {op 1010011 func3 000 func7 1110000 rs2 00000}] \
    {feq.s $rd, $rs1, $rs2}           {*}[i_m {op 1010011 func3 010 func7 1010000}] \
    {flt.s $rd, $rs1, $rs2}           {*}[i_m {op 1010011 func3 001 func7 1010000}] \
    {fle.s $rd, $rs1, $rs2}           {*}[i_m {op 1010011 func3 000 func7 1010000}] \
    {fclass.s $rd, $rs1}              {*}[i_m {op 1010011 func3 001 func7 1110000 rs2 00000}] \
    {fcvt.s.w $rd, $rs1}              {*}[i_m {op 1010011           func7 1101000 rs2 00000}] \
    {fcvt.s.wu $rd, $rs1}             {*}[i_m {op 1010011           func7 1101000 rs2 00001}] \
    {fmv.w.x $rd, $rs1}               {*}[i_m {op 1010011 func3 000 func7 1111000 rs2 00000}] \
  ]
  
  set inst_list_64f [list \
    {fcvt.l.s $rd, $rs1}              {*}[i_m {op 1010011           func7 1100000 rs2 00010}] \
    {fcvt.lu.s $rd, $rs1}             {*}[i_m {op 1010011           func7 1100000 rs2 00011}] \
    {fcvt.s.l $rd, $rs1}              {*}[i_m {op 1010011           func7 1101000 rs2 00010}] \
    {fcvt.s.lu $rd, $rs1}             {*}[i_m {op 1010011           func7 1101000 rs2 00011}] \
  ]
  
  set inst_list_32d [list \
    {fld $rd, $imm_i\($rs1)}          {*}[i_m {op 0000111 func3 011}] \
    {fsd $rs2, $imm_s\($rs1)}         {*}[i_m {op 0100111 func3 011}] \
    {fmadd.d $rd, $rs1, $rs2, $rs3}   {*}[i_m {op 1000011           func2 01}] \
    {fmsub.d $rd, $rs1, $rs2, $rs3}   {*}[i_m {op 1000111           func2 01}] \
    {fnmsub.d $rd, $rs1, $rs2, $rs3}  {*}[i_m {op 1001011           func2 01}] \
    {fnmadd.d $rd, $rs1, $rs2, $rs3}  {*}[i_m {op 1001111           func2 01}] \
    {fadd.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0000001}] \
    {fsub.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0000101}] \
    {fmul.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0001001}] \
    {fdiv.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011           func7 0001101}] \
    {fsqrt.d $rd, $rs1}               {*}[i_m {op 1010011           func7 0101101 rs2 00000}] \
    {fsgnj.d $rd, $rs1, $rs2}         {*}[i_m {op 1010011 func3 000 func7 0010001}] \
    {fsgnjn.d $rd, $rs1, $rs2}        {*}[i_m {op 1010011 func3 001 func7 0010001}] \
    {fsgnjx.d $rd, $rs1, $rs2}        {*}[i_m {op 1010011 func3 010 func7 0010001}] \
    {fmin.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011 func3 000 func7 0010101}] \
    {fmax.d $rd, $rs1, $rs2}          {*}[i_m {op 1010011 func3 001 func7 0010101}] \
    {fcvt.s.d $rd, $rs1}              {*}[i_m {op 1010011           func7 0100000 rs2 00001}] \
    {fcvt.d.s $rd, $rs1}              {*}[i_m {op 1010011           func7 0100001 rs2 00000}] \
    {feq.d $rd, $rs1}                 {*}[i_m {op 1010011 func3 010 func7 1010001}] \
    {flt.d $rd, $rs1, $rs2}           {*}[i_m {op 1010011 func3 001 func7 1010001}] \
    {fle.d $rd, $rs1, $rs2}           {*}[i_m {op 1010011 func3 000 func7 1010001}] \
    {fclass.d $rd, $rs1, $rs2}        {*}[i_m {op 1010011 func3 001 func7 1110001 rs2 00000}] \
    {fcvt.w.d $rd, $rs1}              {*}[i_m {op 1010011           func7 1100001 rs2 00000}] \
    {fcvt.wu.d $rd, $rs1}             {*}[i_m {op 1010011           func7 1100001 rs2 00001}] \
    {fcvt.d.w $rd, $rs1}              {*}[i_m {op 1010011           func7 1101001 rs2 00000}] \
    {fcvt.d.wu $rd, $rs1}             {*}[i_m {op 1010011           func7 1101001 rs2 00001}] \
  ]
  
  set inst_list_64d [list \
    {fcvt.l.d $rd, $rs1}              {*}[i_m {op 1010011           func7 1100001 rs2 00010}] \
    {fcvt.lu.d $rd, $rs1}             {*}[i_m {op 1010011           func7 1100001 rs2 00011}] \
    {fmv.x.d $rd, $rs1}               {*}[i_m {op 1010011 func3 000 func7 1110001 rs2 00000}] \
    {fcvt.d.l $rd, $rs1}              {*}[i_m {op 1010011           func7 1101001 rs2 00010}] \
    {fcvt.d.lu $rd, $rs1}             {*}[i_m {op 1010011           func7 1101001 rs2 00011}] \
    {fmv.d.x $rd, $rs1}               {*}[i_m {op 1010011 func3 000 func7 1111001 rs2 00000}] \
  ]

  set inst_list_prv [list \
    {uret}                    {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 000000000010}] \
    {sret}                    {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 000100000010}] \
    {mret}                    {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 001100000010}] \
    {wfi}                     {*}[i_m {op 1110011 func3 000 rd 00000 rs1 00000 imm_i 000100000101}] \
    {sfence.vma $rs1, $rs2}   {*}[i_m {op 1110011 func3 000 rd 00000 func7 0001001}] \
    {hfence.bvma $rs1, $rs2}  {*}[i_m {op 1110011 func3 000 rd 00000 func7 0010001}] \
    {hfence.gvma $rs1, $rs2}  {*}[i_m {op 1110011 func3 000 rd 00000 func7 1010001}] \
  ]
  
  variable inst_list [list {*}$inst_list_prv]
  lappend  inst_list {*}$inst_list_32i
  lappend  inst_list {*}$inst_list_64i
  lappend  inst_list {*}$inst_list_32m
  lappend  inst_list {*}$inst_list_64m
  lappend  inst_list {*}$inst_list_32a
  lappend  inst_list {*}$inst_list_64a
  lappend  inst_list {*}$inst_list_32f
  lappend  inst_list {*}$inst_list_64f
  lappend  inst_list {*}$inst_list_32d
  lappend  inst_list {*}$inst_list_64d

  variable pesudo 1

  proc inst2string {inst} {
    variable dbg
    variable inst_list
    variable pesudo
    set base [get_base $inst]
    set op [get_op $inst]
    set func2 [get_func2 $inst]
    set func3 [get_func3 $inst]
    set func5 [get_func5 $inst]
    set func6 [get_func6 $inst]
    set func7 [get_func7 $inst]
    set rs1 [regs [get_rs1 $inst]]
    set rs2 [regs [get_rs2 $inst]]
    set rs3 [regs [get_rs3 $inst]]
    set csr [csrs [format 0x%03X [get_imm_i $inst]]]
    set rd [regs [get_rd $inst]]
    set imm_i [get_imm_i $inst]
    set imm_s [get_imm_s $inst]
    set imm_b [get_imm_b $inst]
    set imm_u [get_imm_u $inst]
    set imm_j [get_imm_j $inst]
    set shamt32 [get_shamt32 $inst]
    set shamt64 [get_shamt64 $inst]
    set zimm [get_rs1 $inst]

    foreach {s i m p} $inst_list {
      if {$pesudo == 1 | $p == 0} {
        if {[expr {$inst & $m}] == $i} {
          if {$dbg} {puts "Match inst $j"}
          return "[subst $s]"
        }
      }
      incr j
    }
    if {$dbg} {puts "No match inst"}
    return "unimp"
  }

  proc disassemble {{addr 0x40000000} {count 20}} {
    set data [silent mem -hex $addr [expr $count*4]]
    set i 0
    foreach {d0} $data {
      puts "[format 0x%08X [expr $addr+4*$i]]: [format %s $d0]  [inst2string 0x$d0]"
      incr i
    }
  }
}

namespace eval rv_tbuf {
  variable dbg 0
  variable print_all 0

  proc print_xc {x} {
    set d [format %d $x]
    switch $d {
       0 { return "addr_misaligned"}
       1 { return "access_fault"}
       2 { return "illegal_inst"}
       3 { return "breakpoint"}
       4 { return "load_addr_misaligned"}
       5 { return "load_access_fault"}
       6 { return "store_addr_misaligned"}
       7 { return "store_access_fault"}
       8 { return "env_call_umode"}
       9 { return "env_call_smode"}
      11 { return "env_call_mmode"}
      12 { return "inst_page_fault"}
      13 { return "load_page_fault"}
      15 { return "store_page_fault"}
    }
  }

  proc read_addr {} {
    variable dbg

    return [::rv::reg_read 0xC009]
  }

  proc read_entry {addr} {
    variable dbg
    
    set res [list]

    ::rv::reg_write 0xC008 $addr

    for {set i 0} {$i < 7} {incr i} {
      set tmp [::rv::reg_read [expr {0xc000 + $i}]]
      lappend res [format %08X [expr $tmp & 0xFFFFFFFF]] [format %08X [expr ($tmp >> 32) & 0xFFFFFFFF]]
    }

    return $res
  }
  
  proc print_entry {e} {
    variable dbg
    variable print_all
    
    if {$dbg} {
      set i 0
      foreach x $e {
        puts "$i $x [expr {($i*32)+31}] : [expr {$i*32}]"
        incr i
      }
    }

    set inst0 "0x[lindex $e 0]"
    set res0 "0x[lindex $e 2][lindex $e 1]"
    set pc0 [format 0x%016X [expr {(("0x[lindex $e 4][lindex $e 3]") & 0xFFFFFFFFFFFF)}]]
    set timestamp [format %010d [expr {(("0x[lindex $e 5][lindex $e 4]") >> (143-128) & 0xFFFFFFFF)}]]
    set xc_val [format 0x%016X [expr {(("0x[lindex $e 6][lindex $e 5]") >> (175-160) & 0xFFFFFFFFFFFFFFFF)}]]
    set xc_val [format 0x%016X [expr {((("0x[lindex $e 7]" << (64-(175-160))) + $xc_val) & 0xFFFFFFFFFFFFFFFF)}]]
    set xc_cause [format 0x%02X [expr {(("0x[lindex $e 7]" >> (239-224)) & 0xFF)}]]
    set int_flag [format 0x%1X [expr {(("0x[lindex $e 7]" >> (247-224)) & 0x1)}]]
    set xc_flag [format 0x%1X [expr {(("0x[lindex $e 7]" >> (248-224)) & 0x3)}]]
    set multi [format 0x%1X [expr {(("0x[lindex $e 7]" >> (250-224)) & 0x3)}]]
    set prv [format 0x%1X [expr {(("0x[lindex $e 7]" >> (252-224)) & 0x3)}]]
    set valid0 [format 0x%1X [expr {(("0x[lindex $e 7]" >> (254-224)) & 0x1)}]]
    set valid1 [format 0x%1X [expr {(("0x[lindex $e 7]" >> (255-224)) & 0x1)}]]
    set inst1 "0x[lindex $e 8]"
    set res1 "0x[lindex $e 10][lindex $e 9]"
    set pc1 [format 0x%016X [expr {(("0x[lindex $e 12][lindex $e 11]") & 0xFFFFFFFFFFFF)}]]

    if {$dbg} {
      puts "inst0: $inst0"
      puts "res0: $res0"
      puts "pc0: $pc0"
      puts "timestamp: $timestamp"
      puts "xc_val: $xc_val"
      puts "xc_cause: $xc_cause"
      puts "int_flag: $int_flag"
      puts "xc_flag: $xc_flag"
      puts "multi: $multi"
      puts "prv: $prv"
      puts "valid0: $valid0"
      puts "valid1: $valid1"
      puts "inst1: $inst1"
      puts "res1: $res1"
      puts "pc1: $pc1"
    }
    
    if {$print_all} {
      set xc_str "xc\[[print_xc $xc_cause]\]: cause\[$xc_cause\] val\[$xc_val\] prv\[$prv\] int\[$int_flag\]"
    } else {
      set xc_str "xc\[[print_xc $xc_cause]\]"
    }
    
    if {$valid0 == 1} {
      if {[expr {$xc_flag & 1} == 1]} {
        puts "I0 $timestamp: @$pc0 ($inst0) [::rv_dis::inst2string $inst0] \[$res0\] $xc_str"
      } else {
        puts "I0 $timestamp: @$pc0 ($inst0) [::rv_dis::inst2string $inst0] \[$res0\]"
      }
    }
    if {$valid1 == 1} {
      if {[expr {($xc_flag >> 1) & 1} == 1]} {
        puts "I1 $timestamp: @$pc1 ($inst1) [::rv_dis::inst2string $inst1] \[$res1\] $xc_str"
      } else {
        puts "I1 $timestamp: @$pc1 ($inst1) [::rv_dis::inst2string $inst1] \[$res1\]"
      }
    }
  }
  proc print_trace {{cnt 10}} {
    variable dbg
    set tr [list]

    set addr [expr {[read_addr] - 1}]
    
    for {set i 0} {$i < $cnt} {incr i} { 
      set tr [list [read_entry [expr {$addr - $i}]] {*}$tr]
    }
    foreach t $tr {
      print_entry $t
    }
  }
}
#####################################################################################
# Install Risc-V command
#####################################################################################
if {[namespace exists ::rvdm0] && $grmon_shell == "cli"} {
  puts "Risc-V Debug module available"

  ::rv::install

#  set ::rv::dev rvdm0
#
#  rename run _sparc_run
#  interp alias {} run {} ::rv::run
#  
#  rename step _sparc_step
#  interp alias {} step {} ::rv::step
#
#  rename reg _sparc_reg
#  interp alias {} reg {} ::rv::reg
#
#  rename cont _sparc_cont
#  interp alias {} cont {} ::rv::cont
#  
#  rename disassemble _sparc_disassemble
#  interp alias {} disassemble {} ::rv_dis::disassemble
#
#  rename inst _sparc_inst
#  interp alias {} inst {} ::rv_tbuf::print_trace
}

