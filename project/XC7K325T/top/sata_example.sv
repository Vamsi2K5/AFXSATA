/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_example.sv
Last Update     : 2025/11/25 11:54:28
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/11/25 11:54:28
Version         : 1.0
Description     : SATA controller example design with BIST functionality. This top-level module 
                  integrates the SATA wrapper and BIST modules to provide a complete SATA 
                  testing environment with VIO control interface.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_example(
    input   logic                          clk                 , // Differential clock input positive
    input   logic                          refclkp             , // Reference clock input positive
    input   logic                          refclkn             , // Reference clock input negative
    input   logic                          gtxrxp              , // Serial data receive input positive
    input   logic                          gtxrxn              , // Serial data receive input negative
    output  logic                          gtxtxn              , // Serial data transmit output negative
    output  logic                          gtxtxp               // Serial data transmit output positive
);

// User clock and reset signals
logic                           usr_clk             ; // User clock from SATA wrapper
logic                           usr_rst             ; // User reset from SATA wrapper

// AIXS user interface signals (to SATA core)
(*mark_debug = "true"*)logic  [31                 :0]  s_aixs_usr_tdata    ; // Data payload
(*mark_debug = "true"*)logic  [8                -1:0]  s_aixs_usr_tuser    ; // User sideband signals: {drop,err,keep[3:0],sop,eop}
(*mark_debug = "true"*)logic                           s_aixs_usr_tvalid   ; // Valid signal for transmit data
(*mark_debug = "true"*)logic                           s_aixs_usr_tready   ; // Ready signal from receiver

// AIXS user interface signals (from SATA core)
(*mark_debug = "true"*)logic  [31                 :0]  m_aixs_usr_tdata    ; // Received data payload
(*mark_debug = "true"*)logic  [8                -1:0]  m_aixs_usr_tuser    ; // User sideband signals: {drop,err,keep[3:0],sop,eop}
(*mark_debug = "true"*)logic                           m_aixs_usr_tvalid   ; // Valid signal for received data
(*mark_debug = "true"*)logic                           m_aixs_usr_tready   ; // Ready signal for receiver

// Command interface signals to SATA wrapper
logic  [71               -1:0]  cmd_dat             ; // Command data: {RW,len[22:0],addr[47:0]}
logic                           cmd_wr              ; // Write command flag (0=read, 1=write)
logic                           cmd_req             ; // Command request
logic                           cmd_ack             ; // Command acknowledge

// BIST configuration parameters
logic  [32               -1:0]  level               ; // LFSR level threshold for randomization
logic                           mode                ; // Test mode: 0=normal, 1=trigger
logic  [2                -1:0]  speed_test          ; // Speed test mode: 0=normal, 1=write, 2=read
logic                           tirg                ; // Trigger signal
logic  [32               -1:0]  cycle               ; // Number of test cycles
logic  [22               -1:0]  num                 ; // Number of data words per transfer
logic  [48               -1:0]  addr                ; // Starting address for test
logic                           enable              ; // Enable signal for BIST

// BIST monitoring counters
(*mark_debug = "true"*)logic  [32               -1:0]  timer               ; // Timer for seconds counter
(*mark_debug = "true"*)logic  [31                 :0]  err_cnt             ; // Error count
(*mark_debug = "true"*)logic  [31                 :0]  wr_cnt_sop          ; // Write start-of-packet count
(*mark_debug = "true"*)logic  [31                 :0]  wr_cnt_eop          ; // Write end-of-packet count
(*mark_debug = "true"*)logic  [31                 :0]  rd_cnt_sop          ; // Read start-of-packet count
(*mark_debug = "true"*)logic  [31                 :0]  rd_cnt_eop          ; // Read end-of-packet count

// Link layer counters
(*mark_debug = "true"*)logic  [31                 :0]  rx_link_sop_cnt     ; // Received link layer SOP count
(*mark_debug = "true"*)logic  [31                 :0]  rx_link_eop_cnt     ; // Received link layer EOP count
(*mark_debug = "true"*)logic  [31                 :0]  tx_link_sop_cnt     ; // Transmit link layer SOP count
(*mark_debug = "true"*)logic  [31                 :0]  tx_link_eop_cnt     ; // Transmit link layer EOP count

// Command layer counters
(*mark_debug = "true"*)logic  [31                 :0]  rx_cmd_cnt          ; // Received command count
(*mark_debug = "true"*)logic  [31                 :0]  tx_cmd_cnt          ; // Transmit command count

// Transport layer counters
(*mark_debug = "true"*)logic  [31                 :0]  rx_trans_sop_cnt    ; // Received transport SOP count
(*mark_debug = "true"*)logic  [31                 :0]  rx_trans_eop_cnt    ; // Received transport EOP count
(*mark_debug = "true"*)logic  [31                 :0]  tx_trans_sop_cnt    ; // Transmit transport SOP count
(*mark_debug = "true"*)logic  [31                 :0]  tx_trans_eop_cnt    ; // Transmit transport EOP count

// Encoder/decoder counters
(*mark_debug = "true"*)logic  [31                 :0]  dec_sop_cnt         ; // Decoder SOP count
(*mark_debug = "true"*)logic  [31                 :0]  dec_eop_cnt         ; // Decoder EOP count
(*mark_debug = "true"*)logic  [31                 :0]  enc_sop_cnt         ; // Encoder SOP count
(*mark_debug = "true"*)logic  [31                 :0]  enc_eop_cnt         ; // Encoder EOP count

// Write/read operation counters
(*mark_debug = "true"*)logic  [31                 :0]  wr_ecp_cnt          ; // Write ECP count
(*mark_debug = "true"*)logic  [31                 :0]  wr_err_cnt          ; // Write error count
(*mark_debug = "true"*)logic  [31                 :0]  wr_sop_cnt          ; // Write SOP count
(*mark_debug = "true"*)logic  [31                 :0]  wr_eop_cnt          ; // Write EOP count
(*mark_debug = "true"*)logic  [31                 :0]  rd_ecp_cnt          ; // Read ECP count
(*mark_debug = "true"*)logic  [31                 :0]  rd_err_cnt          ; // Read error count
(*mark_debug = "true"*)logic  [31                 :0]  rd_sop_cnt          ; // Read SOP count
(*mark_debug = "true"*)logic  [31                 :0]  rd_eop_cnt          ; // Read EOP count

/***
mode:0,normal;1,trig
speed_test:0,normal;1,write test;2,read test
num:1~0x20_0000 dword,8MB
***/

// Virtual I/O for controlling BIST parameters
vio_sata_example u_vio_sata_example (
  .clk(usr_clk),                // input wire clk
  .probe_out0(mode),  // output wire [0 : 0] probe_out0
  .probe_out1(tirg),  // output wire [0 : 0] probe_out1
  .probe_out2(cycle),  // output wire [31 : 0] probe_out2
  .probe_out3(num),  // output wire [15 : 0] probe_out3 
  .probe_out4(addr),  // output wire [47 : 0] probe_out4
  .probe_out5(enable), // output wire [0 : 0] probe_out5
  .probe_out6(level),  // output wire [31 : 0] probe_out5
  .probe_out7(speed_test)  // output wire [31 : 0] probe_out5
);

// SATA wrapper instantiation - contains the main SATA protocol implementation
sata_wrapper u_sata_wrapper (
    .clk                 (clk                   ),
    .refclkp             (refclkp               ),
    .refclkn             (refclkn               ),
    .gtxrxp              (gtxrxp                ),
    .gtxrxn              (gtxrxn                ),
    .gtxtxn              (gtxtxn                ),
    .gtxtxp              (gtxtxp                ),

    .rx_link_sop_cnt     (rx_link_sop_cnt       ),
    .rx_link_eop_cnt     (rx_link_eop_cnt       ),
    .tx_link_sop_cnt     (tx_link_sop_cnt       ),
    .tx_link_eop_cnt     (tx_link_eop_cnt       ),
    .rx_cmd_cnt          (rx_cmd_cnt            ),
    .tx_cmd_cnt          (tx_cmd_cnt            ),
    .rx_trans_sop_cnt    (rx_trans_sop_cnt      ),
    .rx_trans_eop_cnt    (rx_trans_eop_cnt      ),
    .tx_trans_sop_cnt    (tx_trans_sop_cnt      ),
    .tx_trans_eop_cnt    (tx_trans_eop_cnt      ),
    .dec_sop_cnt         (dec_sop_cnt           ),
    .dec_eop_cnt         (dec_eop_cnt           ),
    .enc_sop_cnt         (enc_sop_cnt           ),
    .enc_eop_cnt         (enc_eop_cnt           ),
    .wr_ecp_cnt          (wr_ecp_cnt            ),
    .wr_err_cnt          (wr_err_cnt            ),
    .wr_sop_cnt          (wr_sop_cnt            ),
    .wr_eop_cnt          (wr_eop_cnt            ),
    .rd_ecp_cnt          (rd_ecp_cnt            ),
    .rd_err_cnt          (rd_err_cnt            ),
    .rd_sop_cnt          (rd_sop_cnt            ),
    .rd_eop_cnt          (rd_eop_cnt            ),

    .soft_reset 		 (1'b1                  ),

    .usr_clk             (usr_clk               ),
    .usr_rst             (usr_rst               ),
    .usr_ctrl            (2'd1                  ),
    .usr_cmd             ({cmd_wr,cmd_dat}      ),//{RW,len[22:0],addr[47:0]}
    .usr_cmd_req         (cmd_req               ),
    .usr_cmd_ack         (cmd_ack               ),

    .s_aixs_usr_tdata    (s_aixs_usr_tdata      ),
    .s_aixs_usr_tuser    (s_aixs_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .s_aixs_usr_tvalid   (s_aixs_usr_tvalid     ),
    .s_aixs_usr_tready   (s_aixs_usr_tready     ),

    .m_aixs_usr_tdata    (m_aixs_usr_tdata      ),
    .m_aixs_usr_tuser    (m_aixs_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .m_aixs_usr_tvalid   (m_aixs_usr_tvalid     ),
    .m_aixs_usr_tready   (m_aixs_usr_tready     ) 
);

// SATA BIST (Built-In Self-Test) instantiation
sata_bist u_sata_bist(
    .clk                 (usr_clk               ),
    .rst_n               (usr_rst               ),

    .level               (level                 ),
    .speed_test          (speed_test            ),
    .mode                (mode                  ),//0,normal 1,trig
    .tirg                (tirg                  ),
    .cycle               (cycle                 ),
    .num                 (num                   ),//dw
    .addr                (addr                  ),
    .enable              (enable                ),
    .second_timer        (timer                 ),

    .err_cnt             (err_cnt               ),
    .wr_cnt_sop          (wr_cnt_sop            ),
    .wr_cnt_eop          (wr_cnt_eop            ),
    .rd_cnt_sop          (rd_cnt_sop            ),
    .rd_cnt_eop          (rd_cnt_eop            ),

    .cmd_dat             (cmd_dat               ),
    .cmd_wr              (cmd_wr                ),
    .cmd_req             (cmd_req               ),
    .cmd_ack             (cmd_ack               ),

    .s_axis_sbt_tdata    (m_aixs_usr_tdata      ),
    .s_axis_sbt_tuser    (m_aixs_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .s_axis_sbt_tvalid   (m_aixs_usr_tvalid     ),
    .s_axis_sbt_tready   (m_aixs_usr_tready     ),

    .m_axis_sbt_tdata    (s_aixs_usr_tdata      ),
    .m_axis_sbt_tuser    (s_aixs_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .m_axis_sbt_tvalid   (s_aixs_usr_tvalid     ),
    .m_axis_sbt_tready   (s_aixs_usr_tready     ) 
);

endmodule