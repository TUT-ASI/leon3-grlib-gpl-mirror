set_component igl_serdes_epcs_SERDES_IF_0_SERDES_IF
# Microsemi Corp.
# Date: 2017-Nov-01 13:15:05
#

create_clock -period 8 [ get_pins { EPCS_3_RX_CLK } ]
create_clock -period 8 [ get_pins { EPCS_3_TX_CLK } ]
