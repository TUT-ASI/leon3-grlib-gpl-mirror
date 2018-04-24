set_component hpms_sb_CCC_0_FCCC
# Microsemi Corp.
# Date: 2017-Nov-01 13:13:13
#

create_clock -period 20 [ get_pins { CCC_INST/RCOSC_25_50MHZ } ]
create_generated_clock -multiply_by 88 -divide_by 55 -source [ get_pins { CCC_INST/RCOSC_25_50MHZ } ] -phase 0 [ get_pins { CCC_INST/GL0 } ]
create_generated_clock -multiply_by 88 -divide_by 55 -source [ get_pins { CCC_INST/RCOSC_25_50MHZ } ] -phase 0 [ get_pins { CCC_INST/GL2 } ]
create_generated_clock -multiply_by 88 -divide_by 35 -source [ get_pins { CCC_INST/RCOSC_25_50MHZ } ] -phase 0 [ get_pins { CCC_INST/GL3 } ]
