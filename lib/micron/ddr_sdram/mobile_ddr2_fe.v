/****************************************************************************************
*
* Name:  mobile_ddr2.v
*      Version:  0.96
*        Model:  BUS Functional
*
* Dependencies:  mobile_ddr2_parameters.vh
*
*  Description:  Micron MOBILE SDRAM DDR2 (Double Data Rate 2)
*
*   Limitation:  - doesn't check all refresh timings (tREFW, tREFI)
*                - positive ck and ck_n edges are used to form internal clock
*                - positive dqs and dqs_n edges are used to latch data
*                - mode registers settings are not checked for legal values
*                - PASR_Bank, PASR_Segment and Refresh Rate mode registers are not modeled
*                - setup and hold checking is not performed on command or data bus
*                - clock period is not checked
*                - write data strobes are not checked for correct timings
*                - DPD does not clear memory array when `MAX_MEM is defined
*
*         Note:  - Set simulator resolution to "ps" accuracy
*                - Set mcd_info = 0 to disable $display messages
*
*   Disclaimer   This software code and all associated documentation, comments or other 
*  of Warranty:  information (collectively "Software") is provided "AS IS" without 
*                warranty of any kind. MICRON TECHNOLOGY, INC. ("MTI") EXPRESSLY 
*                DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
*                TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
*                OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. MTI DOES NOT 
*                WARRANT THAT THE SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE 
*                OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. 
*                FURTHERMORE, MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR 
*                THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS, 
*                ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT OF USE 
*                OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO EVENT SHALL MTI, 
*                ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, 
*                INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR SPECIAL DAMAGES (INCLUDING, 
*                WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, BUSINESS INTERRUPTION, 
*                OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE 
*                THE SOFTWARE, EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
*                DAMAGES. Because some jurisdictions prohibit the exclusion or 
*                limitation of liability for consequential or incidental damages, the 
*                above limitation may not apply to you.
*
*                Copyright 2003 Micron Technology, Inc. All rights reserved.
*
* Rev   Author   Date        Changes
* ---------------------------------------------------------------------------------------
* 0.00  JMK      01/04/08    Initial Release
* 0.10  JMK      01/08/08    Fixed Burst Wrap
* 0.20  JMK      01/17/08    Fixed timing checks for tMRR, tRFCpb, tRAS, tWR, tRTP, tRPPb
*                            Fixed burst interrupt for WR->WR, RD->RD, WR->BST, RD->BST
*                            Changed MRR to return 'x' except on first data beat of DQ[7:0]
* 0.30  JMK      01/31/08    Fixed BL4 + No Wrap
*                            Fixed Write with Auto Precharge timing checks
*                            Fixed timing checking for tRFCpb and tRFCab
* 0.40  JMK      02/26/08    Added LPDDR2-S2 support.  S2/S4 selected using SX parameter
* 0.50  JMK      05/28/08    Fixed tCCD check for LPDDR2-S2
* 0.60  JMK      08/15/08    Fixed timing checks for WR->RD, WR->PRE for partial writes
*                            Updated to match JEDEC Item #1725.01 LPDDR2 Draft Spec
*                            Changed $display to $fdisplay for info/errors/warnings/failures
* 0.70  JMK      09/19/08    Fixed MRR to odd address.
* 0.90  JMK      05/08/09    Fixed a compile error when MAX_MEM was defined
*                            Forced floating point division on arguments passed to 
*                              the ceil function by multiplying operands by 1.0
* 0.92  MYY      05/17/10    Added MRR 32/40 read out
* 0.94  MYY      08/09/10    Use File Access memory mode
* 0.96  MYY      02/27/12    Ignore PREab during init
****************************************************************************************/

// DO NOT CHANGE THE TIMESCALE
// MAKE SURE YOUR SIMULATOR USES "PS" RESOLUTION
`timescale 1ps / 1ps

module mobile_ddr2_fe (
    ck,
    ck_n,
    cke,
    cs_n,
    ca,
    dm,
    dq,
    dqs,
    dqs_n,
    BEaddr, BEwr_h, BEwr_l, BEdin_h, BEdin_l, BEdout_h, BEdout_l, BEclear, BEreload, BEsynco, BEsynci
);
//    `include "mobile_ddr2_parameters.vh"

`define sg25
`define x16
`define REQUIRE_ZQINIT
// --------- Inlined mobile_ddr2_parameters.vh begins
/****************************************************************************************
*
*   Disclaimer   This software code and all associated documentation, comments or other 
*  of Warranty:  information (collectively "Software") is provided "AS IS" without 
*                warranty of any kind. MICRON TECHNOLOGY, INC. ("MTI") EXPRESSLY 
*                DISCLAIMS ALL WARRANTIES EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
*                TO, NONINFRINGEMENT OF THIRD PARTY RIGHTS, AND ANY IMPLIED WARRANTIES 
*                OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. MTI DOES NOT 
*                WARRANT THAT THE SOFTWARE WILL MEET YOUR REQUIREMENTS, OR THAT THE 
*                OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE. 
*                FURTHERMORE, MTI DOES NOT MAKE ANY REPRESENTATIONS REGARDING THE USE OR 
*                THE RESULTS OF THE USE OF THE SOFTWARE IN TERMS OF ITS CORRECTNESS, 
*                ACCURACY, RELIABILITY, OR OTHERWISE. THE ENTIRE RISK ARISING OUT OF USE 
*                OR PERFORMANCE OF THE SOFTWARE REMAINS WITH YOU. IN NO EVENT SHALL MTI, 
*                ITS AFFILIATED COMPANIES OR THEIR SUPPLIERS BE LIABLE FOR ANY DIRECT, 
*                INDIRECT, CONSEQUENTIAL, INCIDENTAL, OR SPECIAL DAMAGES (INCLUDING, 
*                WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS, BUSINESS INTERRUPTION, 
*                OR LOSS OF INFORMATION) ARISING OUT OF YOUR USE OF OR INABILITY TO USE 
*                THE SOFTWARE, EVEN IF MTI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH 
*                DAMAGES. Because some jurisdictions prohibit the exclusion or 
*                limitation of liability for consequential or incidental damages, the 
*                above limitation may not apply to you.
*
*                Copyright 2003 Micron Technology, Inc. All rights reserved.
*
****************************************************************************************/

    // Parameters current with G80A datasheet rev 1.1
`define lpddr2_4Gb

    // Timing parameters based on Speed Grade

                                              // SYMBOL UNITS DESCRIPTION
                                              // ------ ----- -----------
`ifdef sg18
    parameter TCK_MIN           =       1875; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        200; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        210; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        210; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        220; // tIS      ps  Input Setup Time
    parameter TIH               =        220; // tIH      ps  Input Hold Time
    parameter TWTR              =       7500; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       5620; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else `ifdef sg215
    parameter TCK_MIN           =       2150; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        220; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        235; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        235; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        250; // tIS      ps  Input Setup Time
    parameter TIH               =        250; // tIH      ps  Input Hold Time
    parameter TWTR              =       7500; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else `ifdef sg25
    parameter TCK_MIN           =       2500; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        240; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        270; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        270; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        290; // tIS      ps  Input Setup Time
    parameter TIH               =        290; // tIH      ps  Input Hold Time
    parameter TWTR              =       7500; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else `ifdef sg3
    parameter TCK_MIN           =       3000; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        280; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        350; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        350; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        370; // tIS      ps  Input Setup Time
    parameter TIH               =        370; // tIH      ps  Input Hold Time
    parameter TWTR              =       7500; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else `ifdef sg37
    parameter TCK_MIN           =       3750; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        340; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        430; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        430; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        460; // tIS      ps  Input Setup Time
    parameter TIH               =        460; // tIH      ps  Input Hold Time
    parameter TWTR              =       7500; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else `ifdef sg5
    parameter TCK_MIN           =       5000; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        400; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        480; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        480; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        600; // tIS      ps  Input Setup Time
    parameter TIH               =        600; // tIH      ps  Input Hold Time
    parameter TWTR              =      10000; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      50000; // tFAW     ps  Four-Bank Activate Window
`else 
`define sg6
    parameter TCK_MIN           =       6000; // tCK      ps  Minimum Clock Cycle Time
    parameter TDQSQ             =        500; // tDQSQ    ps  DQS-DQ skew, DQS to last DQ valid, per group, per access
    parameter TDS               =        600; // tDS      ps  DQ and DM input setup time relative to DQS
    parameter TDH               =        600; // tDH      ps  DQ and DM input hold time relative to DQS
    parameter TIS               =        740; // tIS      ps  Input Setup Time
    parameter TIH               =        740; // tIH      ps  Input Hold Time
    parameter TWTR              =      10000; // tWTR     ps  Write to Read command delay
    parameter TDQSCK_MAX        =       6000; // tDQSCK   ps  DQS output access time from CK/CK#
    parameter TFAW              =      60000; // tFAW     ps  Four-Bank Activate Window
`endif `endif `endif `endif `endif `endif

    // Timing Parameters

    // Clock
    parameter CKH_MIN           =       0.45; // tCH      tCK Minimum Clock High-Level Pulse Width
    parameter CKH_MAX           =       0.55; // tCH      tCK Maximum Clock High-Level Pulse Width
    parameter CKL_MIN           =       0.45; // tCL      tCK Minimum Clock Low-Level Pulse Width
    parameter CKL_MAX           =       0.55; // tCL      tCK Maximum Clock Low-Level Pulse Width
    // Read
    parameter TDQSCK            =       2500; // tDQSCK   ps  DQS output access time from CK/CK#
    // Write
    parameter TDIPW             =       0.35; // tDIPW    tCK DQ and DM input Pulse Width
    parameter DQSH              =       0.40; // tDQSH    tCK DQS input High Pulse Width
    parameter DQSL              =       0.40; // tDQSL    tCK DQS input Low Pulse Width
    parameter DQSS              =       0.75; // tDQSS    tCK Rising clock edge to DQS/DQS# latching transition
    parameter DSS               =       0.20; // tDSS     tCK DQS falling edge to CLK rising (setup time)
    parameter DSH               =       0.20; // tDSH     tCK DQS falling edge from CLK rising (hold time)
    parameter WPRE              =       0.35; // tWPRE    tCK DQS Write Preamble
    parameter WPST              =       0.40; // tWPST    tCK DQS Write Postamble
    // CKE
    parameter CKE               =          3; // tCKE     tCK CKE minimum high or low pulse width
    parameter TCKESR            =      15000; // tCKESR   ps  CKE minimum high or low pulse width self refresh
    parameter ISCKE             =       0.25; // tISCKE   tCK CKE Input Setup Time
    parameter IHCKE             =       0.25; // tIHCKE   tCK CKE Input Hold Time
    // Mode Register
    parameter MRR               =          2; // tMRR     tCK Load Mode Register command cycle time
    parameter MRW               =          3; // tMRW     tCK Load Mode Register command cycle time
    parameter CL_MIN            =          3; // CL       tCK Minimum CAS Latency
    parameter CL_MAX            =          8; // CL       tCK Maximum CAS Latency
    parameter TCL               =      15000; // CL       ps  Minimum CAS Latency
    parameter WR_MIN            =          2; // WR       tCK Minimum Write Recovery
    parameter WR_MAX            =          6; // WR       tCK Maximum Write Recovery
    parameter BL_MIN            =          4; // BL       tCK Minimum Burst Length
    parameter BL_MAX            =         16; // BL       tCK Minimum Burst Length
    parameter MR8RESID          =      2'b00;
    parameter DLLK              =        200; // tDLLK    tCK DLL locking time
    // Command and Address
    parameter CCD               =          2; // tCCD     tCK Cas to Cas command delay
    parameter TDPD              =  500000000; // tDPD     ps  Minimum Deep Power-Down time
    parameter FAW               =          8; // tFAW     tCK Four-Bank Activate Window
    parameter TIPW              =        0.4; // tIPW     tCK Control and Address input Pulse Width  
    parameter TRAS              =      42000; // tRAS     ps  Minimum Active to Precharge command time
    parameter RAS               =          3; // tRAS     tCK Minimum Active to Precharge command time
    parameter TRCD              =      15000; // tRCD     ps  Active to Read/Write command time
    parameter RCD               =          3; // tRCD     tCK Active to Read/Write command time
    parameter TRPAB             =      18000; // tRPab    ps  Precharge All command period
    parameter RPAB              =          3; // tRPab    tCK Precharge All command period
    parameter TRPPB             =      15000; // tRPpb    ps  Precharge command period
    parameter RPPB              =          3; // tRPpb    tCK Precharge command period
    parameter TRRD              =      10000; // tRRD     ps  Active bank a to Active bank b command time
    parameter RRD               =          2; // tRRD     tCK Active bank a to Active bank b command time
    parameter TRTP              =       7500; // tRTP     ps  Read to Precharge command delay
    parameter RTP               =          2; // tRTP     tCK Read to Precharge command delay
    parameter TWR               =      15000; // tWR      ps  Write recovery time
    parameter WR                =          3; // tWR      tCK Write recovery time
    parameter WTR               =          2; // tWTR     tCK Write to Read command delay
    parameter TXP               =       7500; // tXP      ps  Exit power down to first valid command
    parameter XP                =          3; // tXP      tCK Exit power down to first valid command
    parameter TXSR              =     140000; // tXSR     ps  Exit self refesh to first valid command
    parameter XSR               =          2; // tXSR     tCK Exit self refesh to first valid command
    // Refresh
    parameter TRFCPB            =      60000; // tRFCpb   ps  Refresh to Refresh Command interval minimum value
    parameter TRFCAB            =     130000; // tRFCab   ps  Refresh to Refresh Command interval minimum value
    parameter TREFBW            =    4160000; // tREFBW   ps  Burst Refresh Window
                            
    // Initialization
    parameter TINIT1            =     100000; // tINIT1   ps
    parameter INIT2             =          5; // tINIT2   tCK
    parameter TINIT3            =  200000000; // tINIT3   ps
    parameter TINIT4            =     281000; // tINIT4   ps  2*tRFCab + tRP
    parameter TINIT5            =   10000000; // tINIT5   ps
    parameter TZQINIT           =    1000000; // tZQINIT  ps  Calibration Initialization Time
    parameter TZQCL             =     360000; // tZQCL    ps  Long (Full) Calibration Time
    parameter TZQCS             =      90000; // tZQCS    ps  Short Calibration Time
    parameter TZQRESET          =      50000; // tZQRESET ps  Calibration Reset Time


    // Size Parameters based on Part Width
`ifdef x16
    parameter ROW_BITS          =         14; // Address bits
    parameter COL_BITS          =         11; // Column bits
    parameter DM_BITS           =          2; // Data Mask bits
    parameter DQ_BITS           =         16; // Data bits       **Same as part bit width**
    parameter DQS_BITS          =          2; // Dqs bits
`else
`define x32
    parameter ROW_BITS          =         14; // Address bits
    parameter COL_BITS          =         10; // Column bits
    parameter DM_BITS           =          4; // Data Mask bits
    parameter DQ_BITS           =         32; // Data bits       **Same as part bit width**
    parameter DQS_BITS          =          4; // Dqs bits
`endif
    parameter COL_NOWRAPBITS    =          9; // subpage for NOWRAP 
    parameter SUB_PAGE_BITS     =          9; // Sub Page Bits = x32 COL_BITS

    // Size Parameters
    parameter BA_BITS           =          3; // Bank Address bits
    parameter CA_BITS           =         10; // Command Address Bits
    parameter MEM_BITS          =         10; // Set this parameter to control how many write data bursts can be stored in memory.  The default is 2^10=1024.
    parameter SX                =          4; // prefetch architecture.  2 = LPDDR2-S2 device, 4 = LPDDR2-S4 device.

    // Simulation parameters
    parameter STOP_ON_ERROR     =          0; // If set to 1, the model will halt on errors
    parameter MSGLENGTH         =        256; // max length in characters of a debug string

// --------- Inlined mobile_ddr2_parameters.vh ends
   
    `define DQ_PER_DQS DQ_BITS/DQS_BITS
    `define MAX_BITS   (BA_BITS+ROW_BITS+COL_BITS-1)
    `define MAX_PIPE   2*CL_MAX + BL_MAX
    `define MEM_SIZE   (1<<MEM_BITS)

    // ports
    input                       ck;
    input                       ck_n;
    input                       cke;
    input                       cs_n;
    input         [CA_BITS-1:0] ca;
    input         [DM_BITS-1:0] dm;
    inout         [DQ_BITS-1:0] dq;
    inout        [DQS_BITS-1:0] dqs;
    inout        [DQS_BITS-1:0] dqs_n;

    output reg    [`MAX_BITS:0] BEaddr;
    output reg  [DQ_BITS/8-1:0] BEwr_h;
    output reg  [DQ_BITS/8-1:0] BEwr_l;
    output reg    [DQ_BITS-1:0] BEdin_h;
    output reg    [DQ_BITS-1:0] BEdin_l;
    input         [DQ_BITS-1:0] BEdout_h;
    input         [DQ_BITS-1:0] BEdout_l;
    output reg                  BEclear;
    output reg                  BEreload;
    output reg                  BEsynco;
    input                       BEsynci;

    // clock
    time                        tck_i;
    time                        tm_ck_pos;
    reg                         diff_ck;
    always @(posedge ck)        diff_ck <= ck;
    always @(posedge ck_n)      diff_ck <= ~ck_n;

    // cke, ca[0], ca[1], ca[2], ca[[3]
    // X means H or L (but a defined logic level)
    parameter
        MRW_CMD   = 5'b10000,
        MRR_CMD   = 5'b10001,
        REFPB_CMD = 5'b10010,
        REFAB_CMD = 5'b10011,
        ACT_CMD   = 5'b101xx,
        WRITE_CMD = 5'b1100x,
        READ_CMD  = 5'b1101x,
        BST_CMD   = 5'b11100,
        PRE_CMD   = 5'b11101,
        NOP_CMD   = 5'b1111x,
        SREF_CMD  = 5'b0001x,
        DPD_CMD   = 5'b0110x,
        PD_CMD    = 5'b0111x
    ;

   parameter MRRBIT = 1'b0;
 
    // command address
    reg                         cke_q;
    wire 			cke_in = cke;
    wire                  [4:0] cmd = {cke, ~cs_n ? {ca[0], ca[1], ca[2], ca[3]} : 4'b111x};  // deselect = nop 
    reg                   [3:0] cke_cmd;
    reg           [CA_BITS-1:0] ca_q;
    reg                         ab;
    reg                   [8:0] ma;
    reg                   [7:0] op;
    reg           [BA_BITS-1:0] ba;
    reg                  [14:0] r;
    reg                  [11:0] c;
    reg                   [1:0]	ecbbl;
   
    // cmd timers/counters
    integer                     ck_cntr;
    integer                     ck_cke;
    integer                     ck_mrw;
    integer                     ck_mrr;
    integer                     ck_ref;
    integer                     ck_act;
    integer                     ck_write;
    integer                     ck_write_end;
    integer                     ck_read;
    integer                     ck_read_end;
    integer                     ck_pre;
    integer                     ck_prea;
    integer                     ck_bst;
    integer                     ck_pd;
    integer                     ck_dpd;
    integer                     ck_sref;
    integer                     ck_bank_act [(1<<BA_BITS)-1:0];
    integer                     ck_bank_write [(1<<BA_BITS)-1:0];
    integer                     ck_bank_write_end [(1<<BA_BITS)-1:0];
    integer                     ck_bank_read [(1<<BA_BITS)-1:0];
    integer                     ck_bank_read_end [(1<<BA_BITS)-1:0];
    integer                     ck_bank_pre [(1<<BA_BITS)-1:0];
    integer                     ck_bank_ref [(1<<BA_BITS)-1:0];

    time                        tm_init3;
    time                        tm_init4;
    time                        tm_cke;
    time                        tm_ref;
    time                        tm_refa;
    time                        tm_act;
    time                        tm_write_end;
    time                        tm_read_end;
    time                        tm_pre;
    time                        tm_prea;
    time                        tm_bst;
    time                        tm_pd;
    time                        tm_dpd;
    time                        tm_sref;
    time                        tm_zq;
    time                        tm_bank_act [(1<<BA_BITS)-1:0];
    time                        tm_bank_write_end [(1<<BA_BITS)-1:0];
    time                        tm_bank_read_end [(1<<BA_BITS)-1:0];
    time                        tm_bank_pre [(1<<BA_BITS)-1:0];
    time                        tm_bank_ref [(1<<BA_BITS)-1:0];
    time                        tm_burst_refa [15:0];

    // DRAM state
    reg                   [7:0] mr [255:0]; // mode register
    wire                 [19:0] mrwe = 20'b00110000011000001110; // mode registers: 1 = write only, 0 = read only or RFU , x = read/write
    reg                   [7:0] mrmask [19:0]; // mode register mask

    // MR1

    // wire                  [4:0] bl  = 1<<(mr[1] & 7); // range 4-16
    reg [5:0] 			bl;
    reg [5:0] 			lastrd_bl;
    reg [5:0] 			lastwr_bl;

    function [5:0] updatebl(input reg [1:0] ecbbl);
       updatebl = 1<<(mr[1] & 7);
    endfunction

    wire                        bt  = (mr[1]>>3) & 1;
    wire                        wc  = (mr[1]>>4) & 1;
    wire                  [3:0] nwr = ((mr[1]>>5) & 7) + 2; // range 3-8
    // MR2
    wire                  [3:0] rl = (mr[2] & 7) + 2; // range 4-8
    wire                  [2:0] wl = (rl>>1) + (&rl[2:0]); // range 2-4
    // MR10
    wire                  [7:0] calibration_code = mr[10];
    parameter                   
        CAL_INIT  = 8'hFF,
        CAL_LONG  = 8'hAB,
        CAL_SHORT = 8'h56,
        CAL_ZQ    = 8'hC3
    ;
    // MR16
    wire                  [1:0] pasr = mr[16]; // S2
    wire                  [7:0] pasr_bank = mr[16]; // S4
    // MR17
    wire                  [7:0] pasr_segment = mr[17]; // 1Gb-8Gb S4

    reg                   [2:0] init;
    reg           [BA_BITS-1:0] cas_ba;
    reg      [(1<<BA_BITS)-1:0] bank_ap;
    reg      [(1<<BA_BITS)-1:0] write_ap;
    reg      [(1<<BA_BITS)-1:0] read_ap;
    reg           [BA_BITS-1:0] bank_ref;
    reg                   [3:0] burst_refa;
    reg      [(1<<BA_BITS)-1:0] bank_active;
    reg          [ROW_BITS-1:0] row_active [(1<<BA_BITS)-1:0];
    reg                         neg_en;
    reg                [SX-1:0] partial_write;
    integer                     i;
    integer                     j;
 
    reg           [`MAX_PIPE:0] wr_pipeline;
    reg           [`MAX_PIPE:0] rd_pipeline;
    reg           [BA_BITS-1:0] ba_pipeline [`MAX_PIPE:0];
    reg          [ROW_BITS-1:0] row_pipeline [`MAX_PIPE:0];
    reg          [COL_BITS-1:0] col_pipeline [`MAX_PIPE:0];
    reg                   [8:0] ma_pipeline [`MAX_PIPE:0];

    // rx
    wire                  [7:0] dm_in = dm;
    wire                 [63:0] dq_in = dq;
    wire                  [7:0] dqs_even = dqs;
    wire                  [7:0] dqs_odd = dqs_n;
    reg                   [7:0] dm_in_pos;
    reg                   [7:0] dm_in_neg;
    reg                  [63:0] dq_in_pos;
    reg                  [63:0] dq_in_neg;

    // transmit
    reg                         dqs_out_en ;
    reg                         dqs_out;
    reg                         dq_out_en;
    reg          [DQ_BITS-1:0]  dq_out;

    bufif1 buf_dqs    [DQS_BITS-1:0] (dqs,    {DQS_BITS{dqs_out}}, dqs_out_en);
    bufif1 buf_dqs_n  [DQS_BITS-1:0] (dqs_n, {DQS_BITS{~dqs_out}}, dqs_out_en);
    bufif1 buf_dq      [DQ_BITS-1:0] (dq,                  dq_out,  dq_out_en);

    // IO
    reg         [8*MSGLENGTH:1] msg;
    integer                     warnings;
    integer                     errors;
    integer                     failures;
    integer                     mcd_info;
    integer                     mcd_warn;
    integer                     mcd_error;
    integer                     mcd_fail;

    // memory
    reg         [2*DQ_BITS-1:0] memory_data;
    reg         [2*DQ_BITS-1:0] bit_mask;
    reg           [DQ_BITS-1:0] dq_temp;
// `ifdef MAX_MEM
//     parameter RFF_BITS = DQ_BITS;
//     // %z format uses 8 bytes for every 32 bits or less
//     parameter RFF_CHUNK = 8 * ((RFF_BITS*2)/32 + ((RFF_BITS*2)%32 ? 1 : 0));
//     reg [1024:1] tmp_model_dir;
//     integer memfd [(1<<BA_BITS)-1:0];

//     initial
//     begin : file_io_open
//         integer bank;

//         if (!$value$plusargs("model_data+%s", tmp_model_dir))
//         begin
//             tmp_model_dir = "/tmp";
//             $display(
//                 "%m: at time %t WARNING: no +model_data option specified, using /tmp.",
//                 $time
//             );
//         end

//         for (bank = 0; bank < (1<<BA_BITS); bank = bank + 1)
//             memfd[bank] = open_bank_file(bank);
//     end
// `else
//     reg         [2*DQ_BITS-1:0] memory  [0:`MEM_SIZE-1];
//     reg         [`MAX_BITS-1:0] address [0:`MEM_SIZE-1];
//     reg            [MEM_BITS:0] memory_index;
//     reg            [MEM_BITS:0] memory_used;
// `endif

    // initial state
    initial begin
        cke_q = 0;
        ck_cntr = 2;
        ck_cke = 0;
        ck_write = 0;
        ck_read = 0;
        ck_bst = 0;
        tm_cke = 0;
        init = 1;
        burst_refa = 0;
        neg_en = 0;
        wr_pipeline = 0;
        rd_pipeline = 0;
        dqs_out_en = 0;
        dq_out_en = 0;
        cas_ba = 0;

        bank_ap <= 0;
        write_ap <= 0;
        read_ap <= 0;
        bank_active <= 0;
        bank_ref <= 0;
       
        warnings = 0;
        errors = 0;
        failures = 0;
        mcd_info = 0;
        mcd_warn = 0;
        mcd_error = 1;
        mcd_fail = 1;

        // define which bits are RFU in the W and RW mode registers
        mrmask[1]  <= 8'hFF;
        mrmask[2]  <= 8'h0F;
        mrmask[3]  <= 8'h0F;
        mrmask[9]  <= 8'hFF;
        mrmask[10] <= 8'hFF;
        if (SX == 2) begin // S2
            mrmask[16] <= 8'h03;
        end else begin // S4
            mrmask[16] <= 8'hFF;
        end
        mrmask[17] <= 8'hFF;

        // all RFU MRR should read out zero
        for(i=0; i<=255; i=i+1) 
	    mr[i] = 8'h00;

        BEaddr = {`MAX_BITS{1'b0}};
        BEwr_h  = {(DQ_BITS/8){1'b0}};
        BEwr_l  = {(DQ_BITS/8){1'b0}};
        BEdin_h = {DQ_BITS{1'b0}};
        BEdin_l = {DQ_BITS{1'b0}};
        BEclear= 1'b0;
        BEreload = 1'b0;
        BEsynco = 1'b0;
    end

    task backend_sync;
    begin
        BEsynco = 1'b1;
        wait (BEsynci) BEsynco = 1'b0;
        wait (!BEsynci);
      end
    endtask // backend_sync

    task chk_err;
        input [4:0] fromcmd;
        input [4:0] cmd;
    begin
        casex ({fromcmd, cmd})
            // The Mode Register Write Command period is tMRW. No command (other than Nop or Deselect) is allowed during this period.
            {MRW_CMD  , MRW_CMD  } ,
            {MRW_CMD  , MRR_CMD  } ,
            {MRW_CMD  , REFPB_CMD} ,
            {MRW_CMD  , REFAB_CMD} ,
            {MRW_CMD  , ACT_CMD  } ,
          //{MRW_CMD  , WRITE_CMD} ,
          //{MRW_CMD  , READ_CMD } ,
          //{MRW_CMD  , BST_CMD  } ,
          //{MRW_CMD  , PRE_CMD  } ,
            {MRW_CMD  , PD_CMD   } ,
            {MRW_CMD  , DPD_CMD  } ,      
            {MRW_CMD  , SREF_CMD } : begin if (ck_cntr - ck_mrw < MRW) ERROR ("tMRW violation"); end

            // The Mode Register Command period is tMRR. No command (other than Nop or Deselect) is allowed during this period.
            // Deep power down, power down and self refresh can not be entered while read or write, mode register read, mode register write, or precharge operations are in progress.
            {MRR_CMD  , MRW_CMD  } ,
            {MRR_CMD  , MRR_CMD  } ,
            {MRR_CMD  , REFPB_CMD} ,
            {MRR_CMD  , REFAB_CMD} ,
            {MRR_CMD  , ACT_CMD  } ,
            {MRR_CMD  , WRITE_CMD} ,
            {MRR_CMD  , READ_CMD } ,
            {MRR_CMD  , BST_CMD  } ,
            {MRR_CMD  , PRE_CMD  } : begin if (ck_cntr - ck_mrr < MRR) ERROR ("tMRR violation"); end
            {MRR_CMD  , PD_CMD   } , // CKE may be registered LOW RL + RU(tDQSCK/tCK)+ BL/2 + 1 clock cycles after the clock on which the Mode Register Read command is registered.
            {MRR_CMD  , DPD_CMD  } , 
            {MRR_CMD  , SREF_CMD } : begin if (ck_cntr - ck_mrr < rl + ceil(1.0*TDQSCK_MAX/tck_i) + 2 + 1) ERROR ("MRR to CKE low violation"); end

            {REFPB_CMD, MRW_CMD  } ,
            {REFPB_CMD, MRR_CMD  } ,
            {REFPB_CMD, REFPB_CMD} ,
            {REFPB_CMD, REFAB_CMD} ,
          //{REFPB_CMD, WRITE_CMD} ,
          //{REFPB_CMD, READ_CMD } ,
          //{REFPB_CMD, BST_CMD  } ,
          //{REFPB_CMD, PRE_CMD  } ,
          //{REFPB_CMD, PD_CMD   } , legal
          //{REFPB_CMD, DPD_CMD  } , legal 
            {REFPB_CMD, SREF_CMD } : begin if ($time - tm_ref < TRFCPB) ERROR ("tRFCpb violation"); end
            {REFPB_CMD, ACT_CMD  } : begin if ($time - tm_bank_ref[ba] < TRFCPB) ERROR ("tRFCpb violation"); if ((ck_cntr - ck_ref < RRD) || ($time - tm_ref < TRRD)) ERROR ("tRRD violation"); end
  
            {REFAB_CMD, MRW_CMD  } ,
            {REFAB_CMD, MRR_CMD  } ,
            {REFAB_CMD, REFPB_CMD} ,
            {REFAB_CMD, REFAB_CMD} ,
            {REFAB_CMD, ACT_CMD  } ,
          //{REFAB_CMD, WRITE_CMD} ,
          //{REFAB_CMD, READ_CMD } ,
          //{REFAB_CMD, BST_CMD  } ,
          //{REFAB_CMD, PRE_CMD  } ,
          //{REFAB_CMD, PD_CMD   } , legal
          //{REFAB_CMD, DPD_CMD  } , legal 
            {REFAB_CMD, SREF_CMD } : begin if ($time - tm_refa < TRFCAB) ERROR ("tRFCab violation"); end

          //{ACT_CMD  , MRW_CMD  } ,
          //{ACT_CMD  , MRR_CMD  } ,
            {ACT_CMD  , REFPB_CMD} ,
          //{ACT_CMD  , REFAB_CMD} ,
            {ACT_CMD  , ACT_CMD  } : begin if ((ck_cntr - ck_act < RRD) || ($time - tm_act < TRRD)) ERROR ("tRRD violation"); end
            {ACT_CMD  , WRITE_CMD} ,
            {ACT_CMD  , READ_CMD } : begin if ((ck_cntr - ck_bank_act[ba] < RCD) || ($time - tm_bank_act[ba] < TRCD)) ERROR ("tRCD violation"); end
          //{ACT_CMD  , BST_CMD  } ,
            {ACT_CMD  , PRE_CMD  } : begin if ((ab && ((ck_cntr - ck_act < RAS) || ($time - tm_act < TRAS))) || (!ab && ((ck_cntr - ck_bank_act[ba] < RAS) || ($time - tm_bank_act[ba] < TRAS)))) ERROR ("tRAS violation"); end
          //{ACT_CMD  , PD_CMD   } , legal
          //{ACT_CMD  , DPD_CMD  } , legal 
          //{ACT_CMD  , SREF_CMD } , 

          //{WRITE_CMD, REFPB_CMD} ,
          //{WRITE_CMD, REFAB_CMD} ,
          //{WRITE_CMD, ACT_CMD  } ,
            {WRITE_CMD, WRITE_CMD} : begin if (ck_cntr - ck_write < SX/2) ERROR ("tCCD violation"); end
          //{WRITE_CMD, BST_CMD  } ,
            {WRITE_CMD, PRE_CMD  } : begin if ((ab && ((ck_cntr - ck_write_end < WR) || ($time - tm_write_end < TWR))) 
                                            || (!ab && ((ck_cntr - ck_bank_write_end[ba] < WR) || ($time - tm_bank_write_end[ba] < TWR)))) 
                                                ERROR ("tWR violation"); end
            {WRITE_CMD, MRR_CMD  } , // The minimum number of clock cycles from the burst write command to the Mode Register Read command is [WL + 1 + BL/2 + RU( tWTR/tCK)].
            {WRITE_CMD, MRW_CMD  } , // The minimum number of clock cycles from the burst write command to the Mode Register Write command is [WL + 1 + BL/2 + RU( tWTR/tCK)].
            {WRITE_CMD, READ_CMD } : begin if ((ck_cntr - ck_write_end < WTR) || ($time - tm_write_end < TWTR)) ERROR ("tWTR violation"); end
            {WRITE_CMD, PD_CMD   } , // CKE may be registered LOW WL + 1 + BL/2 + RU(tWR/tCK) + 1 clock cycles after the Write command is registered.
            {WRITE_CMD, DPD_CMD  } , 
            {WRITE_CMD, SREF_CMD } : begin if ((ck_cntr - ck_write_end < WR + 1) || ($time - tm_write_end < TWR)) ERROR ("Write to Power Down violation"); end

            {READ_CMD , MRW_CMD  } : // The minimum number of clock cycles from the burst read command to the Mode Register Write command is [RL + RU( tDQSCK/tCK) + BL/2].
                                     begin if (ck_cntr - ck_read_end < rl + ceil(1.0*TDQSCK_MAX/tck_i) + SX/2) ERROR ("Read to MRW violation"); end
            {READ_CMD , MRR_CMD  } : // The minimum number of clocks from the burst read command to the Mode Register Read command is BL/2.
                                     begin if (ck_cntr - ck_read_end < SX/2) ERROR ("Read to MRR violation"); end
          //{READ_CMD , REFPB_CMD} ,
          //{READ_CMD , REFAB_CMD} ,
          //{READ_CMD , ACT_CMD  } , 
            {READ_CMD , WRITE_CMD} : // Minimum read to write latency is RL + RU(tDQSCKmax/tCK) + BL/2 + 1 - WL clock cycles.
                                     begin if (ck_cntr - ck_read_end < rl + ceil(1.0*TDQSCK_MAX/tck_i) + SX/2 + 1 - wl) ERROR ("tRTW violation"); end
            {READ_CMD , READ_CMD } : begin if (ck_cntr - ck_read < SX/2) ERROR ("tCCD violation"); end
          //{READ_CMD , BST_CMD  } ,
            {READ_CMD , PRE_CMD  } : begin if ((ab && ((ck_cntr - ck_read_end < RTP) || ($time - tm_read_end < TRTP))) || (!ab && ((ck_cntr - ck_bank_read_end[ba] < RTP) || ($time - tm_bank_read_end[ba] < TRTP)))) ERROR ("tRTP violation"); end
            {READ_CMD , PD_CMD   } , // CKE may be registered LOW RL + RU(tDQSCK/tCK)+ BL/2 + 1 clock cycles after the clock on which the Read command is registered.
            {READ_CMD , DPD_CMD  } ,
            {READ_CMD , SREF_CMD } : begin if (ck_cntr - ck_read_end < rl + ceil(1.0*TDQSCK_MAX/tck_i) + SX/2 + 1) ERROR ("Read to Power Down violation"); end

          //{BST_CMD  , MRW_CMD  } ,
          //{BST_CMD  , MRR_CMD  } ,
          //{BST_CMD  , REFPB_CMD} ,
          //{BST_CMD  , REFAB_CMD} ,
          //{BST_CMD  , ACT_CMD  } ,
          //{BST_CMD  , WRITE_CMD} ,
          //{BST_CMD  , READ_CMD } ,
          //{BST_CMD  , BST_CMD  } ,
          //{BST_CMD  , PRE_CMD  } ,
          //{BST_CMD  , PD_CMD   } ,
          //{BST_CMD  , DPD_CMD  } ,
          //{BST_CMD  , SREF_CMD } ,

            {PRE_CMD  , MRR_CMD  } : begin if ((ck_cntr - ck_prea < RPAB) || ($time - tm_prea < TRPAB)) ERROR ("tRPab violation"); end
            {PRE_CMD  , MRW_CMD  } ,
            {PRE_CMD  , REFAB_CMD} ,
            {PRE_CMD  , SREF_CMD } : begin if ((ck_cntr - ck_pre < RPPB) || ($time - tm_pre < TRPPB)) ERROR ("tRPpb violation");
                                           if ((ck_cntr - ck_prea < RPAB) || ($time - tm_prea < TRPAB)) ERROR ("tRPab violation"); end
	  // for REFPB, use bank_ref instead
	    {PRE_CMD  , REFPB_CMD} : begin if ((ck_cntr - ck_bank_pre[bank_ref] < RPPB) || ($time - tm_bank_pre[bank_ref] < TRPPB)) ERROR ("tRPpb violation");
                                           if ((ck_cntr - ck_prea < RPAB) || ($time - tm_prea < TRPAB)) ERROR ("tRPab violation"); end
	      
            {PRE_CMD  , ACT_CMD  } : begin if ((ck_cntr - ck_bank_pre[ba] < RPPB) || ($time - tm_bank_pre[ba] < TRPPB)) ERROR ("tRPpb violation");
                                           if ((ck_cntr - ck_prea < RPAB) || ($time - tm_prea < TRPAB)) ERROR ("tRPab violation"); end
          //{PRE_CMD  , WRITE_CMD} ,
          //{PRE_CMD  , READ_CMD } ,
          //{PRE_CMD  , BST_CMD  } ,
          //{PRE_CMD  , PRE_CMD  } , legal
          //{PRE_CMD  , PD_CMD   } , legal
          //{PRE_CMD  , DPD_CMD  } , legal

                                           
            {SREF_CMD , MRW_CMD  } ,
            {SREF_CMD , MRR_CMD  } ,
            {SREF_CMD , REFPB_CMD} ,
            {SREF_CMD , REFAB_CMD} ,
            {SREF_CMD , ACT_CMD  } : begin if ((ck_cntr - ck_sref < XSR) || ($time - tm_sref < TXSR)) ERROR ("tXSR violation"); end
          //{SREF_CMD , WRITE_CMD} ,
          //{SREF_CMD , READ_CMD } ,
          //{SREF_CMD , BST_CMD  } ,
          //{SREF_CMD , PRE_CMD  } ,
            {SREF_CMD , PD_CMD   } ,
            {SREF_CMD , DPD_CMD  } ,
            {SREF_CMD , SREF_CMD } : begin if (ck_cntr - ck_sref < CKE) ERROR ("tCKE violation"); end

          //{DPD_CMD  , MRW_CMD  } ,
          //{DPD_CMD  , MRR_CMD  } ,
          //{DPD_CMD  , REFPB_CMD} ,
          //{DPD_CMD  , REFAB_CMD} ,
          //{DPD_CMD  , ACT_CMD  } ,
          //{DPD_CMD  , WRITE_CMD} ,
          //{DPD_CMD  , READ_CMD } ,
          //{DPD_CMD  , BST_CMD  } ,
          //{DPD_CMD  , PRE_CMD  } ,
            {DPD_CMD  , PD_CMD   } ,
            {DPD_CMD  , DPD_CMD  } ,
            {DPD_CMD  , SREF_CMD } : begin if (ck_cntr - ck_pd < CKE) ERROR ("tCKE violation"); end

            {PD_CMD   , MRW_CMD  } ,
            {PD_CMD   , MRR_CMD  } ,
            {PD_CMD   , REFPB_CMD} ,
            {PD_CMD   , REFAB_CMD} ,
            {PD_CMD   , ACT_CMD  } : begin if ((ck_cntr - ck_pd < XP) || ($time - tm_pd < TXP)) ERROR ("tXP violation"); end
          //{PD_CMD   , WRITE_CMD} ,
          //{PD_CMD   , READ_CMD } ,
          //{PD_CMD   , BST_CMD  } ,
          //{PD_CMD   , PRE_CMD  } ,
            {PD_CMD   , PD_CMD   } ,
            {PD_CMD   , DPD_CMD  } ,
            {PD_CMD   , SREF_CMD } : begin if (ck_cntr - ck_pd < CKE) ERROR ("tCKE violation"); end
        endcase
    end
    endtask

    always @(diff_ck) begin


        // In power-down mode, CKE must be maintained LOW while all other input signals are "Don’t Care".
        // Once the LPDDR2 SDRAM has entered Self Refresh mode, all of the external signals except CKE, are "don’t care".
        // Deep Power-Down mode, all input buffers except CKE, all output buffers, and the power supply to internal circuitry may be disabled
        if ((init != 1) && (cke === 1'bx))
            ERROR ("cke must be driven to a a defined logic level");
        if (cke_q && ((&ca === 1'bx) || (|ca === 1'bx)))
            ERROR ("ca must be driven to a a defined logic level while cke is active");
        if (cke_q && (diff_ck === 1'bx))
            ERROR ("ck and ck_n must be driven to a a defined logic level while cke is active");

        // determine if write mask is being used
        if (diff_ck) begin
            partial_write = (partial_write<<1) | &dm_in_neg[DM_BITS-1:0];
        end else begin
            partial_write = (partial_write<<1) | &dm_in_pos[DM_BITS-1:0];
        end

        if (diff_ck) begin
            // initialization
            case (init)
                1 : begin // 1. Power Ramp
                    // CKE low required during tINIT1 and tINIT2
                    if (cke_in) begin
                        // DPD does not require tINIT1
                        if ((cke_cmd != DPD_CMD>>1) && ($time - tm_cke < TINIT1)) begin
                            ERROR ("tINIT1 violation");
                        end 
                        if (ck_cntr - ck_cke < INIT2) begin
                            ERROR ("tINIT2 violation");
                        end
                        // CKE high moves to tINIT3
                        init = 3;
                        tm_init3 <= $time;
                    end
                end
                3 : begin // 2. Reset command
                    // NOP allowed during tINIT3
                    if ((cmd[4:1] !== 4'b1111) && ($time - tm_init3 < TINIT3)) begin
                        ERROR ("tINIT3 violation");
                    end
                    // reset moves to tINIT4
                    if ((cmd == MRW_CMD) && (ca[9:4] == 'h3F)) begin
                        init = 4;
                        tm_init4 <= $time;
                    end

                end
                4 : begin
                    // NOP required during tINIT4
                    if ((cmd[4:1] !== 4'b1111) && ($time - tm_init4 < TINIT4)) begin
                        ERROR ("tINIT4 violation");
                    end
                    // CMD or tINIT4 moves to tINIT5
                    if ((cmd[4:1] !== 4'b1111) || ($time - tm_init4 >= TINIT4)) begin
                        init = 5;
                    end
                end
                5 : begin // 3. Mode Registers Reads and Device Auto-Initialization (DAI) polling:
                    // PD and MRR allowed during tINIT5
                    if ((cmd[3:1] !== 3'b111) && (cmd !== MRR_CMD) && ($time - tm_init4 < TINIT5)) begin
                        ERROR ("tINIT5 violation");
                    end
                    // CMD or tINIT5 finishes
                    if (((cmd[3:1] !== 3'b111) && (cmd !== MRR_CMD)) || ($time - tm_init4 >= TINIT5)) begin
                        if (SX == 2) begin
                            INFO ("Initialization complete");
                            init = 0; // done
                        end else begin
                            init = 6;
                        end
                        mr[0] = {7'h00, MRRBIT}; // DAI complete
                    end
                end
                6 : begin // 4. ZQ Calibration
`ifdef REQUIRE_ZQINIT
                    if (calibration_code == CAL_INIT) begin
                        init = 7;
                    end
`else
		   init = 7;
`endif
                end
                7 : begin
                    // CMD or tZQINIT finishes
                    if ((cmd[3:1] !== 3'b111) || ($time - tm_zq >= TZQINIT)) begin
                        INFO ("Initialization complete");
                        init = 0; // done
                        mr[0] = {7'h00, MRRBIT}; 
                    end
                end
            endcase

            // auto precharge
            if (|bank_ap) begin
                for (i=0; i<(1<<BA_BITS); i=i+1) begin
                    if (write_ap[i] && ((ck_cntr - ck_bank_write_end[i] >= nwr)
                        && (ck_cntr - ck_bank_act[i] >= RAS) && ($time - tm_bank_act[i] >= TRAS))) begin
                        // tWR violation if nwr < tWR
                        ba = i;
                        ab = 0;
                        chk_err(WRITE_CMD, PRE_CMD);
                        write_ap[i] = 1'b0;
                    end
                    if (read_ap[i] && ((ck_cntr - ck_bank_read_end[i] >= RTP) && ($time - tm_bank_read_end[i] >= TRTP)
                        && (ck_cntr - ck_bank_act[i] >= RAS) && ($time - tm_bank_act[i] >= TRAS))) begin
                        read_ap[i] = 1'b0;
                    end
                    if (bank_ap[i] && !write_ap[i] && !read_ap[i]) begin
                        $sformat (msg, "Auto Precharge bank %1d", i);
                        INFO (msg);
                        bank_ap[i] = 1'b0;
                        bank_active[i] = 1'b0;
                        ck_pre <= ck_cntr;
                        tm_pre <= $time;
                        ck_bank_pre[i] <= ck_cntr;
                        tm_bank_pre[i] <= $time;
                    end
                end
            end

            // shift pipelines
            if (|wr_pipeline || |rd_pipeline) begin
                wr_pipeline <= wr_pipeline>>1;
                rd_pipeline <= rd_pipeline>>1;
                for (i=0; i<`MAX_PIPE; i=i+1) begin
                    ba_pipeline[i]  <= ba_pipeline[i + 1];
                    row_pipeline[i] <= row_pipeline[i + 1];
                    col_pipeline[i] <= col_pipeline[i + 1];
                    ma_pipeline[i] <= ma_pipeline[i + 1];
                end
            end

            // *_read_end is start time for measuring tRTP
            if ((ck_read > ck_bst) && ((ck_cntr - ck_read)%(SX/2) == 0) && (ck_cntr - ck_bank_read[cas_ba] <= (lastrd_bl - SX)/2) && (cmd != READ_CMD) && (cmd != BST_CMD)) begin
                ck_read_end = ck_cntr;
                tm_read_end = $time;
                ck_bank_read_end[cas_ba] = ck_cntr;
                tm_bank_read_end[cas_ba] = $time;
            end

            // *_write_end is the start time for measuring tWR and tWTR
            if ((ck_cntr - ck_write)%(SX/2) == 0) begin
                for (i=0; i<(1<<BA_BITS); i=i+1) begin
                    if ((ck_cntr - ck_bank_write[i] <= wl + 1 + SX/2) || ((&partial_write == 0) && wr_pipeline[0] && (ba_pipeline[0] == i))) begin
                        ck_write_end = ck_cntr;
                        tm_write_end = $time;
                        ck_bank_write_end[i] = ck_cntr;
                        tm_bank_write_end[i] = $time;
                    end
                end
            end

            // TODO: The achieveable time without REFRESH commands is given by tREFW - (R / 8) * tREFBW = tREFW - R * 4 * tRFCab.

            // check timing
            ba = ca[9:7];
            ab = ca[4];
	    casex (cmd)
	    NOP_CMD: begin end
            default: begin
                chk_err(MRW_CMD  , cmd);
                chk_err(MRR_CMD  , cmd);
                chk_err(REFPB_CMD, cmd);
                chk_err(REFAB_CMD, cmd);
                chk_err(ACT_CMD  , cmd);
                chk_err(WRITE_CMD, cmd);
                chk_err(READ_CMD , cmd);
                chk_err(BST_CMD  , cmd);
                chk_err(PRE_CMD  , cmd);
                chk_err(SREF_CMD , cmd);
                chk_err(DPD_CMD  , cmd);
                chk_err(PD_CMD   , cmd);
                // ZQ Calibration
                case (calibration_code)
                    CAL_INIT  : begin if ($time - tm_zq < TZQINIT) ERROR ("tZQINIT violation"); end
                    CAL_LONG  : begin if ($time - tm_zq < TZQCL) ERROR ("tZQCL violation"); end
                    CAL_SHORT : begin if ($time - tm_zq < TZQCS) ERROR ("tZQCS violation"); end
                    CAL_ZQ    : begin if ($time - tm_zq < TZQRESET) ERROR ("TZQRESET violation"); end
                endcase
	        end
	    endcase

            // command decode
            casex ({cke_q, cmd})
                {1'b1, MRW_CMD} : begin
                    if (|bank_active && ca[9:4] != 'h3F) begin // reset for DPDE
                        ERROR ("All banks must be Precharged prior to MRW");
                    end else begin
                        if (ca[9:4] == 'h3F) begin
                            INFO ("Reset");
// `ifdef MAX_MEM
//                             erase_banks({(1<<BA_BITS){1'b1}});
// `else
//                             memory_used <= 0;
// `endif
                            BEclear = 1'b1;
                            backend_sync;
                            BEclear = 1'b0;
                            backend_sync;
                            BEreload = 1'b1;
                            backend_sync;
                            BEreload = 1'b0;
                            backend_sync;

                            bank_ap <= 0;
                            write_ap <= 0;
                            read_ap <= 0;
                            bank_active <= 0;
                            bank_ref <= 0;

                            mr[0] <= {7'h00, MRRBIT}; // 0x00 Device info R RFU DAI DI 
                            mr[1] <= 8'h22;   // 1 0x01 Device feature W nWR (for AP) WC BT BL
                            mr[2] <= 8'h01;   // 2 0x02 Device feature W RFU RL & WL
                            mr[3] <= 8'hxx;   // 8'h02 I/O Config W Slew Rate Drive Strength
			    mr[4] <= 8'hxx;   // 8'h03 ignore refresh
                            mr[5] <= 8'hff;   // 0x05 Basic Config 1 R Name of Company
                            mr[6] <= 8'h00;   // 0x06 Basic Config 2 R Revision ID1
                            mr[7] <= 8'h00;   // 0x07 Basic Config 3 R Revision ID2
			    // mr[8] <= 0x08 Basic Config 4 R IO Width Density Type
`ifdef	lpddr2_64Mb					   
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (0<<2) | (SX == 2) | MR8RESID; 
`elsif	lpddr2_128Mb					   
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (1<<2) | (SX == 2) | MR8RESID;
`elsif	lpddr2_256Mb					   
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (2<<2) | (SX == 2) | MR8RESID;
`elsif	lpddr2_512Mb					   
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (3<<2) | (SX == 2) | MR8RESID;
`elsif	lpddr2_1Gb					   
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (4<<2) | (SX == 2) | MR8RESID;
`elsif  lpddr2_2Gb
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (5<<2) | (SX == 2) | MR8RESID;
`elsif  lpddr2_4Gb
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (6<<2) | (SX == 2) | MR8RESID;
`elsif  lpddr2_8Gb
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (7<<2) | (SX == 2) | MR8RESID;
`elsif  lpddr2_16Gb
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (8<<2) | (SX == 2) | MR8RESID;
`elsif  lpddr2_32Gb
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (9<<2) | (SX == 2) | MR8RESID;
`else
                            mr[8] <= ((DQ_BITS == 8)<<7) | ((DQ_BITS == 16)<<6) | (4<<2) | (SX == 2) | MR8RESID;
`endif						   
                            // 9 0x09 Test Mode W Vendor-specific
                            mr[16] <= 8'h00; // 16 0x10 PASR bank S4 W PASR Bank Mask PASR bank S2 RFU PASR
                            mr[17] <= 8'h00; // 17 0x11 PASR segment W PASR Segment Mask
                            // 18 0x12 Refresh mode W RFU REFM
                            mr[19] <= 8'h00; // 0x13 Refresh rate R RFU Refresh Rate // MYY use to be 3
                            // 63 0x3F Reset W Don’t Care

                            // If the RESET command is issued outside the power up initialization sequence, 
                            // the reinitialization procedure shall begin with step 3.
                            if (init == 0) begin
                                init = 5;
                            end
                        end else begin
                            neg_en <= 1'b1;
                        end
                        ck_mrw <= ck_cntr;
                    end 
                end
                {1'b1, MRR_CMD} : begin
                    neg_en <= 1'b1;
                    ck_mrr <= ck_cntr;
                end
                {1'b1, REFPB_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to REFpb");
                    end else if (BA_BITS != 3) begin
                        ERROR ("Per Bank Refresh is only allowed in devices with 8 banks");
                    end else if (bank_active[bank_ref]) begin
                        $sformat (msg, "Bank %d must be Precharged prior to REFpb", bank_ref);
                        ERROR (msg);
                    end else begin
                        // a maximum of 4 REFpb commands may be issued in any rolling tFAW
                        j = 0;
                        for (i=0; i<(1<<BA_BITS); i=i+1) begin
                            if ((ck_cntr - ck_bank_ref[i] < FAW) || ($time - tm_bank_ref[i] < TFAW)) begin
                                j = j + 1;
                            end
                        end
                        if (j > 4) begin
                            ERROR ("tFAW violation");
                        end
                        $sformat (msg, "REFpb bank %d", bank_ref);
                        INFO (msg);
                        bank_ref <= bank_ref + 1;
                        ck_ref <= ck_cntr;
                        tm_ref <= $time;
                        ck_bank_ref[bank_ref] <= ck_cntr;
                        tm_bank_ref[bank_ref] <= $time;
                    end
                end
                {1'b1, REFAB_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to REFab");
                    end else if (|bank_active) begin
                        ERROR ("All banks must be Precharged prior to REFab");
                    end else begin
                        // a maximum of 8 REFab commands may be issued in any rolling tREFBW
                        j = 0;
                        for (i=0; i<16; i=i+1) begin
                            if ($time - tm_burst_refa[i] < TREFBW) begin
                                j = j + 1;
                            end
                        end
                        if (j > 8) begin
                            ERROR ("tREFBW violation");
                        end
                        // INFO ("REFab");
                        // bank_ref <= 0; // REFAB does not reset bank_ref counter
                        burst_refa <= burst_refa + 1;
                        tm_refa <= $time;
                        tm_burst_refa[burst_refa] <= $time;
                    end
                end
                {1'b1, ACT_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to ACT");
                    end else if (bank_active[ba]) begin
                        $sformat (msg, "Bank %d must be Precharged prior to ACT", ba);
                        ERROR (msg);
                    end else begin
                        // a maximum of 4 Act commands may be issued in any rolling tFAW
                        j = 0;
                        for (i=0; i<(1<<BA_BITS); i=i+1) begin
                            if ((ck_cntr - ck_bank_act[i] < FAW) || ($time - tm_bank_act[i] < TFAW)) begin
                                j = j + 1;
                            end
                        end
                        if (j > 4) begin
                            ERROR ("tFAW violation");
                        end
                        neg_en <= 1'b1;
                        ck_act <= ck_cntr;
                        tm_act <= $time;
                        ck_bank_act[ba] <= ck_cntr;
                        tm_bank_act[ba] <= $time;
                    end 
                end
                {1'b1, WRITE_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to WRITE");
                    end else if (!bank_active[ba]) begin
                        $sformat (msg, "Bank %d must be Activated prior to WRITE", ba);
                        WARN (msg); // change from ERR to WAR
                    end else if (bank_ap[ba]) begin
                        $sformat (msg, "Auto Precharge is scheduled to bank %d", ba);
                        ERROR (msg);
                    end else if ((ck_write > ck_bst) && (ck_cntr - ck_write < lastwr_bl/2) && (ck_cntr - ck_write)%(SX/2)) begin
                        ERROR ("Illegal WRITE bust interruption");
                    end else begin
                        neg_en <= 1'b1;
                        cas_ba <= ba;
                        ck_write <= ck_cntr;
                        ck_write_end <= ck_cntr;
                        ck_bank_write[ba] <= ck_cntr;
                        ck_bank_write_end[ba] <= ck_cntr;
                        tm_write_end <= $time;
                        tm_bank_write_end[ba] <= $time;
                    end
                end
                {1'b1, READ_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to READ");
                    end else if (!bank_active[ba]) begin
                        $sformat (msg, "Bank %d must be Activated prior to READ", ba);
                        WARN (msg); // change from ERROR to WARN
                    end else if (bank_ap[ba]) begin
                        $sformat (msg, "Auto Precharge is scheduled to bank %d", ba);
                        ERROR (msg);
                    end else if ((ck_read > ck_bst) && (ck_cntr - ck_read < lastrd_bl/2) && (ck_cntr - ck_read)%(SX/2)) begin
                        ERROR ("Illegal READ burst interruption");
                    end else begin
                        neg_en <= 1'b1;
                        cas_ba <= ba;
                        ck_read <= ck_cntr;
                        ck_read_end <= ck_cntr;
                        ck_bank_read[ba] <= ck_cntr;
                        ck_bank_read_end[ba] <= ck_cntr;
                        tm_read_end <= $time;
                        tm_bank_read_end[ba] <= $time;
                    end
                end
                {1'b1, BST_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to BST");
                    end else if ((ck_cntr - ck_write >= lastwr_bl/2) && (ck_cntr - ck_read >= lastrd_bl/2)) begin
                        // ERROR ("BST may only be issued up to BL/2 - 1 clock cycles after a READ or WRITE"); // CHECK OFF 
                    end else if ((ck_read > ck_write) && (ck_cntr - ck_read)%(SX/2)) begin
                        ERROR ("BST can only be issued an even number of clock cycles after a READ");
                    end else if ((ck_write > ck_read) && (ck_cntr - ck_write)%(SX/2)) begin
                        ERROR ("BST can only be issued an even number of clock cycles after a WRITE");
                    end else if (bank_ap[cas_ba]) begin
                        $sformat (msg, "Auto Precharge is scheduled to bank %d", cas_ba);
                        ERROR (msg);
                    end else begin
                        INFO ("BST");
                        wr_pipeline <= (wr_pipeline>>1) & ((1<<(wl + 1))-1);
                        rd_pipeline <= (rd_pipeline>>1) & ((1<<(rl - 1))-1);
                        ck_bst <= ck_cntr;
                    end
                end
                {1'b1, PRE_CMD} : begin
                    // A PRECHARGE command will be treated as a NOP if there is no open row in that bank (idle state), 
                    // or if the previously open row is already in the process of precharging.
                    if (ab) begin
                        if (|init) begin
                            INFO ("PREab during initialization sequence ignored");
                        end else if (&(~bank_active | bank_ap)) begin
                            INFO ("PREab has been ignored");
                        end else begin
                            INFO ("PREab");
                            bank_active = 0;
                            ck_prea <= ck_cntr;
                            tm_prea <= $time;
                        end
                    end else if (bank_active[ba]) begin
                        if (|init) begin
                            ERROR ("Initialization sequence must be complete prior to PREpb");
                        end else if (~bank_active[ba] | bank_ap[ba]) begin
                            $sformat (msg, "PREpb bank %d has been ignored", ba);
                            INFO (msg);
                        end else begin
                            $sformat (msg, "PREpb bank %d", ba);
                            // INFO (msg);
                            ck_pre <= ck_cntr;
                            tm_pre <= $time;
                            bank_active[ba] = 1'b0;
                            ck_bank_pre[ba] <= ck_cntr;
                            tm_bank_pre[ba] <= $time;
                        end
                    end
                end
                {1'b1, NOP_CMD} : ; // do nothing
                {1'b1, SREF_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to SREF");
                    end else if (|bank_active) begin
                        ERROR ("All banks must be Precharged prior to SREF");
                    end else begin
                        INFO ("SREF");
                        cke_cmd <= SREF_CMD>>1;
                        bank_ref <= 0;
                        ck_cke <= ck_cntr;
                        tm_cke <= $time;
                    end
                end
                {1'b1, DPD_CMD} : begin
                    if (|init) begin
                        ERROR ("Initialization sequence must be complete prior to DPD");
                    end else begin
                        INFO ("DPD");
                        init <= 1;
                        bank_active <= 0; // allow MRW(RESET) command
                        cke_cmd <= DPD_CMD>>1;
// `ifdef MAX_MEM
//                         erase_banks({(1<<BA_BITS){1'b1}});
// `else
//                         memory_used <= 0;
// `endif
                        BEclear = 1'b1;
                        backend_sync;
                        BEclear = 1'b0;
                        backend_sync;

                        ck_cke <= ck_cntr;
                        tm_cke <= $time;
                    end
                end
                {1'b1, PD_CMD} : begin
                    if (|init && (init < 5)) begin
                        ERROR ("PD is illegal until tINIT4 has been satisfied");
                    end else if ((ck_cntr - ck_mrr < MRR) || (ck_cntr - ck_mrw < MRW)) begin
                        ERROR ("CKE is not allowed to go LOW while MRR or MRW operations are in progress");
                    end else begin
                        $sformat (msg, "PD active = %d", |bank_active);
                        INFO (msg);
                        cke_cmd <= PD_CMD>>1;
                        ck_cke <= ck_cntr;
                        tm_cke <= $time;
                    end
                end
                {1'b0, NOP_CMD} : begin // EXIT SREF, PD, DPD
                    case (cke_cmd)
                        SREF_CMD>>1 : begin 
                            if ($time - tm_cke < TCKESR) 
                                ERROR ("tCKESR violation"); 
                            ck_sref <= ck_cntr;
                            tm_sref <= $time;
                        end
                        DPD_CMD>>1  ,
                        PD_CMD>>1   : begin 
                            ck_pd <= ck_cntr; 
                            tm_pd <= $time; 
                        end
                    endcase
                    if (ck_cntr - ck_cke < CKE) 
                        ERROR ("tCKE violation");
                    ck_cke <= ck_cntr;
                    tm_cke <= $time;
                end
                6'b00xxxx : begin // Maintain SREF, PD, DPD
                    if ((ck_cntr - ck_cke == 1) && (cmd[3:1] !== 3'b111)) begin
                        ERROR ("Nop or Deselect must be driven in the clock cycle after CKE goes low");
                    end
                end
                default : ERROR ("Illegal command");
            endcase

            cke_q <= cke_in;
            ca_q <= ca;
            ck_cntr <= ck_cntr + 1;
            tck_i <= $time - tm_ck_pos;
            tm_ck_pos <= $time;

        end else if (neg_en) begin
            ma = {ca[1:0], ca_q[9:4]};
            op = ca[9:2];
            ba = ca_q[9:7];
            r = {ca[9:8], ca_q[6:2], ca[7:0]};
            c = {ca[9:1], ca_q[6:5], 1'b0};
            ecbbl = {ca_q[3], ca_q[4]};
            casex ({ca_q[0], ca_q[1], ca_q[2]})
                3'b000 : begin // MRW/MRR
                    if (ca_q[3]) begin // MRR
                        if (mrwe[ma]) begin
                            $sformat (msg, "Register %d is Write Only", ma); 
                            WARN (msg);
                        end
		        // still output data for write only registers 
                        $sformat (msg, "MRR ma %h op %h", ma, mr[ma]);
                        INFO (msg);
                        for (i=0; i<2; i=i+1) begin
                            rd_pipeline[rl - 1 + i] <= 1'b1;
                            ba_pipeline[rl - 1 + i] <= {BA_BITS{1'bx}};
                            ma_pipeline[rl - 1 + i] <= ma + i*256;
                        end
                    end else begin // MRW
                        if (~mrwe[ma]) begin
                            $sformat (msg, "Register %d is Read Only or RFU", ma); 
                            WARN (msg);
                        end else begin
                            if (~mrmask[ma] & op) begin
                                $sformat(msg, "RFU bits in ma %h cannot be set", ma);
                                WARN (msg);
                            end
                            if (ma == 10) begin
                                if (SX == 2) begin
                                    INFO ("ZQ Calibration command has been ignored");
                                end else begin
                                    tm_zq <= tm_ck_pos;
                                end
                            end
                            $sformat (msg, "MRW ma %h op %h", ma, op);
                            INFO (msg);
                            mr[ma] <= mrmask[ma] & op;
                        end
                    end
                end
                3'b01x : begin // ACT
                    if (r >= 1<<ROW_BITS) begin
                        $sformat (msg, "row = %h does not exist.  Maximum row = %h", r, (1<<ROW_BITS)-1);
                        WARN (msg);
                    end
                    $sformat (msg, "ACT bank %d row %h", ba, r);
                    // INFO (msg);
                    bank_active[ba] = 1'b1;
                    row_active[ba] = r;
                end
                3'b100 : begin // WRITE
                    if (c >= 1<<COL_BITS) begin
                        $sformat (msg, "col = %h does not exist.  Maximum col = %h", c, (1<<COL_BITS)-1);
                        WARN (msg);
                    end
                    $sformat (msg, "WRITE bank %d col %h ap %d", ba, c, ca[0]);
                    // INFO (msg);
		    bl = updatebl(ecbbl);
		    lastwr_bl = bl;
                    for (i=0; i<bl/2; i=i+1) begin
                        wr_pipeline[wl + 1 + i] <= 1'b1;
                        ba_pipeline[wl + 1 + i] <= ba;
                        row_pipeline[wl + 1 + i] <= row_active[ba];
                        if (bt && !wc) begin
                            col_pipeline[wl + 1 + i] <= (c & -1*bl) + (c%bl ^ 2*i); // interleaved, wrap
                        end else begin
						   if (!wc) begin
                              col_pipeline[wl + 1 + i] <= (c & -1*bl) + (c%bl + 2*i)%(bl); // sequential
						   end else begin
						      // subpage nowrap change
                              col_pipeline[wl + 1 + i] <= (c&(((1<<COL_BITS)-1)-((1<<COL_NOWRAPBITS)-1)))|(((c&-1*bl)+(c%bl+2*i))&((1<<COL_NOWRAPBITS)-1)); // sequential
						   end
                        end
                    end
                    bank_ap[ba] <= ca[0]; // AP
                    write_ap[ba] <= ca[0]; // AP
                end
                3'b101 : begin // READ
                    if (c >= 1<<COL_BITS) begin
                        $sformat (msg, "col = %h does not exist.  Maximum col = %h", c, (1<<COL_BITS)-1);
                        WARN (msg);
                    end
                    $sformat (msg, "READ bank %d col %h ap %d", ba, c, ca[0]);
                    // INFO (msg);
		    bl = updatebl(ecbbl);
		    lastrd_bl = bl;
                    for (i=0; i<bl/2; i=i+1) begin
                        rd_pipeline[rl - 1 + i] <= 1'b1;
                        ba_pipeline[rl - 1 + i] <= ba;
                        row_pipeline[rl - 1 + i] <= row_active[ba];
                        if (bt && !wc) begin
                            col_pipeline[rl - 1 + i] <= (c & -1*bl) + (c%bl ^ 2*i); // interleaved, wrap
                        end else begin
						   if (!wc) begin
                              col_pipeline[rl - 1 + i] <= (c & -1*bl) + (c%bl + 2*i)%(bl); // sequential
						   end else begin
						      // subpage nowrap change
                              col_pipeline[rl - 1 + i] <= (c&(((1<<COL_BITS)-1)-((1<<COL_NOWRAPBITS)-1)))|(((c&-1*bl)+(c%bl+2*i))&((1<<COL_NOWRAPBITS)-1)); // sequential
						   end
                        end
                    end
                    bank_ap[ba] <= ca[0]; // AP
                    read_ap[ba] <= ca[0]; // AP
                end
            endcase
            neg_en <= 1'b0;
        end

        // write data
        ba = ba_pipeline[0];
        r = row_pipeline[0];
        c = col_pipeline[0] + diff_ck;
        ma = ma_pipeline[0] + diff_ck;
        if (wr_pipeline[0]) begin
            bit_mask = 0;
            if (diff_ck) begin
                for (i=0; i<DM_BITS; i=i+1) begin
                    bit_mask = bit_mask | ({`DQ_PER_DQS{~dm_in_neg[i]}}<<(DQ_BITS + i*`DQ_PER_DQS));
                end
                memory_data = ((dq_in_neg<<DQ_BITS) & bit_mask) | (memory_data & ~bit_mask);
                memory_write(ba, r, c, memory_data);
            end else begin
                for (i=0; i<DM_BITS; i=i+1) begin
                    bit_mask = bit_mask | ({`DQ_PER_DQS{~dm_in_pos[i]}}<<(i*`DQ_PER_DQS));
                end
                memory_read(ba, r, c, memory_data);
                memory_data = (dq_in_pos & bit_mask) | (memory_data & ~bit_mask);
            end
            dq_temp = memory_data>>(c[0]*DQ_BITS);
            $sformat (msg, "Write @dqs, bank = %h, row = %h, col = %h, dq = %h", ba, r, c, dq_temp);
            // INFO (msg);
        end

        // read data
        if (diff_ck) begin
            dqs_out_en <= #(TDQSCK) (|rd_pipeline[1:0]);
            dq_out_en <= #(TDQSCK) (rd_pipeline[0]);
        end
        dqs_out <= #(TDQSCK) rd_pipeline[0] && diff_ck;
        dq_out <= #(TDQSCK) dq_temp;

        if (rd_pipeline[0]) begin
            if (!diff_ck) begin
                if (ba === {BA_BITS{1'bx}}) begin // MRR command
		   if(ma==32 || ma==(32+256)) begin 
		      memory_data = {{DQ_BITS{1'b0}},{DQ_BITS{1'b1}}};
		   end
		   else if (ma==40) begin
		      memory_data = {{DQ_BITS{1'b0}},{DQ_BITS{1'b0}}};
		   end
		   else if (ma==(40+256)) begin
		      memory_data = {{DQ_BITS{1'b1}},{DQ_BITS{1'b1}}};
		   end
		   else
                    memory_data = {{2*DQ_BITS - 8{MRRBIT}}, mr[ma]};
                end else begin
                    memory_read(ba, r, c, memory_data);
                end
            end

            if (ba === {BA_BITS{1'bx}}) // MRR command // no need to shift for MRR
              dq_temp = memory_data>>(diff_ck*DQ_BITS);
            else
              dq_temp = memory_data>>(c[0]*DQ_BITS);

            $sformat (msg, "Read @dqs, bank = %h, row = %h, col = %h, dq = %h", ba, r, c, dq_temp);
            // INFO (msg);
        end
    end 

    // receiver(s)
    task dqs_even_receiver;
        input [3:0] i;
        reg [63:0] bit_mask;
        begin
            bit_mask = {`DQ_PER_DQS{1'b1}}<<(i*`DQ_PER_DQS);
            if (dqs_even[i]) begin
                dm_in_pos[i] = dm_in[i];
                dq_in_pos = (dq_in & bit_mask) | (dq_in_pos & ~bit_mask);
            end
        end
    endtask

    always @(posedge dqs_even[ 0]) dqs_even_receiver( 0);
    always @(posedge dqs_even[ 1]) dqs_even_receiver( 1);
    always @(posedge dqs_even[ 2]) dqs_even_receiver( 2);
    always @(posedge dqs_even[ 3]) dqs_even_receiver( 3);
    always @(posedge dqs_even[ 4]) dqs_even_receiver( 4);
    always @(posedge dqs_even[ 5]) dqs_even_receiver( 5);
    always @(posedge dqs_even[ 6]) dqs_even_receiver( 6);
    always @(posedge dqs_even[ 7]) dqs_even_receiver( 7);

    task dqs_odd_receiver;
        input [3:0] i;
        reg [63:0] bit_mask;
        begin
            bit_mask = {`DQ_PER_DQS{1'b1}}<<(i*`DQ_PER_DQS);
            if (dqs_odd[i]) begin
                dm_in_neg[i] = dm_in[i];
                dq_in_neg = (dq_in & bit_mask) | (dq_in_neg & ~bit_mask);
            end
        end
    endtask

    always @(posedge dqs_odd[ 0]) dqs_odd_receiver( 0);
    always @(posedge dqs_odd[ 1]) dqs_odd_receiver( 1);
    always @(posedge dqs_odd[ 2]) dqs_odd_receiver( 2);
    always @(posedge dqs_odd[ 3]) dqs_odd_receiver( 3);
    always @(posedge dqs_odd[ 4]) dqs_odd_receiver( 4);
    always @(posedge dqs_odd[ 5]) dqs_odd_receiver( 5);
    always @(posedge dqs_odd[ 6]) dqs_odd_receiver( 6);
    always @(posedge dqs_odd[ 7]) dqs_odd_receiver( 7);

    //---------------------------------------------------
    // TASK: INFO("msg")
    //---------------------------------------------------
    task INFO;
        input [MSGLENGTH*8:1] msg;
        begin
            $fdisplay(mcd_error, "%m at time %t: %0s", $time, msg);
        end
    endtask

    //---------------------------------------------------
    // TASK: WARN("msg")
    //---------------------------------------------------
    task WARN;
        input [MSGLENGTH*8:1] msg;
        begin
            $fdisplay(mcd_warn, "%m at time %t: %0s", $time, msg);
            warnings = warnings + 1;
        end
    endtask

    //---------------------------------------------------
    // TASK: ERROR(errcode, "msg")
    //---------------------------------------------------
    task ERROR;
        input [MSGLENGTH*8:1] msg;
        begin
            $fdisplay(mcd_error, "%m at time %t: %0s", $time, msg);
            errors = errors + 1;
            if (STOP_ON_ERROR) begin
                STOP;
            end
        end
    endtask

    //---------------------------------------------------
    // TASK: FAIL("msg")
    //---------------------------------------------------
    task FAIL;
        input [MSGLENGTH*8:1] msg;
        begin
            $fdisplay(mcd_fail, "%m at time %t: %0s", $time, msg);
            failures = failures + 1;
            STOP;
        end
    endtask

    //---------------------------------------------------
    // TASK: Stop()
    //---------------------------------------------------
    task STOP;
        begin
            $display("%m at time %t: %d warnings, %d errors, %d failures", $time, warnings, errors, failures);
            $stop(0);
        end
    endtask


    function integer ceil;
        input number;
        real number;
        if (number > $rtoi(number))
            ceil = $rtoi(number) + 1;
        else
            ceil = number;
    endfunction

// `ifdef MAX_MEM
//     function integer open_bank_file( input integer bank );
//         integer fd;
//         reg [2048:1] filename;
//         begin
//             $sformat( filename, "%0s/%m.%0d", tmp_model_dir, bank );

//             fd = $fopen(filename, "w+");
//             if (fd == 0)
//             begin
// 	        if (mcd_error)
//                   $display("%m: at time %0t ERROR: failed to open %0s.", $time, filename);
//                 $finish;
//             end
//             else
//             begin
// 	        if (mcd_info) 
// 		  $display("%m: at time %0t INFO: opening %0s.", $time, filename);
//                 open_bank_file = fd;
//             end

//         end
//     endfunction

//     function [2*RFF_BITS:1] read_from_file(
//         input integer fd,
//         input integer index
//     );
//         integer code;
//         integer offset;
//         reg [1024:1] msg;
//         reg [2*RFF_BITS:1] read_value;

//         begin
//             offset = index * RFF_CHUNK;
//             code = $fseek( fd, offset, 0 );
//             // $fseek returns 0 on success, -1 on failure
//             if (code != 0)
//             begin
//                 $display("%m: at time %t ERROR: fseek to %d failed", $time, offset);
//                 $finish;
//             end

//             code = $fscanf(fd, "%z", read_value);
//             // $fscanf returns number of items read
//             if (code != 1)
//             begin
//                 if ($ferror(fd,msg) != 0)
//                 begin
//                     $display("%m: at time %t ERROR: fscanf failed at %d", $time, index);
//                     $display(msg);
//                     $finish;
//                 end
//                 else
//                     read_value = 'hx;
//             end

//             /* when reading from unwritten portions of the file, 0 will be returned.
//             * Use 0 in bit 1 as indicator that invalid data has been read.
//             * A true 0 is encoded as Z.
//             */
//             if (read_value[1] === 1'bz)
//                 // true 0 encoded as Z, data is valid
//                 read_value[1] = 1'b0;
//             else if (read_value[1] === 1'b0)
//                 // read from file section that has not been written
//                 read_value = 'hx;

//             read_from_file = read_value;
//         end
//     endfunction

//     task write_to_file(
//         input integer fd,
//         input integer index,
//         input [2*RFF_BITS:1] data
//     );
//         integer code;
//         integer offset;

//         begin
//             offset = index * RFF_CHUNK;
//             code = $fseek( fd, offset, 0 );
//             if (code != 0)
//             begin
//                 $display("%m: at time %t ERROR: fseek to %d failed", $time, offset);
//                 $finish;
//             end

//             // encode a valid data
//             if (data[1] === 1'bz)
//                 data[1] = 1'bx;
//             else if (data[1] === 1'b0)
//                 data[1] = 1'bz;

//             $fwrite( fd, "%z", data );
//         end
//     endtask

//     task erase_banks;
//         input  [(1<<BA_BITS)-1:0] banks; //one select bit per bank
//         integer bank;

//         begin

//         for (bank = 0; bank < (1<<BA_BITS); bank = bank + 1)
//             if (banks[bank] === 1'b1) begin
//                 $fclose(memfd[bank]);
//                 memfd[bank] = open_bank_file(bank);
//             end
//         end
//     endtask
// `else
//     function get_index;
//         input [`MAX_BITS-1:0] addr;
//         begin : index
//             get_index = 0;
//             for (memory_index=0; memory_index<memory_used; memory_index=memory_index+1) begin
//                 if (address[memory_index] == addr) begin
//                     get_index = 1;
//                     disable index;
//                 end
//             end
//         end
//     endfunction
// `endif

    task memory_write;
        input  [BA_BITS-1:0]  bank;
        input  [ROW_BITS-1:0] row;
        input  [COL_BITS-1:0] col;
        input  [2*DQ_BITS-1:0] data;
        reg    [`MAX_BITS-1:0] addr;
        begin
            // chop off the lowest address bits
            addr = {bank, row, col}/2;
            BEaddr = addr;
            BEdin_l = data[2*DQ_BITS-1:DQ_BITS];
            BEdin_h = data[DQ_BITS-1:0];
            backend_sync;
            BEwr_l = 2'b11;
            BEwr_h = 2'b11;
            backend_sync;
            BEwr_l = 2'b00;
            BEwr_h = 2'b00;
            backend_sync;
// `ifdef MAX_MEM
//             write_to_file( memfd[bank], {row, col}/2, data );
// `else
//             if (get_index(addr)) begin
//                 address[memory_index] = addr;
//                 memory[memory_index] = data;
//             end else if (memory_used == `MEM_SIZE) begin
//                 $display ("%m: at time %t ERROR: Memory overflow.  Write to Address %h with Data %h will be lost.\nYou must increase the MEM_BITS parameter or define MAX_MEM.", $time, addr, data);
//                 if (STOP_ON_ERROR) $stop(0);
//             end else begin
//                 address[memory_used] = addr;
//                 memory[memory_used] = data;
//                 memory_used = memory_used + 1;
//             end
// `endif
        end
    endtask

    task memory_read;
        input  [BA_BITS-1:0]  bank;
        input  [ROW_BITS-1:0] row;
        input  [COL_BITS-1:0] col;
        output [2*DQ_BITS-1:0] data;
        reg    [`MAX_BITS-1:0] addr;
        begin
            // chop off the lowest address bits
            addr = {bank, row, col}/2;
            BEaddr = addr;
            backend_sync;
            data = { {BEdout_l},{BEdout_h} };
            backend_sync;
// `ifdef MAX_MEM
//             data = read_from_file( memfd[bank], {row, col}/2 );
// `else
//             if (get_index(addr)) begin
//                 data = memory[memory_index];
//             end else begin
//                 data = {2*DQ_BITS{1'bx}};
//             end
// `endif
        end
    endtask


endmodule

`ifdef LPDDR2_2_1
module mobile_ddr2_2_1 (
    ck,
    ck_n,
    cke,
    cs_n,
    ca,
    dm,
    dq,
    dqs,
    dqs_n
);

    `include "mobile_ddr2_parameters.vh"

    // ports
    input                       ck;
    input                       ck_n;
    input                 [1:0] cke;
    input                 [1:0] cs_n;
    input         [CA_BITS-1:0] ca;
    input         [DM_BITS-1:0] dm;
    inout         [DQ_BITS-1:0] dq;
    inout        [DQS_BITS-1:0] dqs;
    inout        [DQS_BITS-1:0] dqs_n;

    mobile_ddr2 sdrammobile_ddr2_0 (
        ck,
        ck_n,
        cke[0],
        cs_n[0],
        ca,
        dm,
        dq,
        dqs,
        dqs_n
    );
    
    mobile_ddr2 sdrammobile_ddr2_1 (
        ck,
        ck_n,
        cke[1],
        cs_n[1],
        ca,
        dm,
        dq,
        dqs,
        dqs_n
    );
   
endmodule
`endif 

`ifdef LPDDR2_2_2
module mobile_ddr2_2_2 (
    ck,
    ck_n,
    cke,
    cs_n,
    ca,
    dm,
    dq,
    dqs,
    dqs_n
);

    `include "mobile_ddr2_parameters.vh"

    // ports
    input                       ck;
    input                       ck_n;
    input                       cke;
    input                       cs_n;
    input           [CA_BITS-1:0] ca;
    input         [2*DM_BITS-1:0] dm;
    inout         [2*DQ_BITS-1:0] dq;
    inout        [2*DQS_BITS-1:0] dqs;
    inout        [2*DQS_BITS-1:0] dqs_n;

    mobile_ddr2 sdrammobile_ddr2_0 (
        ck,
        ck_n,
        cke,
        cs_n,
        ca,
        dm[DM_BITS-1:0],
        dq[DQ_BITS-1:0],
        dqs[DQS_BITS-1:0],
        dqs_n[DQS_BITS-1:0]
    );
    
    mobile_ddr2 sdrammobile_ddr2_1 (
        ck,
        ck_n,
        cke,
        cs_n,
        ca,
        dm[2*DM_BITS-1:DM_BITS],
        dq[2*DQ_BITS-1:DQ_BITS],
        dqs[2*DQS_BITS-1:DQS_BITS],
        dqs_n[2*DQS_BITS-1:DQS_BITS]
    );
   
endmodule
`endif

`ifdef LPDDR2_4_2
module mobile_ddr2_4_2 (
    ck,
    ck_n,
    cke,
    cs_n,
    ca,
    dm,
    dq,
    dqs,
    dqs_n
);

    `include "mobile_ddr2_parameters.vh"

    // ports
    input                       ck;
    input                       ck_n;
    input                 [1:0] cke;
    input                 [1:0] cs_n;
    input         [CA_BITS-1:0] ca;
    input         [2*DM_BITS-1:0] dm;
    inout         [2*DQ_BITS-1:0] dq;
    inout        [2*DQS_BITS-1:0] dqs;
    inout        [2*DQS_BITS-1:0] dqs_n;

    mobile_ddr2 sdrammobile_ddr2_0_0 (
        ck,
        ck_n,
        cke[0],
        cs_n[0],
        ca,
        dm[DM_BITS-1:0],
        dq[DQ_BITS-1:0],
        dqs[DQS_BITS-1:0],
        dqs_n[DQS_BITS-1:0]
    );
    
    mobile_ddr2 sdrammobile_ddr2_0_1 (
        ck,
        ck_n,
        cke[0],
        cs_n[0],
        ca,
        dm[2*DM_BITS-1:DM_BITS],
        dq[2*DQ_BITS-1:DQ_BITS],
        dqs[2*DQS_BITS-1:DQS_BITS],
        dqs_n[2*DQS_BITS-1:DQS_BITS]
    );

    mobile_ddr2 sdrammobile_ddr2_1_0 (
        ck,
        ck_n,
        cke[1],
        cs_n[1],
        ca,
        dm[DM_BITS-1:0],
        dq[DQ_BITS-1:0],
        dqs[DQS_BITS-1:0],
        dqs_n[DQS_BITS-1:0]
    );

    mobile_ddr2 sdrammobile_ddr2_1_1 (
        ck,
        ck_n,
        cke[1],
        cs_n[1],
        ca,
        dm[2*DM_BITS-1:DM_BITS],
        dq[2*DQ_BITS-1:DQ_BITS],
        dqs[2*DQS_BITS-1:DQS_BITS],
        dqs_n[2*DQS_BITS-1:DQS_BITS]
    );
   
endmodule
`endif

