## Define clock groups for CDC between pl0_ref_clk and bscan_user1_usr_tck in AHBJTAG
set_clock_groups -name cdc_clock_groups \
   -asynchronous \
   -group [get_clocks -of_objects [get_pins -filter {REF_PIN_NAME=~USRTCKINT[0]} -of [get_cells -hierarchical PS9_inst]]] \
   -group clk_pl_0