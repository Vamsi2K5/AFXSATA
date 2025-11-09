`timescale 1ns/1ns

/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_wrapper.sv
Last Update     : 2025/01/28 11:54:28
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/01/28 11:54:28
Version         : 1.0
Description     : SATA PHY & Link Layer Wrapper - Top-level module that integrates the SATA 
                  physical layer, link layer, transport layer, and command processing modules.
                  This module provides a complete SATA controller interface for user applications.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Wrapper Module
// This is the top-level module that integrates all SATA controller components including:
// - Physical layer (PHY) interface
// - Link layer control
// - Transport layer processing
// - Command and DMA controller
// It provides a clean interface for user applications to interact with SATA devices.
module sata_wrapper (
    /************ sys_clk ************/
    input   logic                           clk                 ,   // System clock input
    /************ gt_clk ************/
    input   logic                           refclkp             ,   // Reference clock positive
    input   logic                           refclkn             ,   // Reference clock negative
    input   logic                           gtxrxp              ,   // GTX receiver positive input
    input   logic                           gtxrxn              ,   // GTX receiver negative input
    output  logic                           gtxtxn              ,   // GTX transmitter negative output
    output  logic                           gtxtxp              ,   // GTX transmitter positive output

    /************ debug ************/
    output   logic  [31                :0]  rx_link_sop_cnt     ,   // Received link start of packet counter
    output   logic  [31                :0]  rx_link_eop_cnt     ,   // Received link end of packet counter
    output   logic  [31                :0]  tx_link_sop_cnt     ,   // Transmitted link start of packet counter
    output   logic  [31                :0]  tx_link_eop_cnt     ,   // Transmitted link end of packet counter
    output   logic  [31                :0]  rx_cmd_cnt          ,   // Received command counter
    output   logic  [31                :0]  tx_cmd_cnt          ,   // Transmitted command counter
    output   logic  [31                :0]  rx_trans_sop_cnt    ,   // Received transport start of packet counter
    output   logic  [31                :0]  rx_trans_eop_cnt    ,   // Received transport end of packet counter
    output   logic  [31                :0]  tx_trans_sop_cnt    ,   // Transmitted transport start of packet counter
    output   logic  [31                :0]  tx_trans_eop_cnt    ,   // Transmitted transport end of packet counter

    output   logic  [31                :0]  dec_sop_cnt         ,   // Decode start of packet counter
    output   logic  [31                :0]  dec_eop_cnt         ,   // Decode end of packet counter
    output   logic  [31                :0]  enc_sop_cnt         ,   // Encode start of packet counter
    output   logic  [31                :0]  enc_eop_cnt         ,   // Encode end of packet counter
    output   logic  [31                :0]  wr_ecp_cnt          ,   // Write ECP (Error Correction Protocol) counter
    output   logic  [31                :0]  wr_err_cnt          ,   // Write error counter
    output   logic  [31                :0]  wr_sop_cnt          ,   // Write start of packet counter
    output   logic  [31                :0]  wr_eop_cnt          ,   // Write end of packet counter
    output   logic  [31                :0]  rd_ecp_cnt          ,   // Read ECP counter
    output   logic  [31                :0]  rd_err_cnt          ,   // Read error counter
    output   logic  [31                :0]  rd_sop_cnt          ,   // Read start of packet counter
    output   logic  [31                :0]  rd_eop_cnt          ,   // Read end of packet counter

    /************ system control ************/
    input    logic                          soft_reset          ,   // Software reset input (active high)

    /************ user control ************/

    output   logic                          usr_clk             ,   // User clock output
    output   logic                          usr_rst             ,   // User reset output (active low)

    input    logic [2                -1:0]  usr_ctrl            ,   // User control signals
    input    logic [72               -1:0]  usr_cmd             ,   // User command input: {RW,len[22:0],addr[47:0]}
    input    logic                          usr_cmd_req         ,   // User command request
    output   logic                          usr_cmd_ack         ,   // User command acknowledge

    input    logic [31                 :0]  s_aixs_usr_tdata    ,   // Slave AXI stream data input
    input    logic [`LINK_USER_W     -1:0]  s_aixs_usr_tuser    ,   // Slave AXI stream user signals: {drop,err,keep[3:0],sop,eop}
    input    logic                          s_aixs_usr_tvalid   ,   // Slave AXI stream valid signal
    output   logic                          s_aixs_usr_tready   ,   // Slave AXI stream ready signal

    output   logic [31                 :0]  m_aixs_usr_tdata    ,   // Master AXI stream data output
    output   logic [`LINK_USER_W     -1:0]  m_aixs_usr_tuser    ,   // Master AXI stream user signals: {drop,err,keep[3:0],sop,eop}
    output   logic                          m_aixs_usr_tvalid   ,   // Master AXI stream valid signal
    input    logic                          m_aixs_usr_tready       // Master AXI stream ready signal
);

// Internal signal declarations for PHY interface
logic                         gt_dat_clk          ;   // GT data clock
logic                         gt_dat_rst          ;   // GT data reset

logic   [3             :0]    rx_charisk_out      ;   // Received character identifier (K-char)
logic   [31            :0]    rx_data_out         ;   // Received data from PHY

logic   [3             :0]    tx_charisk_in       ;   // Transmit character identifier (K-char)
logic   [31            :0]    tx_data_in          ;   // Transmit data to PHY

logic                         rx_comwake          ;   // Received COMWAKE signal (out-of-band)
logic                         rx_cominit          ;   // Received COMINIT signal (out-of-band)
logic                         rx_eleidle          ;   // Electrical idle detection
logic                         tx_cominit          ;   // Transmit COMINIT signal (out-of-band)
logic                         tx_comwake          ;   // Transmit COMWAKE signal (out-of-band)

// Link layer interface signals
logic   [31            :0]    dat_i               ;   // Data input to link layer
logic   [3             :0]    datchar_i           ;   // Data character input to link layer
logic                         hreset              ;   // Hard reset request to link layer
logic                         phyrdy              ;   // PHY ready signal
logic                         slumber             ;   // Slumber power management mode
logic                         partial             ;   // Partial power management mode
logic                         nearafelb           ;   // Near-end analog loopback mode
logic                         farafelb            ;   // Far-end analog loopback mode
logic                         spdsedl             ;   // Speed selection from device list
logic                         spdmode             ;   // Speed mode indicator
logic                         device_detect       ;   // Device detection signal
logic                         phy_internal_err    ;   // PHY internal error flag
logic  [31             :0]    phy2link_dat        ;   // Data from PHY to link layer
logic  [3              :0]    phy2link_datchar    ;   // Data character from PHY to link layer
logic                         rxclock             ;   // Receive clock from PHY
logic                         cominit             ;   // COMINIT signal from PHY
logic                         comwake             ;   // COMWAKE signal from PHY
logic                         comma               ;   // Comma character detection from PHY

// Link layer output signals
logic  [31             :0]    link2phy_dat        ;   // Data from link layer to PHY
logic  [3              :0]    link2phy_datchar    ;   // Data character from link layer to PHY
logic  [31             :0]    s_aixs_tdata        ;   // Slave AXI stream data (link to transport)
logic  [`LINK_USER_W -1:0]    s_aixs_tuser        ;   // Slave AXI stream user signals (link to transport)
logic                         s_aixs_tvalid       ;   // Slave AXI stream valid signal (link to transport)
logic                         s_aixs_tready       ;   // Slave AXI stream ready signal (link to transport)
logic  [31             :0]    m_aixs_tdata        ;   // Master AXI stream data (transport to link)
logic  [`LINK_USER_W -1:0]    m_aixs_tuser        ;   // Master AXI stream user signals (transport to link)
logic                         m_aixs_tvalid       ;   // Master AXI stream valid signal (transport to link)
logic                         m_aixs_tready       ;   // Master AXI stream ready signal (transport to link)

// Command interface signals
logic                         phy_rstn            ;   // PHY reset (active low)

cmd_t                         s_cmd               ;   // Slave command output (D2H format)
logic                         s_req               ;   // Slave command request
logic                         s_ack               ;   // Slave command acknowledge
cmd_t                         m_cmd               ;   // Master command input (H2D format)
logic                         m_req               ;   // Master command request
logic                         m_ack               ;   // Master command acknowledge

// DMA and PIO control signals
logic                         dma_active          ;   // DMA active signal
logic                         pio_setup           ;   // PIO setup signal

// Transport layer data stream signals
logic  [31             :0]    s_aixs_trans_tdata  ;   // Slave AXI stream data (transport data path)
logic  [`LINK_USER_W -1:0]    s_aixs_trans_tuser  ;   // Slave AXI stream user signals: {drop,err,keep[3:0],sop,eop}
logic                         s_aixs_trans_tvalid ;   // Slave AXI stream valid signal (transport data path)
logic                         s_aixs_trans_tready ;   // Slave AXI stream ready signal (transport data path)

logic  [31             :0]    m_aixs_trans_tdata  ;   // Master AXI stream data (transport data path)
logic  [`LINK_USER_W -1:0]    m_aixs_trans_tuser  ;   // Master AXI stream user signals: {drop,err,keep[3:0],sop,eop}
logic                         m_aixs_trans_tvalid ;   // Master AXI stream valid signal (transport data path)
logic                         m_aixs_trans_tready ;   // Master AXI stream ready signal (transport data path)

// Clock signals
logic                         rx_clk              ;   // Receive clock
logic                         tx_clk              ;   // Transmit clock

// Reset and control signals
logic                         hr_reset            ;   // Hard reset
logic                         vio_reset           ;   // VIO reset
logic                         link_err            ;   // Link error flag

// Transport layer acknowledge signals
logic  [2            -1:0]    tl_ack              ;   // Transport layer acknowledge signals

// Clock assignment for user interface
assign usr_clk = tx_clk;

// PHY reset generator
// Generates a reset signal for the PHY based on the hard reset signal
sata_reset_gen#(
    .CYCLE            (150_000_000         ),   // Reset duration in clock cycles
    .POLARI           (1                   )    // Reset polarity: 1=active high
)
u0_sata_phy_reset_gen
(
    .clk                  (clk              ),   // Clock input
    .din                  (~hr_reset        ),   // Input data/control signal (inverted hard reset)
    .rst_o                (phy_rstn         )    // Generated reset output
);

// SATA GT (Gigabit Transceiver) Wrapper
// Handles the physical layer interface including clocking, reset, and data paths
sata_gt_wrapper u1_sata_gt_wrapper (
    .clk             (clk                   ),   // System clock
    .rst_n           (phy_rstn & soft_reset ),   // Reset signal (active low)

    .refclkp         (refclkp           ),       // Reference clock positive
    .refclkn         (refclkn           ),       // Reference clock negative
    .gtxrxp          (gtxrxp            ),       // Receiver serial data positive input
    .gtxrxn          (gtxrxn            ),       // Receiver serial data negative input
    .gtxtxn          (gtxtxn            ),       // Transmitter serial data negative output
    .gtxtxp          (gtxtxp            ),       // Transmitter serial data positive output

    .rx_clk          (rx_clk            ),       // Receiver clock output
    .tx_clk          (tx_clk            ),       // Transmitter clock output
    .gt_dat_rst      (gt_dat_rst        ),       // GT data path reset signal

    .rx_charisk_out  (rx_charisk_out    ),       // Receiver character identifier (K-char)
    .rx_data_out     (rx_data_out       ),       // Receiver data output

    .tx_charisk_in   (tx_charisk_in     ),       // Transmitter character identifier (K-char)
    .tx_data_in      (tx_data_in        ),       // Transmitter data input

    .rx_comwake      (rx_comwake        ),       // Received COMWAKE signal (out-of-band)
    .rx_cominit      (rx_cominit        ),       // Received COMINIT signal (out-of-band)
    .rx_eleidle      (rx_eleidle        ),       // Electrical idle detection
    .tx_cominit      (tx_cominit        ),       // Transmit COMINIT signal (out-of-band)
    .tx_comwake      (tx_comwake        )        // Transmit COMWAKE signal (out-of-band)
);

// SATA PHY Control Module
// Implements the physical layer control for SATA interface including link initialization,
// speed negotiation, out-of-band signaling, and data transmission/reception control
sata_phy_ctrl u2_sata_phy_ctrl (
    .rx_clk          (rx_clk            ),       // Receive clock from PHY
    .tx_clk          (tx_clk            ),       // Transmit clock to PHY
    .rst_n           (gt_dat_rst        ),       // Active low reset signal
    
    .timeout_time    (750000000         ),       // Timeout value for link state transitions
    .hr_reset        (hr_reset          ),       // Hard reset request to link layer
    
    .rx_charisk      (rx_charisk_out    ),       // Received character identifier (K-char)
    .rx_data         (rx_data_out       ),       // Received data from PHY

    .tx_charisk      (tx_charisk_in     ),       // Transmit character identifier (K-char)
    .tx_data         (tx_data_in        ),       // Transmit data to PHY

    .rx_comwake      (rx_comwake        ),       // Received COMWAKE signal (out-of-band)
    .rx_cominit      (rx_cominit        ),       // Received COMINIT signal (out-of-band)
    .rx_eleidle      (rx_eleidle        ),       // Electrical idle detection

    .tx_cominit      (tx_cominit        ),       // Transmit COMINIT signal (out-of-band)
    .tx_comwake      (tx_comwake        ),       // Transmit COMWAKE signal (out-of-band)

    .dat_i           (link2phy_dat      ),       // Data input from link layer
    .datchar_i       (link2phy_datchar  ),       // Data character input from link layer
    .hreset          (hreset            ),       // Hard reset request to link layer
    .phyrdy          (phyrdy            ),       // PHY ready signal to link layer
    .slumber         (slumber           ),       // Slumber power management mode
    .partial         (partial           ),       // Partial power management mode
    .nearafelb       (nearafelb         ),       // Near-end analog loopback mode
    .farafelb        (farafelb          ),       // Far-end analog loopback mode
    .spdsedl         (spdsedl           ),       // Speed selection from device list
    .spdmode         (spdmode           ),       // Speed mode indicator
    .device_detect   (device_detect     ),       // Device detection signal
    .phy_internal_err(phy_internal_err  ),       // PHY internal error flag
    .dat_o           (phy2link_dat      ),       // Data output to link layer
    .datchar_o       (phy2link_datchar  ),       // Data character output to link layer
    .rxclock         (rxclock           ),       // Receive clock output
    .cominit         (cominit           ),       // COMINIT signal output
    .comwake         (comwake           ),       // COMWAKE signal output
    .comma           (comma             )        // Comma character detection output
);

// User reset generator
// Generates a reset signal for the user logic based on PHY data reset and PHY ready signals
sata_reset_gen#(
    .CYCLE            (2            ),           // Reset duration in clock cycles
    .POLARI           (1            )            // Reset polarity: 1=active high
)
u6_sata_usr_reset_gen
(
    .clk                  (usr_clk              ),   // Clock input (user clock)
    .din                  (gt_dat_rst && phyrdy ),   // Input data/control signal (GT reset AND PHY ready)
    .rst_o                (usr_rst              )    // Generated reset output (user reset)
);

// SATA Link Control Module
// Manages the link layer of the SATA interface, handling data encoding/decoding, 
// flow control, and communication between the physical layer and transport layer
sata_link_ctrl u3_sata_link_ctrl(
    .clk                (usr_clk           ),       // Main clock signal
    .rst_n              (usr_rst           ),       // Active-low reset signal
    .dat_o              (link2phy_dat      ),       // Data output to PHY layer
    .datchar_o          (link2phy_datchar  ),       // Data character output to PHY layer
    .hreset             (hreset            ),       // Hard reset request to PHY
    .phyrdy             (phyrdy            ),       // PHY ready signal
    .slumber            (slumber           ),       // Slumber power management mode
    .partial            (partial           ),       // Partial power management mode
    .nearafelb          (nearafelb         ),       // Near-end analog loopback mode
    .farafelb           (farafelb          ),       // Far-end analog loopback mode
    .spdsedl            (spdsedl           ),       // Speed selection from device list
    .spdmode            (spdmode           ),       // Speed mode indicator
    .device_detect      (device_detect     ),       // Device detection signal
    .phy_internal_err   (phy_internal_err  ),       // PHY internal error flag
    .dat_i              (phy2link_dat      ),       // Data input from PHY layer
    .datchar_i          (phy2link_datchar  ),       // Data character input from PHY layer
    .rxclock            (rxclock           ),       // Receive clock from PHY
    .cominit            (cominit           ),       // COMINIT signal from PHY
    .comwake            (comwake           ),       // COMWAKE signal from PHY
    .comma              (comma             ),       // Comma character detection from PHY
    .tl_ok              (tl_ack[0]         ),       // Transport layer OK signal
    .tl_err             (tl_ack[1]         ),       // Transport layer error signal
    .dec_sop_cnt        (dec_sop_cnt       ),       // Decode start of packet counter
    .dec_eop_cnt        (dec_eop_cnt       ),       // Decode end of packet counter
    .enc_sop_cnt        (enc_sop_cnt       ),       // Encode start of packet counter
    .enc_eop_cnt        (enc_eop_cnt       ),       // Encode end of packet counter
    .wr_ecp_cnt         (wr_ecp_cnt        ),       // Write ECP (Error Correction Protocol) counter
    .wr_err_cnt         (wr_err_cnt        ),       // Write error counter
    .wr_sop_cnt         (wr_sop_cnt        ),       // Write start of packet counter
    .wr_eop_cnt         (wr_eop_cnt        ),       // Write end of packet counter
    .rd_ecp_cnt         (rd_ecp_cnt        ),       // Read ECP counter
    .rd_err_cnt         (rd_err_cnt        ),       // Read error counter
    .rd_sop_cnt         (rd_sop_cnt        ),       // Read start of packet counter
    .rd_eop_cnt         (rd_eop_cnt        ),       // Read end of packet counter
    .s_aixs_tdata       (s_aixs_tdata      ),       // Slave AXI Stream interface (from transport layer)
    .s_aixs_tuser       (s_aixs_tuser      ),       // Slave user signals {drop,err,keep[3:0],sop,eop}
    .s_aixs_tvalid      (s_aixs_tvalid     ),       // Slave data valid signal
    .s_aixs_tready      (s_aixs_tready     ),       // Slave ready signal
    .m_aixs_tdata       (m_aixs_tdata      ),       // Master AXI Stream interface (to transport layer)
    .m_aixs_tuser       (m_aixs_tuser      ),       // Master user signals {drop,err,keep[3:0],sop,eop}
    .m_aixs_tvalid      (m_aixs_tvalid     ),       // Master data valid signal
    .m_aixs_tready      (m_aixs_tready     )        // Master ready signal
);

// SATA Transport Layer Module
// Implements the transport layer of the SATA protocol stack, handling command processing,
// data streaming, and interface management between the link layer and user application
sata_transport #(
    .USER_W     (`LINK_USER_W  )                    // User data width for AXI Stream interface
)
u4_sata_transport(
    .clk                  (usr_clk              ),   // Main clock signal
    .rst_n                (usr_rst              ),   // Active-low reset signal
    .tl_ack               (tl_ack               ),   // Transport layer acknowledge signals
    .s_aixs_link_tdata    (m_aixs_tdata         ),   // Slave data payload (from link layer)
    .s_aixs_link_tuser    (m_aixs_tuser         ),   // Slave user signals {drop,err,keep[3:0],sop,eop} (from link layer)
    .s_aixs_link_tvalid   (m_aixs_tvalid        ),   // Slave data valid signal (from link layer)
    .s_aixs_link_tready   (m_aixs_tready        ),   // Slave ready signal (from link layer)
    .m_aixs_link_tdata    (s_aixs_tdata         ),   // Master data payload (to link layer)
    .m_aixs_link_tuser    (s_aixs_tuser         ),   // Master user signals {drop,err,keep[3:0],sop,eop} (to link layer)
    .m_aixs_link_tvalid   (s_aixs_tvalid        ),   // Master data valid signal (to link layer)
    .m_aixs_link_tready   (s_aixs_tready        ),   // Master ready signal (to link layer)
    
    .m_cmd                (m_cmd                ),   // Master command input (H2D format)
    .m_req                (m_req                ),   // Master command request
    .m_ack                (m_ack                ),   // Master command acknowledge
    .s_cmd                (s_cmd                ),   // Slave command output (D2H format)
    .s_req                (s_req                ),   // Slave command request
    .s_ack                (s_ack                ),   // Slave command acknowledge

    .dma_active           (dma_active           ),   // DMA active signal output
    .pio_setup            (pio_setup            ),   // PIO setup signal output

    .s_aixs_trans_tdata   (s_aixs_trans_tdata   ),   // Slave data payload (transport data path)
    .s_aixs_trans_tuser   (s_aixs_trans_tuser   ),   // Slave user signals {drop,err,keep[3:0],sop,eop} (transport data path)
    .s_aixs_trans_tvalid  (s_aixs_trans_tvalid  ),   // Slave data valid signal (transport data path)
    .s_aixs_trans_tready  (s_aixs_trans_tready  ),   // Slave ready signal (transport data path)
    .m_aixs_trans_tdata   (m_aixs_trans_tdata   ),   // Master data payload (transport data path)
    .m_aixs_trans_tuser   (m_aixs_trans_tuser   ),   // Master user signals {drop,err,keep[3:0],sop,eop} (transport data path)
    .m_aixs_trans_tvalid  (m_aixs_trans_tvalid  ),   // Master data valid signal (transport data path)
    .m_aixs_trans_tready  (m_aixs_trans_tready  ),   // Master ready signal (transport data path)
    .rx_link_sop_cnt      (rx_link_sop_cnt      ),   // Received link start of packet counter
    .rx_link_eop_cnt      (rx_link_eop_cnt      ),   // Received link end of packet counter
    .tx_link_sop_cnt      (tx_link_sop_cnt      ),   // Transmitted link start of packet counter
    .tx_link_eop_cnt      (tx_link_eop_cnt      ),   // Transmitted link end of packet counter
    .rx_cmd_cnt           (rx_cmd_cnt           ),   // Received command counter
    .tx_cmd_cnt           (tx_cmd_cnt           ),   // Transmitted command counter
    .rx_trans_sop_cnt     (rx_trans_sop_cnt     ),   // Received transport start of packet counter
    .rx_trans_eop_cnt     (rx_trans_eop_cnt     ),   // Received transport end of packet counter
    .tx_trans_sop_cnt     (tx_trans_sop_cnt     ),   // Transmitted transport start of packet counter
    .tx_trans_eop_cnt     (tx_trans_eop_cnt     )    // Transmitted transport end of packet counter
);

// SATA Command and DMA Controller Module
// Manages SATA command processing and DMA data transfer operations, handling read/write 
// command execution, data buffering, and interface control between user logic and SATA transport layer
sata_command_dma_ctrl #(
    .TIMER      (150000000    ),                    // Timer value for initial delay
    .USER_W     (`LINK_USER_W )                     // User data width
)
u5_sata_command_dma_ctrl(
    .clk                  (usr_clk                    ),   // Clock signal
    .rst_n                (usr_rst                    ),   // Reset signal (active low)
    .ctrl                 (usr_ctrl                   ),   // Control signals
    .s_aixs_trans_tdata   (m_aixs_trans_tdata         ),   // Transaction data input
    .s_aixs_trans_tuser   (m_aixs_trans_tuser         ),   // Transaction user signals {drop,err,keep[3:0],sop,eop}
    .s_aixs_trans_tvalid  (m_aixs_trans_tvalid        ),   // Transaction data valid
    .s_aixs_trans_tready  (m_aixs_trans_tready        ),   // Transaction ready signal
    .m_aixs_trans_tdata   (s_aixs_trans_tdata         ),   // Transaction data output
    .m_aixs_trans_tuser   (s_aixs_trans_tuser         ),   // Transaction user signals output {drop,err,keep[3:0],sop,eop}
    .m_aixs_trans_tvalid  (s_aixs_trans_tvalid        ),   // Transaction data valid output
    .m_aixs_trans_tready  (s_aixs_trans_tready        ),   // Transaction ready input
    .cmd                  ({usr_cmd_req,usr_cmd    }  ),   // Application command input
    .cmd_ack              (usr_cmd_ack                ),   // Command acknowledge output
    .read_count           (                           ),   // Read sector count (unused)
    .s_aixs_cmd_tdata     (s_aixs_usr_tdata           ),   // Command data input
    .s_aixs_cmd_tuser     (s_aixs_usr_tuser           ),   // Command user signals {drop,err,keep[3:0],sop,eop}
    .s_aixs_cmd_tvalid    (s_aixs_usr_tvalid          ),   // Command data valid
    .s_aixs_cmd_tready    (s_aixs_usr_tready          ),   // Command ready signal
    .m_aixs_cmd_tdata     (m_aixs_usr_tdata           ),   // Command data output
    .m_aixs_cmd_tuser     (m_aixs_usr_tuser           ),   // Command user signals output {drop,err,keep[3:0],sop,eop}
    .m_aixs_cmd_tvalid    (m_aixs_usr_tvalid          ),   // Command data valid output
    .m_aixs_cmd_tready    (m_aixs_usr_tready          ),   // Command ready input
    .m_cmd                (m_cmd                      ),   // Master command output
    .m_req                (m_req                      ),   // Master request output
    .m_ack                (m_ack                      ),   // Master acknowledge input
    .s_cmd                (s_cmd                      ),   // Slave command input
    .s_req                (s_req                      ),   // Slave request input
    .s_ack                (s_ack                      ),   // Slave acknowledge output
    .dma_active           (dma_active                 ),   // DMA active signal
    .pio_setup            (pio_setup                  )    // PIO setup signal
);

endmodule