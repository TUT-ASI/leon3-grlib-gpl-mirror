vlib modelsim/xpm
vlib modelsim/microblaze_v11_0_4
vlib modelsim/xil_defaultlib
vlib modelsim/lib_cdc_v1_0_2
vlib modelsim/proc_sys_reset_v5_0_13
vlib modelsim/lmb_v10_v3_0_11
vlib modelsim/lmb_bram_if_cntlr_v4_0_19
vlib modelsim/blk_mem_gen_v8_4_4
vlib modelsim/iomodule_v3_1_6

vlib modelsim/axi_infrastructure_v1_1_0
vlib modelsim/fifo_generator_v13_2_5
vlib modelsim/axi_clock_converter_v2_1_21

vmap -modelsimini ./modelsim.ini xpm modelsim/xpm
vmap -modelsimini ./modelsim.ini microblaze_v11_0_4 modelsim/microblaze_v11_0_4
vmap -modelsimini ./modelsim.ini xil_defaultlib modelsim/xil_defaultlib
vmap -modelsimini ./modelsim.ini lib_cdc_v1_0_2 modelsim/lib_cdc_v1_0_2
vmap -modelsimini ./modelsim.ini proc_sys_reset_v5_0_13 modelsim/proc_sys_reset_v5_0_13
vmap -modelsimini ./modelsim.ini lmb_v10_v3_0_11 modelsim/lmb_v10_v3_0_11
vmap -modelsimini ./modelsim.ini lmb_bram_if_cntlr_v4_0_19 modelsim/lmb_bram_if_cntlr_v4_0_19
vmap -modelsimini ./modelsim.ini blk_mem_gen_v8_4_4 modelsim/blk_mem_gen_v8_4_4
vmap -modelsimini ./modelsim.ini iomodule_v3_1_6 modelsim/iomodule_v3_1_6

vmap -modelsimini ./modelsim.ini  axi_infrastructure_v1_1_0 modelsim/axi_infrastructure_v1_1_0
vmap -modelsimini ./modelsim.ini  fifo_generator_v13_2_5 modelsim/fifo_generator_v13_2_5
vmap -modelsimini ./modelsim.ini  axi_clock_converter_v2_1_21 modelsim/axi_clock_converter_v2_1_21

vlog -work xpm -64 -sv "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"$env(XILINX_VIVADO)/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"$env(XILINX_VIVADO)/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"$env(XILINX_VIVADO)/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -64 -93 \
"$env(XILINX_VIVADO)/data/ip/xpm/xpm_VCOMP.vhd" \

vcom -work microblaze_v11_0_4 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_0/hdl/microblaze_v11_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_0/sim/bd_bae1_microblaze_I_0.vhd" \

vcom -work lib_cdc_v1_0_2 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_1/hdl/lib_cdc_v1_0_rfs.vhd" \

vcom -work proc_sys_reset_v5_0_13 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_1/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_1/sim/bd_bae1_rst_0_0.vhd" \

vcom -work lmb_v10_v3_0_11 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_2/hdl/lmb_v10_v3_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_2/sim/bd_bae1_ilmb_0.vhd" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_3/sim/bd_bae1_dlmb_0.vhd" \

vcom -work lmb_bram_if_cntlr_v4_0_19 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_4/hdl/lmb_bram_if_cntlr_v4_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_4/sim/bd_bae1_dlmb_cntlr_0.vhd" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_5/sim/bd_bae1_ilmb_cntlr_0.vhd" \

vlog -work blk_mem_gen_v8_4_4 -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_6/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_6/sim/bd_bae1_lmb_bram_I_0.v" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_7/sim/bd_bae1_second_dlmb_cntlr_0.vhd" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_8/sim/bd_bae1_second_ilmb_cntlr_0.vhd" \

vlog -work xil_defaultlib -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_9/sim/bd_bae1_second_lmb_bram_I_0.v" \

vcom -work iomodule_v3_1_6 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_10/hdl/iomodule_v3_1_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/ip/ip_10/sim/bd_bae1_iomodule_0_0.vhd" \

vlog -work xil_defaultlib -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/bd_0/sim/bd_bae1.v" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_0/sim/mig_microblaze_mcs.v" \

vlog -work xil_defaultlib -64 -sv "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/map" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top" "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/phy/mig_phy_ddr4.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy_behav.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/phy/ddr4_phy_v2_2_xiphy.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/iob/ddr4_phy_v2_2_iob_byte.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/iob/ddr4_phy_v2_2_iob.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/clocking/ddr4_phy_v2_2_pll.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_tristate_wrapper.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_riuor_wrapper.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_control_wrapper.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_byte_wrapper.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/xiphy_files/ddr4_phy_v2_2_xiphy_bitslice_wrapper.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/ip_1/rtl/ip_top/mig_phy.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_wtr.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ref.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_rd_wr.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_periodic.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_group.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc_merge_enc.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc_gen.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc_fi_xor.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc_dec_fix.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc_buf.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ecc.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_ctl.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_cmd_mux_c.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_cmd_mux_ap.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_arb_p.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_arb_mux_p.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_arb_c.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_arb_a.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_act_timer.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc_act_rank.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/controller/ddr4_v2_2_mc.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ui/ddr4_v2_2_ui_wr_data.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ui/ddr4_v2_2_ui_rd_data.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ui/ddr4_v2_2_ui_cmd.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ui/ddr4_v2_2_ui.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_ar_channel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_aw_channel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_b_channel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_cmd_arbiter.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_cmd_fsm.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_cmd_translator.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_fifo.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_incr_cmd.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_r_channel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_w_channel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_wr_cmd_fsm.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_wrap_cmd.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_a_upsizer.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_register_slice.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axi_upsizer.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_axic_register_slice.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_carry_and.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_carry_latch_and.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_carry_latch_or.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_carry_or.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_command_fifo.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_comparator.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_comparator_sel.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_comparator_sel_static.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_r_upsizer.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi/ddr4_v2_2_w_upsizer.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_addr_decode.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_read.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg_bank.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_reg.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_top.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/axi_ctrl/ddr4_v2_2_axi_ctrl_write.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/clocking/ddr4_v2_2_infrastructure.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_xsdb_bram.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_write.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_wr_byte.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_wr_bit.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_sync.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_read.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_rd_en.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_pi.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_mc_odt.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_debug_microblaze.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_cplx_data.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_cplx.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_config_rom.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_addr_decode.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_top.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal_xsdb_arbiter.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_cal.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_chipscope_xsdb_slave.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/ddr4_v2_2_dp_AB9.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top/mig_ddr4.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top/mig_ddr4_mem_intfc.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/cal/mig_ddr4_cal_riu.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/rtl/ip_top/mig.sv" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig/tb/microblaze_mcs_0.sv" \


vlog -work axi_infrastructure_v1_1_0 -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl" "+incdir+../../../hdl" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work fifo_generator_v13_2_5 -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl" "+incdir+../../../hdl" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_5 -64 -93 \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_5 -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl" "+incdir+../../../hdl" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl/fifo_generator_v13_2_rfs.v" \

vlog -work axi_clock_converter_v2_1_21 -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl" "+incdir+../../../hdl" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl/axi_clock_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 "+incdir+./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/hdl" "+incdir+../../../hdl" \
"./vivado/leon5-xilinx-vcu128/leon5-xilinx-vcu128.gen/sources_1/ip/mig_cdc/sim/mig_cdc.v" \

vlog -work work \
"$env(XILINX_VIVADO)/data/verilog/src/glbl.v"

quit

