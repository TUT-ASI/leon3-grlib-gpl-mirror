#! /usr/bin/tclsh
#
# Utility to pad SREC to multiple of 16 bytes
# Copyright 2010, Aeroflex Gaisler AB.
#
# Usage: tclsh padsrec.tcl <in.srec >out.srec
#
# Limitations:
# - Records other than S1-3 are passed on unchanged
# - SREC checksums are not correct
#
# Revision history:
#   2011-08-12, MH, First version (based on ftddrcb.tcl)
#   2020-12-01, MH, Rewrite to support realigning data
#



# -------------------------------------------------------------
# SREC processing

proc hex2int { h } {
        return [expr {"0x$h"}]
}

set outrecs [list] ; # output records without check byte
set prerecs [list]
set postrecs [list]

set startaddr 0
set recbytes 16

set lineno 0
while { ! [eof stdin] } {
        set l [gets stdin]
        incr lineno
        set llen [string length $l]
        if { $llen == 0 } then continue
        set rt [string index $l 1 ]
        if { $rt > 0 && $rt < 4 } then {
                # Byte count and data position
                set bc [expr { [hex2int [string range $l 2 3]] - 2 - $rt } ]
                set dp [expr {6 + $rt*2}]
                # Address
                set haddr [string range $l 4 $dp-1]
                set addr 0x${haddr}
                if { [llength $outrecs] == 0 } {
                        set startaddr [expr { $addr - ($addr & (1-$recbytes)) }]
                }
                while { $bc > 0 } {
                        set recno [expr { ($addr-$startaddr) / $recbytes }]
                        while { $recno >= [llength $outrecs] } {
                                set newrec [format "S3%02X%08X%0*X" [expr {$recbytes + 5}] [expr {$startaddr + [llength $outrecs]*$recbytes}] [expr {2*$recbytes}] 0]
                                lappend outrecs $newrec
                        }
                        set recoffs [expr {$addr - $recno*$recbytes - $startaddr}]
                        set cbc [expr { min($bc, $recbytes-$recoffs) }]
                        set rec [lindex $outrecs $recno]
                        set nrec [string replace $rec [expr { 12+2*$recoffs}] [expr { 11+2*($recoffs+$cbc) }] [string range $l $dp [expr {$dp+2*$cbc-1}]] ]
                        lset outrecs $recno $nrec
                        set dp [expr { $dp + 2*$cbc }]
                        set bc [expr { $bc - $cbc }]
                        incr addr $cbc
                }
        } elseif { [llength $outrecs] == 0 } {
                lappend prerecs $l
        } else {
                lappend postrecs $l
        }
}

foreach l $prerecs { puts $l }
foreach l $outrecs {
        set c 0
        for { set b 1 } { $b < (1+4+16+1) } { incr b } {
                incr c [hex2int [string range $l [expr {2*$b}] [expr {2*$b+1}]]]
        }
        set c [expr { (~$c) & 255 }]
        puts [format %s%02X $l $c]
}
foreach l $postrecs { puts $l }
