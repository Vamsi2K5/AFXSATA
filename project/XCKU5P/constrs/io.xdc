set_property PACKAGE_PIN AC13 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN K7 [get_ports refclkp]


create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list {u_sata_wrapper/u1_sata_gt_wrapper/gth_sata_wrapper_inst/gtwiz_userclk_tx_inst/txusrclk2_in[0]}]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {s_aixs_usr_tdata[0]} {s_aixs_usr_tdata[1]} {s_aixs_usr_tdata[2]} {s_aixs_usr_tdata[3]} {s_aixs_usr_tdata[4]} {s_aixs_usr_tdata[5]} {s_aixs_usr_tdata[6]} {s_aixs_usr_tdata[7]} {s_aixs_usr_tdata[8]} {s_aixs_usr_tdata[9]} {s_aixs_usr_tdata[10]} {s_aixs_usr_tdata[11]} {s_aixs_usr_tdata[12]} {s_aixs_usr_tdata[13]} {s_aixs_usr_tdata[14]} {s_aixs_usr_tdata[15]} {s_aixs_usr_tdata[16]} {s_aixs_usr_tdata[17]} {s_aixs_usr_tdata[18]} {s_aixs_usr_tdata[19]} {s_aixs_usr_tdata[20]} {s_aixs_usr_tdata[21]} {s_aixs_usr_tdata[22]} {s_aixs_usr_tdata[23]} {s_aixs_usr_tdata[24]} {s_aixs_usr_tdata[25]} {s_aixs_usr_tdata[26]} {s_aixs_usr_tdata[27]} {s_aixs_usr_tdata[28]} {s_aixs_usr_tdata[29]} {s_aixs_usr_tdata[30]} {s_aixs_usr_tdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 32 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {err_cnt[0]} {err_cnt[1]} {err_cnt[2]} {err_cnt[3]} {err_cnt[4]} {err_cnt[5]} {err_cnt[6]} {err_cnt[7]} {err_cnt[8]} {err_cnt[9]} {err_cnt[10]} {err_cnt[11]} {err_cnt[12]} {err_cnt[13]} {err_cnt[14]} {err_cnt[15]} {err_cnt[16]} {err_cnt[17]} {err_cnt[18]} {err_cnt[19]} {err_cnt[20]} {err_cnt[21]} {err_cnt[22]} {err_cnt[23]} {err_cnt[24]} {err_cnt[25]} {err_cnt[26]} {err_cnt[27]} {err_cnt[28]} {err_cnt[29]} {err_cnt[30]} {err_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {wr_err_cnt[0]} {wr_err_cnt[1]} {wr_err_cnt[2]} {wr_err_cnt[3]} {wr_err_cnt[4]} {wr_err_cnt[5]} {wr_err_cnt[6]} {wr_err_cnt[7]} {wr_err_cnt[8]} {wr_err_cnt[9]} {wr_err_cnt[10]} {wr_err_cnt[11]} {wr_err_cnt[12]} {wr_err_cnt[13]} {wr_err_cnt[14]} {wr_err_cnt[15]} {wr_err_cnt[16]} {wr_err_cnt[17]} {wr_err_cnt[18]} {wr_err_cnt[19]} {wr_err_cnt[20]} {wr_err_cnt[21]} {wr_err_cnt[22]} {wr_err_cnt[23]} {wr_err_cnt[24]} {wr_err_cnt[25]} {wr_err_cnt[26]} {wr_err_cnt[27]} {wr_err_cnt[28]} {wr_err_cnt[29]} {wr_err_cnt[30]} {wr_err_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {m_aixs_usr_tdata[0]} {m_aixs_usr_tdata[1]} {m_aixs_usr_tdata[2]} {m_aixs_usr_tdata[3]} {m_aixs_usr_tdata[4]} {m_aixs_usr_tdata[5]} {m_aixs_usr_tdata[6]} {m_aixs_usr_tdata[7]} {m_aixs_usr_tdata[8]} {m_aixs_usr_tdata[9]} {m_aixs_usr_tdata[10]} {m_aixs_usr_tdata[11]} {m_aixs_usr_tdata[12]} {m_aixs_usr_tdata[13]} {m_aixs_usr_tdata[14]} {m_aixs_usr_tdata[15]} {m_aixs_usr_tdata[16]} {m_aixs_usr_tdata[17]} {m_aixs_usr_tdata[18]} {m_aixs_usr_tdata[19]} {m_aixs_usr_tdata[20]} {m_aixs_usr_tdata[21]} {m_aixs_usr_tdata[22]} {m_aixs_usr_tdata[23]} {m_aixs_usr_tdata[24]} {m_aixs_usr_tdata[25]} {m_aixs_usr_tdata[26]} {m_aixs_usr_tdata[27]} {m_aixs_usr_tdata[28]} {m_aixs_usr_tdata[29]} {m_aixs_usr_tdata[30]} {m_aixs_usr_tdata[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {wr_cnt_eop[0]} {wr_cnt_eop[1]} {wr_cnt_eop[2]} {wr_cnt_eop[3]} {wr_cnt_eop[4]} {wr_cnt_eop[5]} {wr_cnt_eop[6]} {wr_cnt_eop[7]} {wr_cnt_eop[8]} {wr_cnt_eop[9]} {wr_cnt_eop[10]} {wr_cnt_eop[11]} {wr_cnt_eop[12]} {wr_cnt_eop[13]} {wr_cnt_eop[14]} {wr_cnt_eop[15]} {wr_cnt_eop[16]} {wr_cnt_eop[17]} {wr_cnt_eop[18]} {wr_cnt_eop[19]} {wr_cnt_eop[20]} {wr_cnt_eop[21]} {wr_cnt_eop[22]} {wr_cnt_eop[23]} {wr_cnt_eop[24]} {wr_cnt_eop[25]} {wr_cnt_eop[26]} {wr_cnt_eop[27]} {wr_cnt_eop[28]} {wr_cnt_eop[29]} {wr_cnt_eop[30]} {wr_cnt_eop[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 32 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {rd_ecp_cnt[0]} {rd_ecp_cnt[1]} {rd_ecp_cnt[2]} {rd_ecp_cnt[3]} {rd_ecp_cnt[4]} {rd_ecp_cnt[5]} {rd_ecp_cnt[6]} {rd_ecp_cnt[7]} {rd_ecp_cnt[8]} {rd_ecp_cnt[9]} {rd_ecp_cnt[10]} {rd_ecp_cnt[11]} {rd_ecp_cnt[12]} {rd_ecp_cnt[13]} {rd_ecp_cnt[14]} {rd_ecp_cnt[15]} {rd_ecp_cnt[16]} {rd_ecp_cnt[17]} {rd_ecp_cnt[18]} {rd_ecp_cnt[19]} {rd_ecp_cnt[20]} {rd_ecp_cnt[21]} {rd_ecp_cnt[22]} {rd_ecp_cnt[23]} {rd_ecp_cnt[24]} {rd_ecp_cnt[25]} {rd_ecp_cnt[26]} {rd_ecp_cnt[27]} {rd_ecp_cnt[28]} {rd_ecp_cnt[29]} {rd_ecp_cnt[30]} {rd_ecp_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {rx_trans_sop_cnt[0]} {rx_trans_sop_cnt[1]} {rx_trans_sop_cnt[2]} {rx_trans_sop_cnt[3]} {rx_trans_sop_cnt[4]} {rx_trans_sop_cnt[5]} {rx_trans_sop_cnt[6]} {rx_trans_sop_cnt[7]} {rx_trans_sop_cnt[8]} {rx_trans_sop_cnt[9]} {rx_trans_sop_cnt[10]} {rx_trans_sop_cnt[11]} {rx_trans_sop_cnt[12]} {rx_trans_sop_cnt[13]} {rx_trans_sop_cnt[14]} {rx_trans_sop_cnt[15]} {rx_trans_sop_cnt[16]} {rx_trans_sop_cnt[17]} {rx_trans_sop_cnt[18]} {rx_trans_sop_cnt[19]} {rx_trans_sop_cnt[20]} {rx_trans_sop_cnt[21]} {rx_trans_sop_cnt[22]} {rx_trans_sop_cnt[23]} {rx_trans_sop_cnt[24]} {rx_trans_sop_cnt[25]} {rx_trans_sop_cnt[26]} {rx_trans_sop_cnt[27]} {rx_trans_sop_cnt[28]} {rx_trans_sop_cnt[29]} {rx_trans_sop_cnt[30]} {rx_trans_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 32 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {tx_cmd_cnt[0]} {tx_cmd_cnt[1]} {tx_cmd_cnt[2]} {tx_cmd_cnt[3]} {tx_cmd_cnt[4]} {tx_cmd_cnt[5]} {tx_cmd_cnt[6]} {tx_cmd_cnt[7]} {tx_cmd_cnt[8]} {tx_cmd_cnt[9]} {tx_cmd_cnt[10]} {tx_cmd_cnt[11]} {tx_cmd_cnt[12]} {tx_cmd_cnt[13]} {tx_cmd_cnt[14]} {tx_cmd_cnt[15]} {tx_cmd_cnt[16]} {tx_cmd_cnt[17]} {tx_cmd_cnt[18]} {tx_cmd_cnt[19]} {tx_cmd_cnt[20]} {tx_cmd_cnt[21]} {tx_cmd_cnt[22]} {tx_cmd_cnt[23]} {tx_cmd_cnt[24]} {tx_cmd_cnt[25]} {tx_cmd_cnt[26]} {tx_cmd_cnt[27]} {tx_cmd_cnt[28]} {tx_cmd_cnt[29]} {tx_cmd_cnt[30]} {tx_cmd_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {wr_cnt_sop[0]} {wr_cnt_sop[1]} {wr_cnt_sop[2]} {wr_cnt_sop[3]} {wr_cnt_sop[4]} {wr_cnt_sop[5]} {wr_cnt_sop[6]} {wr_cnt_sop[7]} {wr_cnt_sop[8]} {wr_cnt_sop[9]} {wr_cnt_sop[10]} {wr_cnt_sop[11]} {wr_cnt_sop[12]} {wr_cnt_sop[13]} {wr_cnt_sop[14]} {wr_cnt_sop[15]} {wr_cnt_sop[16]} {wr_cnt_sop[17]} {wr_cnt_sop[18]} {wr_cnt_sop[19]} {wr_cnt_sop[20]} {wr_cnt_sop[21]} {wr_cnt_sop[22]} {wr_cnt_sop[23]} {wr_cnt_sop[24]} {wr_cnt_sop[25]} {wr_cnt_sop[26]} {wr_cnt_sop[27]} {wr_cnt_sop[28]} {wr_cnt_sop[29]} {wr_cnt_sop[30]} {wr_cnt_sop[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {tx_trans_sop_cnt[0]} {tx_trans_sop_cnt[1]} {tx_trans_sop_cnt[2]} {tx_trans_sop_cnt[3]} {tx_trans_sop_cnt[4]} {tx_trans_sop_cnt[5]} {tx_trans_sop_cnt[6]} {tx_trans_sop_cnt[7]} {tx_trans_sop_cnt[8]} {tx_trans_sop_cnt[9]} {tx_trans_sop_cnt[10]} {tx_trans_sop_cnt[11]} {tx_trans_sop_cnt[12]} {tx_trans_sop_cnt[13]} {tx_trans_sop_cnt[14]} {tx_trans_sop_cnt[15]} {tx_trans_sop_cnt[16]} {tx_trans_sop_cnt[17]} {tx_trans_sop_cnt[18]} {tx_trans_sop_cnt[19]} {tx_trans_sop_cnt[20]} {tx_trans_sop_cnt[21]} {tx_trans_sop_cnt[22]} {tx_trans_sop_cnt[23]} {tx_trans_sop_cnt[24]} {tx_trans_sop_cnt[25]} {tx_trans_sop_cnt[26]} {tx_trans_sop_cnt[27]} {tx_trans_sop_cnt[28]} {tx_trans_sop_cnt[29]} {tx_trans_sop_cnt[30]} {tx_trans_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 32 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {rd_cnt_sop[0]} {rd_cnt_sop[1]} {rd_cnt_sop[2]} {rd_cnt_sop[3]} {rd_cnt_sop[4]} {rd_cnt_sop[5]} {rd_cnt_sop[6]} {rd_cnt_sop[7]} {rd_cnt_sop[8]} {rd_cnt_sop[9]} {rd_cnt_sop[10]} {rd_cnt_sop[11]} {rd_cnt_sop[12]} {rd_cnt_sop[13]} {rd_cnt_sop[14]} {rd_cnt_sop[15]} {rd_cnt_sop[16]} {rd_cnt_sop[17]} {rd_cnt_sop[18]} {rd_cnt_sop[19]} {rd_cnt_sop[20]} {rd_cnt_sop[21]} {rd_cnt_sop[22]} {rd_cnt_sop[23]} {rd_cnt_sop[24]} {rd_cnt_sop[25]} {rd_cnt_sop[26]} {rd_cnt_sop[27]} {rd_cnt_sop[28]} {rd_cnt_sop[29]} {rd_cnt_sop[30]} {rd_cnt_sop[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {rx_cmd_cnt[0]} {rx_cmd_cnt[1]} {rx_cmd_cnt[2]} {rx_cmd_cnt[3]} {rx_cmd_cnt[4]} {rx_cmd_cnt[5]} {rx_cmd_cnt[6]} {rx_cmd_cnt[7]} {rx_cmd_cnt[8]} {rx_cmd_cnt[9]} {rx_cmd_cnt[10]} {rx_cmd_cnt[11]} {rx_cmd_cnt[12]} {rx_cmd_cnt[13]} {rx_cmd_cnt[14]} {rx_cmd_cnt[15]} {rx_cmd_cnt[16]} {rx_cmd_cnt[17]} {rx_cmd_cnt[18]} {rx_cmd_cnt[19]} {rx_cmd_cnt[20]} {rx_cmd_cnt[21]} {rx_cmd_cnt[22]} {rx_cmd_cnt[23]} {rx_cmd_cnt[24]} {rx_cmd_cnt[25]} {rx_cmd_cnt[26]} {rx_cmd_cnt[27]} {rx_cmd_cnt[28]} {rx_cmd_cnt[29]} {rx_cmd_cnt[30]} {rx_cmd_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 32 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {rd_err_cnt[0]} {rd_err_cnt[1]} {rd_err_cnt[2]} {rd_err_cnt[3]} {rd_err_cnt[4]} {rd_err_cnt[5]} {rd_err_cnt[6]} {rd_err_cnt[7]} {rd_err_cnt[8]} {rd_err_cnt[9]} {rd_err_cnt[10]} {rd_err_cnt[11]} {rd_err_cnt[12]} {rd_err_cnt[13]} {rd_err_cnt[14]} {rd_err_cnt[15]} {rd_err_cnt[16]} {rd_err_cnt[17]} {rd_err_cnt[18]} {rd_err_cnt[19]} {rd_err_cnt[20]} {rd_err_cnt[21]} {rd_err_cnt[22]} {rd_err_cnt[23]} {rd_err_cnt[24]} {rd_err_cnt[25]} {rd_err_cnt[26]} {rd_err_cnt[27]} {rd_err_cnt[28]} {rd_err_cnt[29]} {rd_err_cnt[30]} {rd_err_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 32 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {rd_eop_cnt[0]} {rd_eop_cnt[1]} {rd_eop_cnt[2]} {rd_eop_cnt[3]} {rd_eop_cnt[4]} {rd_eop_cnt[5]} {rd_eop_cnt[6]} {rd_eop_cnt[7]} {rd_eop_cnt[8]} {rd_eop_cnt[9]} {rd_eop_cnt[10]} {rd_eop_cnt[11]} {rd_eop_cnt[12]} {rd_eop_cnt[13]} {rd_eop_cnt[14]} {rd_eop_cnt[15]} {rd_eop_cnt[16]} {rd_eop_cnt[17]} {rd_eop_cnt[18]} {rd_eop_cnt[19]} {rd_eop_cnt[20]} {rd_eop_cnt[21]} {rd_eop_cnt[22]} {rd_eop_cnt[23]} {rd_eop_cnt[24]} {rd_eop_cnt[25]} {rd_eop_cnt[26]} {rd_eop_cnt[27]} {rd_eop_cnt[28]} {rd_eop_cnt[29]} {rd_eop_cnt[30]} {rd_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 32 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {tx_link_eop_cnt[0]} {tx_link_eop_cnt[1]} {tx_link_eop_cnt[2]} {tx_link_eop_cnt[3]} {tx_link_eop_cnt[4]} {tx_link_eop_cnt[5]} {tx_link_eop_cnt[6]} {tx_link_eop_cnt[7]} {tx_link_eop_cnt[8]} {tx_link_eop_cnt[9]} {tx_link_eop_cnt[10]} {tx_link_eop_cnt[11]} {tx_link_eop_cnt[12]} {tx_link_eop_cnt[13]} {tx_link_eop_cnt[14]} {tx_link_eop_cnt[15]} {tx_link_eop_cnt[16]} {tx_link_eop_cnt[17]} {tx_link_eop_cnt[18]} {tx_link_eop_cnt[19]} {tx_link_eop_cnt[20]} {tx_link_eop_cnt[21]} {tx_link_eop_cnt[22]} {tx_link_eop_cnt[23]} {tx_link_eop_cnt[24]} {tx_link_eop_cnt[25]} {tx_link_eop_cnt[26]} {tx_link_eop_cnt[27]} {tx_link_eop_cnt[28]} {tx_link_eop_cnt[29]} {tx_link_eop_cnt[30]} {tx_link_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 32 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {wr_eop_cnt[0]} {wr_eop_cnt[1]} {wr_eop_cnt[2]} {wr_eop_cnt[3]} {wr_eop_cnt[4]} {wr_eop_cnt[5]} {wr_eop_cnt[6]} {wr_eop_cnt[7]} {wr_eop_cnt[8]} {wr_eop_cnt[9]} {wr_eop_cnt[10]} {wr_eop_cnt[11]} {wr_eop_cnt[12]} {wr_eop_cnt[13]} {wr_eop_cnt[14]} {wr_eop_cnt[15]} {wr_eop_cnt[16]} {wr_eop_cnt[17]} {wr_eop_cnt[18]} {wr_eop_cnt[19]} {wr_eop_cnt[20]} {wr_eop_cnt[21]} {wr_eop_cnt[22]} {wr_eop_cnt[23]} {wr_eop_cnt[24]} {wr_eop_cnt[25]} {wr_eop_cnt[26]} {wr_eop_cnt[27]} {wr_eop_cnt[28]} {wr_eop_cnt[29]} {wr_eop_cnt[30]} {wr_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 32 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {rd_sop_cnt[0]} {rd_sop_cnt[1]} {rd_sop_cnt[2]} {rd_sop_cnt[3]} {rd_sop_cnt[4]} {rd_sop_cnt[5]} {rd_sop_cnt[6]} {rd_sop_cnt[7]} {rd_sop_cnt[8]} {rd_sop_cnt[9]} {rd_sop_cnt[10]} {rd_sop_cnt[11]} {rd_sop_cnt[12]} {rd_sop_cnt[13]} {rd_sop_cnt[14]} {rd_sop_cnt[15]} {rd_sop_cnt[16]} {rd_sop_cnt[17]} {rd_sop_cnt[18]} {rd_sop_cnt[19]} {rd_sop_cnt[20]} {rd_sop_cnt[21]} {rd_sop_cnt[22]} {rd_sop_cnt[23]} {rd_sop_cnt[24]} {rd_sop_cnt[25]} {rd_sop_cnt[26]} {rd_sop_cnt[27]} {rd_sop_cnt[28]} {rd_sop_cnt[29]} {rd_sop_cnt[30]} {rd_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 8 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {m_aixs_usr_tuser[0]} {m_aixs_usr_tuser[1]} {m_aixs_usr_tuser[2]} {m_aixs_usr_tuser[3]} {m_aixs_usr_tuser[4]} {m_aixs_usr_tuser[5]} {m_aixs_usr_tuser[6]} {m_aixs_usr_tuser[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 32 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {timer[0]} {timer[1]} {timer[2]} {timer[3]} {timer[4]} {timer[5]} {timer[6]} {timer[7]} {timer[8]} {timer[9]} {timer[10]} {timer[11]} {timer[12]} {timer[13]} {timer[14]} {timer[15]} {timer[16]} {timer[17]} {timer[18]} {timer[19]} {timer[20]} {timer[21]} {timer[22]} {timer[23]} {timer[24]} {timer[25]} {timer[26]} {timer[27]} {timer[28]} {timer[29]} {timer[30]} {timer[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 32 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {enc_sop_cnt[0]} {enc_sop_cnt[1]} {enc_sop_cnt[2]} {enc_sop_cnt[3]} {enc_sop_cnt[4]} {enc_sop_cnt[5]} {enc_sop_cnt[6]} {enc_sop_cnt[7]} {enc_sop_cnt[8]} {enc_sop_cnt[9]} {enc_sop_cnt[10]} {enc_sop_cnt[11]} {enc_sop_cnt[12]} {enc_sop_cnt[13]} {enc_sop_cnt[14]} {enc_sop_cnt[15]} {enc_sop_cnt[16]} {enc_sop_cnt[17]} {enc_sop_cnt[18]} {enc_sop_cnt[19]} {enc_sop_cnt[20]} {enc_sop_cnt[21]} {enc_sop_cnt[22]} {enc_sop_cnt[23]} {enc_sop_cnt[24]} {enc_sop_cnt[25]} {enc_sop_cnt[26]} {enc_sop_cnt[27]} {enc_sop_cnt[28]} {enc_sop_cnt[29]} {enc_sop_cnt[30]} {enc_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 32 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {rx_trans_eop_cnt[0]} {rx_trans_eop_cnt[1]} {rx_trans_eop_cnt[2]} {rx_trans_eop_cnt[3]} {rx_trans_eop_cnt[4]} {rx_trans_eop_cnt[5]} {rx_trans_eop_cnt[6]} {rx_trans_eop_cnt[7]} {rx_trans_eop_cnt[8]} {rx_trans_eop_cnt[9]} {rx_trans_eop_cnt[10]} {rx_trans_eop_cnt[11]} {rx_trans_eop_cnt[12]} {rx_trans_eop_cnt[13]} {rx_trans_eop_cnt[14]} {rx_trans_eop_cnt[15]} {rx_trans_eop_cnt[16]} {rx_trans_eop_cnt[17]} {rx_trans_eop_cnt[18]} {rx_trans_eop_cnt[19]} {rx_trans_eop_cnt[20]} {rx_trans_eop_cnt[21]} {rx_trans_eop_cnt[22]} {rx_trans_eop_cnt[23]} {rx_trans_eop_cnt[24]} {rx_trans_eop_cnt[25]} {rx_trans_eop_cnt[26]} {rx_trans_eop_cnt[27]} {rx_trans_eop_cnt[28]} {rx_trans_eop_cnt[29]} {rx_trans_eop_cnt[30]} {rx_trans_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 32 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {rd_cnt_eop[0]} {rd_cnt_eop[1]} {rd_cnt_eop[2]} {rd_cnt_eop[3]} {rd_cnt_eop[4]} {rd_cnt_eop[5]} {rd_cnt_eop[6]} {rd_cnt_eop[7]} {rd_cnt_eop[8]} {rd_cnt_eop[9]} {rd_cnt_eop[10]} {rd_cnt_eop[11]} {rd_cnt_eop[12]} {rd_cnt_eop[13]} {rd_cnt_eop[14]} {rd_cnt_eop[15]} {rd_cnt_eop[16]} {rd_cnt_eop[17]} {rd_cnt_eop[18]} {rd_cnt_eop[19]} {rd_cnt_eop[20]} {rd_cnt_eop[21]} {rd_cnt_eop[22]} {rd_cnt_eop[23]} {rd_cnt_eop[24]} {rd_cnt_eop[25]} {rd_cnt_eop[26]} {rd_cnt_eop[27]} {rd_cnt_eop[28]} {rd_cnt_eop[29]} {rd_cnt_eop[30]} {rd_cnt_eop[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 32 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {dec_eop_cnt[0]} {dec_eop_cnt[1]} {dec_eop_cnt[2]} {dec_eop_cnt[3]} {dec_eop_cnt[4]} {dec_eop_cnt[5]} {dec_eop_cnt[6]} {dec_eop_cnt[7]} {dec_eop_cnt[8]} {dec_eop_cnt[9]} {dec_eop_cnt[10]} {dec_eop_cnt[11]} {dec_eop_cnt[12]} {dec_eop_cnt[13]} {dec_eop_cnt[14]} {dec_eop_cnt[15]} {dec_eop_cnt[16]} {dec_eop_cnt[17]} {dec_eop_cnt[18]} {dec_eop_cnt[19]} {dec_eop_cnt[20]} {dec_eop_cnt[21]} {dec_eop_cnt[22]} {dec_eop_cnt[23]} {dec_eop_cnt[24]} {dec_eop_cnt[25]} {dec_eop_cnt[26]} {dec_eop_cnt[27]} {dec_eop_cnt[28]} {dec_eop_cnt[29]} {dec_eop_cnt[30]} {dec_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 32 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {dec_sop_cnt[0]} {dec_sop_cnt[1]} {dec_sop_cnt[2]} {dec_sop_cnt[3]} {dec_sop_cnt[4]} {dec_sop_cnt[5]} {dec_sop_cnt[6]} {dec_sop_cnt[7]} {dec_sop_cnt[8]} {dec_sop_cnt[9]} {dec_sop_cnt[10]} {dec_sop_cnt[11]} {dec_sop_cnt[12]} {dec_sop_cnt[13]} {dec_sop_cnt[14]} {dec_sop_cnt[15]} {dec_sop_cnt[16]} {dec_sop_cnt[17]} {dec_sop_cnt[18]} {dec_sop_cnt[19]} {dec_sop_cnt[20]} {dec_sop_cnt[21]} {dec_sop_cnt[22]} {dec_sop_cnt[23]} {dec_sop_cnt[24]} {dec_sop_cnt[25]} {dec_sop_cnt[26]} {dec_sop_cnt[27]} {dec_sop_cnt[28]} {dec_sop_cnt[29]} {dec_sop_cnt[30]} {dec_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 32 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {tx_link_sop_cnt[0]} {tx_link_sop_cnt[1]} {tx_link_sop_cnt[2]} {tx_link_sop_cnt[3]} {tx_link_sop_cnt[4]} {tx_link_sop_cnt[5]} {tx_link_sop_cnt[6]} {tx_link_sop_cnt[7]} {tx_link_sop_cnt[8]} {tx_link_sop_cnt[9]} {tx_link_sop_cnt[10]} {tx_link_sop_cnt[11]} {tx_link_sop_cnt[12]} {tx_link_sop_cnt[13]} {tx_link_sop_cnt[14]} {tx_link_sop_cnt[15]} {tx_link_sop_cnt[16]} {tx_link_sop_cnt[17]} {tx_link_sop_cnt[18]} {tx_link_sop_cnt[19]} {tx_link_sop_cnt[20]} {tx_link_sop_cnt[21]} {tx_link_sop_cnt[22]} {tx_link_sop_cnt[23]} {tx_link_sop_cnt[24]} {tx_link_sop_cnt[25]} {tx_link_sop_cnt[26]} {tx_link_sop_cnt[27]} {tx_link_sop_cnt[28]} {tx_link_sop_cnt[29]} {tx_link_sop_cnt[30]} {tx_link_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 32 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {tx_trans_eop_cnt[0]} {tx_trans_eop_cnt[1]} {tx_trans_eop_cnt[2]} {tx_trans_eop_cnt[3]} {tx_trans_eop_cnt[4]} {tx_trans_eop_cnt[5]} {tx_trans_eop_cnt[6]} {tx_trans_eop_cnt[7]} {tx_trans_eop_cnt[8]} {tx_trans_eop_cnt[9]} {tx_trans_eop_cnt[10]} {tx_trans_eop_cnt[11]} {tx_trans_eop_cnt[12]} {tx_trans_eop_cnt[13]} {tx_trans_eop_cnt[14]} {tx_trans_eop_cnt[15]} {tx_trans_eop_cnt[16]} {tx_trans_eop_cnt[17]} {tx_trans_eop_cnt[18]} {tx_trans_eop_cnt[19]} {tx_trans_eop_cnt[20]} {tx_trans_eop_cnt[21]} {tx_trans_eop_cnt[22]} {tx_trans_eop_cnt[23]} {tx_trans_eop_cnt[24]} {tx_trans_eop_cnt[25]} {tx_trans_eop_cnt[26]} {tx_trans_eop_cnt[27]} {tx_trans_eop_cnt[28]} {tx_trans_eop_cnt[29]} {tx_trans_eop_cnt[30]} {tx_trans_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 32 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {wr_ecp_cnt[0]} {wr_ecp_cnt[1]} {wr_ecp_cnt[2]} {wr_ecp_cnt[3]} {wr_ecp_cnt[4]} {wr_ecp_cnt[5]} {wr_ecp_cnt[6]} {wr_ecp_cnt[7]} {wr_ecp_cnt[8]} {wr_ecp_cnt[9]} {wr_ecp_cnt[10]} {wr_ecp_cnt[11]} {wr_ecp_cnt[12]} {wr_ecp_cnt[13]} {wr_ecp_cnt[14]} {wr_ecp_cnt[15]} {wr_ecp_cnt[16]} {wr_ecp_cnt[17]} {wr_ecp_cnt[18]} {wr_ecp_cnt[19]} {wr_ecp_cnt[20]} {wr_ecp_cnt[21]} {wr_ecp_cnt[22]} {wr_ecp_cnt[23]} {wr_ecp_cnt[24]} {wr_ecp_cnt[25]} {wr_ecp_cnt[26]} {wr_ecp_cnt[27]} {wr_ecp_cnt[28]} {wr_ecp_cnt[29]} {wr_ecp_cnt[30]} {wr_ecp_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 32 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {wr_sop_cnt[0]} {wr_sop_cnt[1]} {wr_sop_cnt[2]} {wr_sop_cnt[3]} {wr_sop_cnt[4]} {wr_sop_cnt[5]} {wr_sop_cnt[6]} {wr_sop_cnt[7]} {wr_sop_cnt[8]} {wr_sop_cnt[9]} {wr_sop_cnt[10]} {wr_sop_cnt[11]} {wr_sop_cnt[12]} {wr_sop_cnt[13]} {wr_sop_cnt[14]} {wr_sop_cnt[15]} {wr_sop_cnt[16]} {wr_sop_cnt[17]} {wr_sop_cnt[18]} {wr_sop_cnt[19]} {wr_sop_cnt[20]} {wr_sop_cnt[21]} {wr_sop_cnt[22]} {wr_sop_cnt[23]} {wr_sop_cnt[24]} {wr_sop_cnt[25]} {wr_sop_cnt[26]} {wr_sop_cnt[27]} {wr_sop_cnt[28]} {wr_sop_cnt[29]} {wr_sop_cnt[30]} {wr_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 32 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {rx_link_sop_cnt[0]} {rx_link_sop_cnt[1]} {rx_link_sop_cnt[2]} {rx_link_sop_cnt[3]} {rx_link_sop_cnt[4]} {rx_link_sop_cnt[5]} {rx_link_sop_cnt[6]} {rx_link_sop_cnt[7]} {rx_link_sop_cnt[8]} {rx_link_sop_cnt[9]} {rx_link_sop_cnt[10]} {rx_link_sop_cnt[11]} {rx_link_sop_cnt[12]} {rx_link_sop_cnt[13]} {rx_link_sop_cnt[14]} {rx_link_sop_cnt[15]} {rx_link_sop_cnt[16]} {rx_link_sop_cnt[17]} {rx_link_sop_cnt[18]} {rx_link_sop_cnt[19]} {rx_link_sop_cnt[20]} {rx_link_sop_cnt[21]} {rx_link_sop_cnt[22]} {rx_link_sop_cnt[23]} {rx_link_sop_cnt[24]} {rx_link_sop_cnt[25]} {rx_link_sop_cnt[26]} {rx_link_sop_cnt[27]} {rx_link_sop_cnt[28]} {rx_link_sop_cnt[29]} {rx_link_sop_cnt[30]} {rx_link_sop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 32 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {enc_eop_cnt[0]} {enc_eop_cnt[1]} {enc_eop_cnt[2]} {enc_eop_cnt[3]} {enc_eop_cnt[4]} {enc_eop_cnt[5]} {enc_eop_cnt[6]} {enc_eop_cnt[7]} {enc_eop_cnt[8]} {enc_eop_cnt[9]} {enc_eop_cnt[10]} {enc_eop_cnt[11]} {enc_eop_cnt[12]} {enc_eop_cnt[13]} {enc_eop_cnt[14]} {enc_eop_cnt[15]} {enc_eop_cnt[16]} {enc_eop_cnt[17]} {enc_eop_cnt[18]} {enc_eop_cnt[19]} {enc_eop_cnt[20]} {enc_eop_cnt[21]} {enc_eop_cnt[22]} {enc_eop_cnt[23]} {enc_eop_cnt[24]} {enc_eop_cnt[25]} {enc_eop_cnt[26]} {enc_eop_cnt[27]} {enc_eop_cnt[28]} {enc_eop_cnt[29]} {enc_eop_cnt[30]} {enc_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 32 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {rx_link_eop_cnt[0]} {rx_link_eop_cnt[1]} {rx_link_eop_cnt[2]} {rx_link_eop_cnt[3]} {rx_link_eop_cnt[4]} {rx_link_eop_cnt[5]} {rx_link_eop_cnt[6]} {rx_link_eop_cnt[7]} {rx_link_eop_cnt[8]} {rx_link_eop_cnt[9]} {rx_link_eop_cnt[10]} {rx_link_eop_cnt[11]} {rx_link_eop_cnt[12]} {rx_link_eop_cnt[13]} {rx_link_eop_cnt[14]} {rx_link_eop_cnt[15]} {rx_link_eop_cnt[16]} {rx_link_eop_cnt[17]} {rx_link_eop_cnt[18]} {rx_link_eop_cnt[19]} {rx_link_eop_cnt[20]} {rx_link_eop_cnt[21]} {rx_link_eop_cnt[22]} {rx_link_eop_cnt[23]} {rx_link_eop_cnt[24]} {rx_link_eop_cnt[25]} {rx_link_eop_cnt[26]} {rx_link_eop_cnt[27]} {rx_link_eop_cnt[28]} {rx_link_eop_cnt[29]} {rx_link_eop_cnt[30]} {rx_link_eop_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list m_aixs_usr_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list m_aixs_usr_tvalid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list s_aixs_usr_tready]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list s_aixs_usr_tvalid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets usr_clk]
