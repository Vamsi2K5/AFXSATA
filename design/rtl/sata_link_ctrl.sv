/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_ctrl.sv
Last Update     : 2025/04/06 20:09:04
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/06 20:09:04
Version         : 1.0
Description     : SATA Link Control Module - Manages the link layer of the SATA interface,
                  handling data encoding/decoding, flow control, and communication between
                  the physical layer and transport layer. This module coordinates read/write
                  operations and manages the SATA link state machine.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Control Module
// This module serves as the main controller for the SATA link layer, coordinating all link-level
// operations including data encoding/decoding, flow control, and communication with both the
// physical layer and transport layer.
module sata_link_ctrl #(
    parameter USER_W = 8               // User data width for AXI Stream interface
)
(
    // Clock and reset signals
    input    logic                     clk             ,   // Main clock signal
    input    logic                     rst_n           ,   // Active-low reset signal

    /***** phy layer *****/
    // Physical layer interface signals
    output   logic  [31         :0]    dat_o           ,   // Data output to PHY layer
    output   logic  [3          :0]    datchar_o       ,   // Data character output to PHY layer
    output   logic                     hreset          ,   // Hard reset request to PHY
    input    logic                     phyrdy          ,   // PHY ready signal
    output   logic                     slumber         ,   // Slumber power management mode
    output   logic                     partial         ,   // Partial power management mode
    output   logic                     nearafelb       ,   // Near-end analog loopback mode
    output   logic                     farafelb        ,   // Far-end analog loopback mode
    output   logic                     spdsedl         ,   // Speed selection from device list
    input    logic                     spdmode         ,   // Speed mode indicator
    input    logic                     device_detect   ,   // Device detection signal
    input    logic                     phy_internal_err,   // PHY internal error flag
    input    logic  [31         :0]    dat_i           ,   // Data input from PHY layer
    input    logic  [3          :0]    datchar_i       ,   // Data character input from PHY layer
    input    logic                     rxclock         ,   // Receive clock from PHY
    input    logic                     cominit         ,   // COMINIT signal from PHY
    input    logic                     comwake         ,   // COMWAKE signal from PHY
    input    logic                     comma           ,   // Comma character detection from PHY

    /***** trans layer *****/
    // Transport layer interface signals
    input    logic                     tl_ok           ,   // Transport layer OK signal
    input    logic                     tl_err          ,   // Transport layer error signal

    // Statistics counters
    output   logic  [31         :0]    dec_sop_cnt     ,   // Decode start of packet counter
    output   logic  [31         :0]    dec_eop_cnt     ,   // Decode end of packet counter
    output   logic  [31         :0]    enc_sop_cnt     ,   // Encode start of packet counter
    output   logic  [31         :0]    enc_eop_cnt     ,   // Encode end of packet counter
    output   logic  [31         :0]    wr_ecp_cnt      ,   // Write ECP (Error Correction Protocol) counter
    output   logic  [31         :0]    wr_err_cnt      ,   // Write error counter
    output   logic  [31         :0]    wr_sop_cnt      ,   // Write start of packet counter
    output   logic  [31         :0]    wr_eop_cnt      ,   // Write end of packet counter
    output   logic  [31         :0]    rd_ecp_cnt      ,   // Read ECP counter
    output   logic  [31         :0]    rd_err_cnt      ,   // Read error counter
    output   logic  [31         :0]    rd_sop_cnt      ,   // Read start of packet counter
    output   logic  [31         :0]    rd_eop_cnt      ,   // Read end of packet counter

    // Slave AXI Stream interface (from transport layer)
    input    logic  [31         :0]    s_aixs_tdata    ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_tvalid   ,   // Slave data valid signal
    output   logic                     s_aixs_tready   ,   // Slave ready signal

    // Master AXI Stream interface (to transport layer)
    output   logic  [31         :0]    m_aixs_tdata    ,   // Master data payload
    output   logic  [USER_W   -1:0]    m_aixs_tuser    ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_tvalid   ,   // Master data valid signal
    input    logic                     m_aixs_tready       // Master ready signal
);

// Output declarations for submodules
// Decoded data type from link decoder
sata_p_t                          dec_dat_type            ;   // Decoded data type
logic       [32         -1:0]     dec_dat_o               ;   // Decoded data output
logic       [4          -1:0]     dec_char_o              ;   // Decoded character output

// Encode control signals
logic                             roll_insert             ;   // Roll insertion request for encoding

// Arbitration signals
logic                             wr_req                  ;   // Write request from arbitration
logic                             rd_req                  ;   // Read request from arbitration

// Write module signals
logic                             wr_cpl                  ;   // Write completion signal
logic                             wr_no_busy              ;   // Write not busy signal
sata_p_t                          w_tx_dat_type           ;   // Write transmit data type
logic       [32         -1:0]     w_tx_dat                ;   // Write transmit data
logic       [4          -1:0]     w_tx_char               ;   // Write transmit character

// Read module signals
logic                             rd_cpl                  ;   // Read completion signal
logic                             rd_no_busy              ;   // Read not busy signal
sata_p_t                          r_tx_dat_type           ;   // Read transmit data type
logic       [32         -1:0]     r_tx_dat                ;   // Read transmit data
logic       [4          -1:0]     r_tx_char               ;   // Read transmit character

// Ingress module signals (data flow from transport to link layer)
logic       [32         -1:0]     ingress_m_aixs_tdata    ;   // Ingress master data
logic       [USER_W     -1:0]     ingress_m_aixs_tuser    ;   // Ingress master user signals
logic                             ingress_m_aixs_tvalid   ;   // Ingress master valid
logic                             ingress_m_aixs_tready   ;   // Ingress master ready

// Egress module signals (data flow from link to transport layer)
logic                             buffer_full             ;   // Buffer full indicator
logic       [32         -1:0]     egress_s_aixs_tdata     ;   // Egress slave data
logic       [USER_W     -1:0]     egress_s_aixs_tuser     ;   // Egress slave user signals
logic                             egress_s_aixs_tvalid    ;   // Egress slave valid
logic                             egress_s_aixs_tready    ;   // Egress slave ready

// Instantiate SATA link decoder module
// Responsible for decoding incoming data from the PHY layer
sata_link_decode u_sata_link_decode(
    .clk        	(clk            ),      // Clock signal
    .rst_n      	(rst_n          ),      // Reset signal
    .vld        	(phyrdy         ),      // Valid signal (PHY ready)
    .dat_i      	(dat_i          ),      // Data input from PHY
    .datachar_i 	(datchar_i      ),      // Data character input from PHY
    .dat_type   	(dec_dat_type   ),      // Decoded data type output
    .char_o         (dec_char_o     ),      // Decoded character output
    .dat_o      	(dec_dat_o      ),      // Decoded data output
    .sop_cnt        (dec_sop_cnt    ),      // Start of packet counter
    .eop_cnt        (dec_eop_cnt    )       // End of packet counter
);

// Instantiate SATA link arbitration module
// Manages access to the link layer between read and write operations
sata_link_arbt u_sata_link_arbt(
    .clk         	(clk          ),        // Clock signal
    .rst_n       	(rst_n        ),        // Reset signal
    .rx_req         (s_aixs_tvalid),        // Receive request from transport layer
    .roll_insert    (roll_insert  ),        // Roll insertion request
    .rx_dat_type 	(dec_dat_type ),        // Received data type from decoder
    .phyrdy      	(phyrdy       ),        // PHY ready signal
    .wr_req      	(wr_req       ),        // Write request output
    .wr_cpl      	(wr_cpl       ),        // Write completion input
    .wr_no_busy     (wr_no_busy   ),        // Write not busy input
    .rd_req      	(rd_req       ),        // Read request output
    .rd_cpl      	(rd_cpl       ),        // Read completion input
    .rd_no_busy     (rd_no_busy   )         // Read not busy input
);

// Instantiate SATA link write module
// Handles write operations from transport layer to PHY
sata_link_wrmod #(
    .USER_W 	(USER_W  )                  // User data width parameter
)
u_sata_link_wrmod(
    .clk           	(clk                    ),      // Clock signal
    .rst_n         	(rst_n                  ),      // Reset signal
    .phyrdy        	(phyrdy                 ),      // PHY ready signal
    .wr_req        	(wr_req                 ),      // Write request from arbitration
    .wr_cpl        	(wr_cpl                 ),      // Write completion output
    .wr_no_busy     (wr_no_busy             ),      // Write not busy output
    .roll_insert   	(roll_insert            ),      // Roll insertion request
    .s_aixs_tdata  	(ingress_m_aixs_tdata   ),      // Slave data input
    .s_aixs_tuser  	(ingress_m_aixs_tuser   ),      // Slave user signals input
    .s_aixs_tvalid 	(ingress_m_aixs_tvalid  ),      // Slave valid input
    .s_aixs_tready 	(ingress_m_aixs_tready  ),      // Slave ready output
    .rx_dat_type   	(dec_dat_type           ),      // Received data type
    .rx_dat        	(dec_dat_o              ),      // Received data
    .rx_char       	(dec_char_o             ),      // Received character
    .tx_dat_type   	(w_tx_dat_type          ),      // Transmit data type output
    .tx_dat        	(w_tx_dat               ),      // Transmit data output
    .tx_char       	(w_tx_char              ),      // Transmit character output
    .ecp_cnt        (wr_ecp_cnt             ),      // ECP counter output
    .err_cnt        (wr_err_cnt             ),      // Error counter output
    .tx_sop_cnt     (wr_sop_cnt             ),      // Transmit SOP counter
    .tx_eop_cnt     (wr_eop_cnt             )       // Transmit EOP counter
);

// Instantiate SATA link read module
// Handles read operations from PHY to transport layer
sata_link_rdmod #(
    .USER_W 	(USER_W  )                  // User data width parameter
)
u_sata_link_rdmod(
    .clk           	(clk                   ),       // Clock signal
    .rst_n         	(rst_n                 ),       // Reset signal
    .phyrdy        	(phyrdy                ),       // PHY ready signal
    .rd_req        	(rd_req                ),       // Read request from arbitration
    .rd_cpl        	(rd_cpl                ),       // Read completion output
    .rd_no_busy     (rd_no_busy            ),       // Read not busy output
    .roll_insert   	(roll_insert           ),       // Roll insertion request
    .m_aixs_tdata  	(egress_s_aixs_tdata   ),       // Master data output
    .m_aixs_tuser  	(egress_s_aixs_tuser   ),       // Master user signals output
    .m_aixs_tvalid 	(egress_s_aixs_tvalid  ),       // Master valid output
    .m_aixs_tready 	(egress_s_aixs_tready  ),       // Master ready input
    .buffer_full   	(buffer_full           ),       // Buffer full indicator
    .tl_ok         	(tl_ok                 ),       // Transport layer OK
    .tl_err        	(tl_err                ),       // Transport layer error
    .rx_dat_type   	(dec_dat_type          ),       // Received data type
    .rx_dat        	(dec_dat_o             ),       // Received data
    .rx_char       	(dec_char_o            ),       // Received character
    .tx_dat_type   	(r_tx_dat_type         ),       // Transmit data type output
    .tx_dat        	(r_tx_dat              ),       // Transmit data output
    .tx_char       	(r_tx_char             ),       // Transmit character output
    .ecp_cnt        (rd_ecp_cnt            ),       // ECP counter output
    .err_cnt        (rd_err_cnt            ),       // Error counter output
    .tx_sop_cnt     (rd_sop_cnt            ),       // Transmit SOP counter
    .tx_eop_cnt     (rd_eop_cnt            )        // Transmit EOP counter
);

// Instantiate SATA link encoder module
// Encodes data for transmission to the PHY layer
sata_link_encode u_sata_link_encode(
    .clk         	(clk          ),         // Clock signal
    .rst_n       	(rst_n        ),         // Reset signal
    .phyrdy         (phyrdy       ),         // PHY ready signal
    .vld         	(             ),         // Valid signal (unused)
    .roll_insert    (roll_insert  ),         // Roll insertion request
    .dat_o       	(dat_o        ),         // Data output to PHY
    .datachar_o  	(datchar_o    ),         // Data character output to PHY
    .wr_req      	(wr_req       ),         // Write request
    .wr_dat_type 	(w_tx_dat_type),         // Write data type
    .wr_char_i   	(w_tx_char    ),         // Write character input
    .wr_dat_i    	(w_tx_dat     ),         // Write data input
    .rd_req      	(rd_req       ),         // Read request
    .rd_dat_type 	(r_tx_dat_type),         // Read data type
    .rd_char_i   	(r_tx_char    ),         // Read character input
    .rd_dat_i    	(r_tx_dat     ),         // Read data input
    .sop_cnt        (enc_sop_cnt  ),         // Start of packet counter
    .eop_cnt        (enc_eop_cnt  )          // End of packet counter
);

// Instantiate SATA link ingress module
// Handles data flow from transport layer to link layer (write path)
sata_link_ingress #(
    .USER_W    	(USER_W  ),                  // User data width
    .NO_BUFFER 	(0       )                   // Buffer enable flag
)
u_sata_link_ingress(
    .clk           	(clk                    ),       // Clock signal
    .rst_n         	(rst_n                  ),       // Reset signal
    .s_aixs_tdata  	(s_aixs_tdata           ),       // Slave data input
    .s_aixs_tuser  	(s_aixs_tuser           ),       // Slave user signals input
    .s_aixs_tvalid 	(s_aixs_tvalid          ),       // Slave valid input
    .s_aixs_tready 	(s_aixs_tready          ),       // Slave ready output
    .m_aixs_tdata  	(ingress_m_aixs_tdata   ),       // Master data output
    .m_aixs_tuser  	(ingress_m_aixs_tuser   ),       // Master user signals output
    .m_aixs_tvalid 	(ingress_m_aixs_tvalid  ),       // Master valid output
    .m_aixs_tready 	(ingress_m_aixs_tready  )        // Master ready input
);

// Instantiate SATA link egress module
// Handles data flow from link layer to transport layer (read path)
sata_link_egress #(
    .USER_W  	(USER_W  )                   // User data width
)
u_sata_link_egress(
    .clk           	(clk                    ),       // Clock signal
    .rst_n         	(rst_n                  ),       // Reset signal
    .s_aixs_tdata  	(egress_s_aixs_tdata    ),       // Slave data input
    .s_aixs_tuser  	(egress_s_aixs_tuser    ),       // Slave user signals input
    .s_aixs_tvalid 	(egress_s_aixs_tvalid   ),       // Slave valid input
    .s_aixs_tready 	(egress_s_aixs_tready   ),       // Slave ready output
    .m_aixs_tdata  	(m_aixs_tdata           ),       // Master data output
    .m_aixs_tuser  	(m_aixs_tuser           ),       // Master user signals output
    .m_aixs_tvalid 	(m_aixs_tvalid          ),       // Master valid output
    .m_aixs_tready 	(m_aixs_tready          ),       // Master ready input
    .buffer_full   	(buffer_full            )        // Buffer full indicator
);

endmodule
