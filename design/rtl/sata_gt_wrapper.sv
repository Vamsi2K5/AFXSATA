/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_gt_wrapper.v
Last Update     : 2025/01/31 11:48:12
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/01/31 11:48:12
Version         : 1.0
Description     : SATA GT Wrapper - Wrapper module for SATA transceiver instantiation. 
                  This module provides a unified interface for different transceiver types
                  (GTX, GTH, etc.) and handles clocking, reset, and data path connections for
                  SATA physical layer communication.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_gt_wrapper #(
    parameter [5 -1:0]  POSTCUSOR = 5'b00000    ,   // Transmitter post-cursor emphasis control
    parameter [5 -1:0]  PRECUSOR  = 5'b00000    ,   // Transmitter pre-cursor emphasis control
    parameter [4 -1:0]  DIFFCTRL  = 4'b1100        // Transmitter differential output control
)(
    /************ sys_clk ************/
    input   logic               clk             ,   // System clock input
    input   logic               rst_n           ,   // Active low reset signal

    /************ gt_clk ************/
    input   logic               refclkp         ,   // Reference clock positive input
    input   logic               refclkn         ,   // Reference clock negative input
    input   logic               gtxrxp          ,   // Receiver serial data positive input
    input   logic               gtxrxn          ,   // Receiver serial data negative input
    output  logic               gtxtxn          ,   // Transmitter serial data negative output
    output  logic               gtxtxp          ,   // Transmitter serial data positive output

    /************ gt_dat ************/
    output  logic               gt_dat_rst      ,   // GT data path reset signal

    output  logic               rx_clk          ,   // Receiver clock output
    output  logic   [3   :0]    rx_charisk_out  ,   // Receiver character identifier (K-char)
    output  logic   [31  :0]    rx_data_out     ,   // Receiver data output

    output  logic               tx_clk          ,   // Transmitter clock output
    input   logic   [3   :0]    tx_charisk_in   ,   // Transmitter character identifier (K-char)
    input   logic   [31  :0]    tx_data_in      ,   // Transmitter data input

    /************ gt_OOB ************/
    output  logic               rx_comwake      ,   // Received COMWAKE signal (out-of-band)
    output  logic               rx_cominit      ,   // Received COMINIT signal (out-of-band)
    output  logic               rx_eleidle      ,   // Electrical idle detection

    input   logic               tx_cominit      ,   // Transmit COMINIT signal (out-of-band)
    input   logic               tx_comwake        // Transmit COMWAKE signal (out-of-band)

);

// Function to swap byte endianness in 32-bit data
function automatic logic [31:0] swap_endian(input logic [31:0] data);
    logic [31:0] swap_data;
    swap_data = {data[8*0 +: 8],data[8*1 +: 8],data[8*2 +: 8],data[8*3 +: 8]};
    return swap_data;
endfunction

// Function to swap nibble endianness in 4-bit character data
function automatic logic [31:0] swap_endian_char(input logic [3:0] data);
    logic [3:0] swap_data;
    swap_data = {data[0],data[1],data[2],data[3]};
    return swap_data;
endfunction


`ifdef GTX_IBERT_TEST

// IBERT test mode assignments
assign gt0_gtxrxp_in        = gtxrxp        ;
assign gt0_gtxrxn_in        = gtxrxn        ;
assign gtxtxn               = gt0_gtxtxn_out;
assign gtxtxp               = gt0_gtxtxp_out;
assign sysclk_in_i          = clk           ;

// IBUFDS_GTE2 primitive for reference clock buffering
IBUFDS_GTE2 ibufds_instQ0_CLK1  
(
    .O               (q0_clk1_gtrefclk  ),      // Buffered reference clock output
    .ODIV2           (                  ),      // Half-rate reference clock (not used)
    .CEB             (1'd0              ),      // Clock enable (active low)
    .I               (refclkp           ),      // Positive reference clock input
    .IB              (refclkn           )       // Negative reference clock input
);

// IBERT instantiation for GTX transceiver testing
ibert_7series_gtx_0 test_ibert_7series_gtx_0 (
  .TXN_O(gt0_gtxtxn_out),              // output wire [3 : 0] TXN_O
  .TXP_O(gt0_gtxtxp_out),              // output wire [3 : 0] TXP_O
  .RXOUTCLK_O(),    // output wire RXOUTCLK_O
  .RXN_I(gt0_gtxrxn_in),              // input wire [3 : 0] RXN_I
  .RXP_I(gt0_gtxrxp_in),              // input wire [3 : 0] RXP_I
  .GTREFCLK0_I(1'b0),  // input wire [0 : 0] GTREFCLK0_I
  .GTREFCLK1_I(q0_clk1_gtrefclk),  // input wire [0 : 0] GTREFCLK1_I
  .SYSCLK_I(sysclk_in_i)        // input wire SYSCLK_I
);
`elsif GTX
// GTX transceiver mode signals
logic              sysclk_in_i                 ;   // System clock internal signal
logic              gt0_txoutclk_i              ;   // Transmitter output clock
logic              gt0_txusrclk_i              ;   // Transmitter user clock
logic              gt0_txusrclk2_i             ;   // Transmitter user clock 2
logic              gt0_qplloutclk_i            ;   // QPLL output clock
logic              gt0_qplloutrefclk_i         ;   // QPLL output reference clock

logic              gt0_gtxrxp_in               ;   // GTX receiver positive input
logic              gt0_gtxrxn_in               ;   // GTX receiver negative input
logic              gt0_gtxtxn_out              ;   // GTX transmitter negative output
logic              gt0_gtxtxp_out              ;   // GTX transmitter positive output

logic              q0_clk1_gtrefclk            ;   // Reference clock signal

logic [5    -1:0]  gt0_txpostcursor_in         ;   // Transmitter post-cursor emphasis
logic [5    -1:0]  gt0_txprecursor_in          ;   // Transmitter pre-cursor emphasis

logic [4    -1:0]  gt0_txcharisk_in            ;   // Transmitter character identifier
logic [32   -1:0]  gt0_txdata_in               ;   // Transmitter data input

logic [4    -1:0]  gt0_rxcharisk_out           ;   // Receiver character identifier
logic [32   -1:0]  gt0_rxdata_out              ;   // Receiver data output

logic              gt0_txcominit_in            ;   // Transmitter COMINIT input
logic              gt0_txcomwake_in            ;   // Transmitter COMWAKE input
logic              gt0_rxcomwakedet_out        ;   // Receiver COMWAKE detect output
logic              gt0_rxcominitdet_out        ;   // Receiver COMINIT detect output
logic              gt0_rxelecidle_out          ;   // Receiver electrical idle output
logic              gt0_rxresetdone_out         ;   // Receiver reset done output

logic              gt0_rxbyteisaligned_out     ;   // Receiver byte alignment status

logic              gt0_txresetdone_out         ;   // Transmitter reset done output

logic              soft_reset_tx_in            ;   // Soft reset for transmitter
logic              soft_reset_rx_in            ;   // Soft reset for receiver
logic              gt0_tx_fsm_reset_done_out   ;   // Transmitter FSM reset done
logic              gt0_rx_fsm_reset_done_out   ;   // Receiver FSM reset done
logic              gt0_data_valid_in           ;   // Data valid input signal

logic              commonreset_i               ;   // Common reset signal
logic              gt0_gtrxreset_in            ;   // Receiver reset input

logic [16   -1:0]  gt0_drpdo_out               ;   // DRP data output
logic              gt0_drprdy_out              ;   // DRP ready output
logic [8    -1:0]  gt0_dmonitorout_out         ;   // Digital monitor output
logic              gt0_eyescandataerror_out    ;   // Eye scan data error output
logic [2    -1:0]  gt0_rxclkcorcnt_out         ;   // Receive clock correction count
logic [4    -1:0]  gt0_rxdisperr_out           ;   // Receive disparity error
logic [4    -1:0]  gt0_rxnotintable_out        ;   // Receive not in table error
logic [7    -1:0]  gt0_rxmonitorout_out        ;   // Receive monitor output
logic              gt0_rxoutclkfabric_out      ;   // Receiver fabric clock output
logic              gt0_txoutclkfabric_out      ;   // Transmitter fabric clock output
logic              gt0_txoutclkpcs_out         ;   // Transmitter PCS clock output

logic              glb_reset                   ;   // Global reset signal
logic              gt0_rxpmareset_in           ;   // Receiver PMA reset input
logic              gt0_gttxreset_in            ;   // Transmitter GT reset input

logic              gt0_qpllreset_t             ;   // QPLL reset signal
logic              gt0_rxusrclk_i              ;   // Receiver user clock
logic              gt0_rxusrclk2_i             ;   // Receiver user clock 2
logic              gt0_txdiffctrl_in           ;   // Transmitter differential control
logic              gt0_cpllfbclklost_out       ;   // CPLL feedback clock lost
logic              gt0_cplllock_out            ;   // CPLL lock output

// Common reset controller instantiation
gt_sata_common_reset #(
    .STABLE_CLOCK_PERIOD (10)        // Period of the stable clock driving this state-machine, unit is [ns]
)
common_reset_i
(    
    .STABLE_CLOCK   (sysclk_in_i        ),             //Stable Clock, either a stable clock from the PCB
    .SOFT_RESET     (soft_reset_tx_in   ),               //User Reset, can be pulled any time
    .COMMON_RESET   (commonreset_i      )              //Reset QPLL
);
//GT global reset
assign glb_reset = ~rst_n;

// GTX transceiver I/O assignments
assign gt0_gtxrxp_in        = gtxrxp        ;
assign gt0_gtxrxn_in        = gtxrxn        ;
assign gtxtxn               = gt0_gtxtxn_out;
assign gtxtxp               = gt0_gtxtxp_out;

// Reset signal assignments
assign soft_reset_tx_in     = glb_reset                                         ;
assign soft_reset_rx_in     = glb_reset                                         ;
assign gt0_gtrxreset_in     = glb_reset                                         ;
assign gt0_rxpmareset_in    = glb_reset                                         ;
assign gt0_gttxreset_in     = glb_reset                                         ;
assign gt_dat_rst           = gt0_txresetdone_out && gt0_tx_fsm_reset_done_out  ;
assign gt0_data_valid_in    = 1'b1                                     ;
//--------------------------- common qpll ------- --------------------//
//function :gen qpll
//output   :
//describe :use cpll,no use qpll
assign gt0_qpllreset_t  = commonreset_i;
gt_sata_common #(
    .WRAPPER_SIM_GTRESET_SPEEDUP("FALSE"),
    .SIM_QPLLREFCLK_SEL         (3'b001 )
)
common0_i(
    .QPLLREFCLKSEL_IN   (3'b001             ),
    .GTREFCLK0_IN       (1'd0               ),
    .GTREFCLK1_IN       (1'd0               ),
    .QPLLLOCK_OUT       (                   ),
    .QPLLLOCKDETCLK_IN  (sysclk_in_i        ),
    .QPLLOUTCLK_OUT     (gt0_qplloutclk_i   ),
    .QPLLOUTREFCLK_OUT  (gt0_qplloutrefclk_i),
    .QPLLREFCLKLOST_OUT (                   ),    
    .QPLLRESET_IN       (gt0_qpllreset_t    )
);
//IBUFDS_GTE2
IBUFDS_GTE2 ibufds_instQ0_CLK1  
(
    .O               (q0_clk1_gtrefclk  ),
    .ODIV2           (                  ),
    .CEB             (1'd0              ),
    .I               (refclkp           ),
    .IB              (refclkn           )
);
//--------------------------- user clock gen ---------------------------//
//function :gen user clock
//output   :gt0_txusrclk2_i,gt0_rxusrclk_i,gt0_rxusrclk2_i
//describe :the sata user clock is 150MHz
BUFG txoutclk_bufg0_i
(
    .I                              (gt0_txoutclk_i),
    .O                              (gt0_txusrclk_i)
);
assign gt0_txusrclk2_i      = gt0_txusrclk_i;
assign gt0_rxusrclk_i       = gt0_txusrclk_i;
assign gt0_rxusrclk2_i      = gt0_txusrclk_i;
assign tx_clk  	            = gt0_rxusrclk2_i;
assign rx_clk  	   	    = gt0_rxusrclk2_i;
//--------------------------- drp/system clock ---------------------------//
assign sysclk_in_i      = clk                   ;

//--------------------------- set parameter ---------------------------//
assign gt0_txpostcursor_in  = POSTCUSOR     ;
assign gt0_txprecursor_in   = PRECUSOR      ;
assign gt0_txdiffctrl_in    = DIFFCTRL      ;


//--------------------------- gt data stream ---------------------------//
assign rx_charisk_out   = swap_endian_char(gt0_rxcharisk_out);
assign rx_data_out      = swap_endian(gt0_rxdata_out)        ;
assign gt0_txcharisk_in = swap_endian_char(tx_charisk_in)    ;
assign gt0_txdata_in    = swap_endian(tx_data_in)            ;

//gtwizard_0 gt_sata_init_i
gt_sata gt_sata_init_i
(
    .sysclk_in                      (sysclk_in_i                ),  
    .soft_reset_tx_in               (soft_reset_tx_in           ),  
    .soft_reset_rx_in               (soft_reset_rx_in           ),  
    .dont_reset_on_data_error_in    (1'b0                       ),  
    .gt0_tx_fsm_reset_done_out      (gt0_tx_fsm_reset_done_out  ),
    .gt0_rx_fsm_reset_done_out      (gt0_rx_fsm_reset_done_out  ),
    .gt0_data_valid_in              (gt0_data_valid_in          ),

    //_____________________________________________________________________
    //_____________________________________________________________________
    //GT0  (X1Y0)

    //------------------------------- CPLL Ports -------------------------------
    .gt0_cpllfbclklost_out          (gt0_cpllfbclklost_out      ), // output wire gt0_cpllfbclklost_out
    .gt0_cplllock_out               (gt0_cplllock_out           ), // output wire gt0_cplllock_out
    .gt0_cplllockdetclk_in          (sysclk_in_i                ), // input wire sysclk_in_i
    .gt0_cpllreset_in               (1'b0                       ), // input wire gt0_cpllreset_in
    //------------------------ Channel - Clocking Ports ------------------------
    .gt0_gtrefclk0_in               (1'b0                       ), // input wire tied_to_ground_i
    .gt0_gtrefclk1_in               (q0_clk1_gtrefclk           ), // input wire q0_clk1_refclk_i
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt0_drpaddr_in                 (9'd0                       ), // input wire [8:0] gt0_drpaddr_in
    .gt0_drpclk_in                  (sysclk_in_i                ), // input wire sysclk_in_i
    .gt0_drpdi_in                   (16'd0                      ), // input wire [15:0] gt0_drpdi_in
    .gt0_drpdo_out                  (gt0_drpdo_out              ), // output wire [15:0] gt0_drpdo_out
    .gt0_drpen_in                   (1'd0                       ), // input wire gt0_drpen_in
    .gt0_drprdy_out                 (gt0_drprdy_out             ), // output wire gt0_drprdy_out
    .gt0_drpwe_in                   (1'b0                       ), // input wire gt0_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt0_dmonitorout_out            (gt0_dmonitorout_out        ), // output wire [7:0] gt0_dmonitorout_out
    //----------------------------- Loopback Ports -----------------------------
    .gt0_loopback_in                (3'b000                     ), // input wire [2:0] gt0_loopback_in
    //------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in            (1'd0                       ), // input wire gt0_eyescanreset_in
    .gt0_rxuserrdy_in               (1'd1                       ), // input wire gt0_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out       (gt0_eyescandataerror_out   ), // output wire gt0_eyescandataerror_out
    .gt0_eyescantrigger_in          (1'd0                       ), // input wire gt0_eyescantrigger_in
    //----------------- Receive Ports - Clock Correction Ports -----------------
    .gt0_rxclkcorcnt_out            (gt0_rxclkcorcnt_out        ), // output wire [1:0] gt0_rxclkcorcnt_out
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt0_rxusrclk_in                (gt0_rxusrclk_i             ), // input wire gt0_rxusrclk_i
    .gt0_rxusrclk2_in               (gt0_rxusrclk2_i            ), // input wire gt0_rxusrclk2_i
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt0_rxdata_out                 (gt0_rxdata_out             ), // output wire [31:0] gt0_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt0_rxdisperr_out              (gt0_rxdisperr_out          ), // output wire [3:0] gt0_rxdisperr_out
    .gt0_rxnotintable_out           (gt0_rxnotintable_out       ), // output wire [3:0] gt0_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt0_gtxrxp_in                  (gt0_gtxrxp_in              ), // input wire gt0_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt0_gtxrxn_in                  (gt0_gtxrxn_in              ), // input wire gt0_gtxrxn_in
    //------------ Receive Ports - RX Byte and Word Alignment Ports ------------
    .gt0_rxbyteisaligned_out        (gt0_rxbyteisaligned_out    ), // output wire gt0_rxbyteisaligned_out
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxdfelpmreset_in           (1'd0                       ), // input wire gt0_rxdfelpmreset_in
    .gt0_rxmonitorout_out           (gt0_rxmonitorout_out       ), // output wire [6:0] gt0_rxmonitorout_out
    .gt0_rxmonitorsel_in            (2'd00                      ), // input wire [1:0] gt0_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    .gt0_rxoutclkfabric_out         (gt0_rxoutclkfabric_out     ), // output wire gt0_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in               (gt0_gtrxreset_in           ), // input wire gt0_gtrxreset_in
    .gt0_rxpmareset_in              (gt0_rxpmareset_in           ), // input wire gt0_rxpmareset_in
    //----------------- Receive Ports - RX OOB Signaling ports -----------------
    .gt0_rxcomwakedet_out           (rx_comwake                 ), // output wire gt0_rxcomwakedet_out
    //---------------- Receive Ports - RX OOB Signaling ports  -----------------
    .gt0_rxcominitdet_out           (rx_cominit                 ), // output wire gt0_rxcominitdet_out
    //---------------- Receive Ports - RX OOB signalling Ports -----------------
    .gt0_rxelecidle_out             (rx_eleidle                 ), // output wire gt0_rxelecidle_out
    //--------------- Receive Ports - RX Polarity Control Ports ----------------
    .gt0_rxpolarity_in              (1'd0                       ), // input wire gt0_rxpolarity_in

    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt0_rxcharisk_out              (gt0_rxcharisk_out          ), // output wire [3:0] gt0_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt0_rxresetdone_out            (gt0_rxresetdone_out        ), // output wire gt0_rxresetdone_out
    //---------------------- TX Configurable Driver Ports ----------------------
    .gt0_txpostcursor_in            (gt0_txpostcursor_in        ), // input wire [4:0] gt0_txpostcursor_in
    .gt0_txprecursor_in             (gt0_txprecursor_in         ), // input wire [4:0] gt0_txprecursor_in
    //------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in               (gt0_gttxreset_in           ), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in               (1'd1                       ), // input wire gt0_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txusrclk_in                (gt0_txusrclk_i             ), // input wire gt0_txusrclk_i
    .gt0_txusrclk2_in               (gt0_txusrclk2_i            ), // input wire gt0_txusrclk2_i
    //------------- Transmit Ports - TX Configurable Driver Ports --------------
    .gt0_txdiffctrl_in              (gt0_txdiffctrl_in          ), // input wire [3:0] gt0_txdiffctrl_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt0_txdata_in                  (gt0_txdata_in              ), // input wire [31:0] gt0_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt0_gtxtxn_out                 (gt0_gtxtxn_out             ), // output wire gt0_gtxtxn_out
    .gt0_gtxtxp_out                 (gt0_gtxtxp_out             ), // output wire gt0_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt0_txoutclk_out               (gt0_txoutclk_i             ), // output wire gt0_txoutclk_i
    .gt0_txoutclkfabric_out         (gt0_txoutclkfabric_out     ), // output wire gt0_txoutclkfabric_out
    .gt0_txoutclkpcs_out            (gt0_txoutclkpcs_out        ), // output wire gt0_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt0_txcharisk_in               (gt0_txcharisk_in           ), // input wire [3:0] gt0_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt0_txresetdone_out            (gt0_txresetdone_out        ), // output wire gt0_txresetdone_out
    //---------------- Transmit Ports - TX OOB signalling Ports ----------------
    .gt0_txcominit_in               (tx_cominit                 ), // input wire gt0_txcominit_in
    .gt0_txcomwake_in               (tx_comwake                 ), // input wire gt0_txcomwake_in
    //--------------- Transmit Ports - TX Polarity Control Ports ---------------
    .gt0_txpolarity_in              (1'd0                       ), // input wire gt0_txpolarity_in

    .gt0_qplloutclk_in              (gt0_qplloutclk_i           ),
    .gt0_qplloutrefclk_in           (gt0_qplloutrefclk_i        )
);
`elsif ULTRA_GTH
// UltraScale GTH transceiver mode signals
logic               txpolarity_in                       ;   // Transmitter polarity control
logic [2      :0]   loopback_in                         ;   // Loopback control
logic [3      :0]   txdiffctrl_in                       ;   // Transmitter differential control
logic [4      :0]   txpostcursor_in                     ;   // Transmitter post-cursor emphasis
logic [4      :0]   txprecursor_in                      ;   // Transmitter pre-cursor emphasis

logic               gthrxn_int                          ;   // GTH receiver negative input
logic               gthrxp_int                          ;   // GTH receiver positive input
logic               gthtxn_int                          ;   // GTH transmitter negative output
logic               gthtxp_int                          ;   // GTH transmitter positive output
logic               gtwiz_userclk_tx_reset_int          ;   // Transmitter user clock reset
logic               gtwiz_userclk_tx_srcclk_int         ;   // Transmitter source clock (unused)
logic               gtwiz_userclk_tx_usrclk_int         ;   // Transmitter user clock (unused)
logic               gtwiz_userclk_tx_usrclk2_int        ;   // Transmitter user clock 2
logic               gtwiz_userclk_tx_active_int         ;   // Transmitter user clock active (unknown)
logic               gtwiz_userclk_rx_reset_int          ;   // Receiver user clock reset
logic               gtwiz_userclk_rx_srcclk_int         ;   // Receiver source clock (unused)
logic               gtwiz_userclk_rx_usrclk_int         ;   // Receiver user clock (unused)
logic               gtwiz_userclk_rx_usrclk2_int        ;   // Receiver user clock 2
logic               gtwiz_userclk_rx_active_int         ;   // Receiver user clock active (unknown)

logic               gtwiz_reset_clk_freerun_in          ;   // Free-running reset clock
logic               gtwiz_reset_all_in                  ;   // Global reset input
logic               gtwiz_reset_tx_pll_and_datapath_in  ;   // TX PLL and datapath reset
logic               gtwiz_reset_tx_datapath_in          ;   // TX datapath reset
logic               gtwiz_reset_rx_pll_and_datapath_in  ;   // RX PLL and datapath reset
logic               gtwiz_reset_rx_datapath_in          ;   // RX datapath reset
logic               gtwiz_reset_tx_done_int             ;   // TX reset done signal
logic               gtwiz_reset_rx_done_int             ;   // RX reset done signal

logic               gtwiz_reset_rx_cdr_stable_out       ;   // RX CDR stable output

logic [32   -1:0]   gtwiz_userdata_tx_int               ;   // TX user data internal
logic [32   -1:0]   gtwiz_userdata_rx_int               ;   // RX user data internal
logic [8    -1:0]   tx_charisk                          ;   // TX character identifier
logic [16   -1:0]   rx_charisk                          ;   // RX character identifier
logic               txpmaresetdone_int                  ;   // TX PMA reset done
logic               rxpmaresetdone_int                  ;   // RX PMA reset done
logic               gtpowergood_out                     ;   // GT power good output
logic [2      :0]   rxbufstatus_out                     ;   // RX buffer status
logic               rxbyteisaligned_out                 ;   // RX byte alignment status
logic [1      :0]   rxclkcorcnt_out                     ;   // RX clock correction count

logic [15     :0]   rxctrl1_out                         ;   // RX control 1 output
logic [7      :0]   rxctrl2_out                         ;   // RX control 2 output
logic [7      :0]   rxctrl3_out                         ;   // RX control 3 output
logic               rxelecidle_out                      ;   // RX electrical idle output
logic               txcomfinish_out                     ;   // TX COM finish output

logic               sys_clk                             ;   // System clock
logic               glb_reset                           ;   // Global reset
logic               glb_reset_buf                       ;   // Buffered global reset
logic               gt_refclk                           ;   // GT reference clock



//GT CLOCK
assign gthrxn_int                           = gtxrxn;
assign gthrxp_int                           = gtxrxp;
assign gtxtxn                               = gthtxn_int;
assign gtxtxp                               = gthtxp_int;

//USER CLOCK
assign tx_clk                               = gtwiz_userclk_tx_usrclk2_int;
assign rx_clk                               = gtwiz_userclk_rx_usrclk2_int;

//GT global reset
assign glb_reset = ~rst_n;
BUFG bufg_clk_freerun_inst (
    .I (glb_reset    ),
    .O (glb_reset_buf) 
);

assign gtwiz_reset_clk_freerun_in           = glb_reset_buf;
assign gtwiz_reset_all_in                   = glb_reset_buf;
assign gtwiz_reset_tx_pll_and_datapath_in   = glb_reset_buf;
assign gtwiz_reset_tx_datapath_in           = glb_reset_buf;
assign gtwiz_reset_rx_pll_and_datapath_in   = glb_reset_buf;
assign gtwiz_reset_rx_datapath_in           = glb_reset_buf;

//USER reset
assign gt_dat_rst                           = gtwiz_reset_tx_done_int && gtwiz_reset_rx_done_int;


//USER Data
assign gtwiz_userdata_tx_int                = swap_endian(tx_data_in)                ;
assign tx_charisk                           = {4'b0,swap_endian_char(tx_charisk_in)} ;
assign rx_data_out                          = swap_endian(gtwiz_userdata_rx_int)     ;
assign rx_charisk_out                       = swap_endian_char(rx_charisk[3:0])      ;

//SYC CLOCK
assign sys_clk = clk;

assign txpolarity_in = 1'b0;
assign loopback_in   = 3'b000;

//REF CLOCK
IBUFDS_GTE3 #(
.REFCLK_EN_TX_PATH  (1'b0),
.REFCLK_HROW_CK_SEL (2'b00),
.REFCLK_ICNTL_RX    (2'b00)
)
IBUFDS_GTE3_MGTREFCLK0_X0Y3_INST (
    .I     (refclkp     ),
    .IB    (refclkn     ),
    .CEB   (1'b0        ),
    .O     (gt_refclk   ),
    .ODIV2 (            )
);

assign gtwiz_userclk_tx_reset_int = ~(&txpmaresetdone_int);
assign gtwiz_userclk_rx_reset_int = ~(&rxpmaresetdone_int);

// GTH transceiver wrapper instantiation
gth_sata_wrapper gth_sata_wrapper_inst (
    .gthrxn_in                                (gthrxn_int                               )
    ,.gthrxp_in                               (gthrxp_int                               )
    ,.gthtxn_out                              (gthtxn_int                               )
    ,.gthtxp_out                              (gthtxp_int                               )

    ,.gtwiz_userclk_tx_reset_in               (gtwiz_userclk_tx_reset_int               )
    ,.gtwiz_userclk_tx_srcclk_out             (gtwiz_userclk_tx_srcclk_int              )
    ,.gtwiz_userclk_tx_usrclk_out             (gtwiz_userclk_tx_usrclk_int              )
    ,.gtwiz_userclk_tx_usrclk2_out            (gtwiz_userclk_tx_usrclk2_int             )
    ,.gtwiz_userclk_tx_active_out             (gtwiz_userclk_tx_active_int              )
    ,.gtwiz_userclk_rx_reset_in               (gtwiz_userclk_rx_reset_int               )
    ,.gtwiz_userclk_rx_srcclk_out             (gtwiz_userclk_rx_srcclk_int              )
    ,.gtwiz_userclk_rx_usrclk_out             (gtwiz_userclk_rx_usrclk_int              )
    ,.gtwiz_userclk_rx_usrclk2_out            (gtwiz_userclk_rx_usrclk2_int             )
    ,.gtwiz_userclk_rx_active_out             (gtwiz_userclk_rx_active_int              )

    ,.gtwiz_reset_clk_freerun_in              ({1{sys_clk          }}                   )
    ,.gtwiz_reset_all_in                      ({1{gtwiz_reset_all_in}}                  )
    ,.gtwiz_reset_tx_pll_and_datapath_in      (gtwiz_reset_tx_pll_and_datapath_in       )
    ,.gtwiz_reset_tx_datapath_in              (gtwiz_reset_tx_datapath_in               )
    ,.gtwiz_reset_rx_pll_and_datapath_in      ({1{gtwiz_reset_rx_pll_and_datapath_in}}  )
    ,.gtwiz_reset_rx_datapath_in              ({1{gtwiz_reset_rx_datapath_in}}          )
    ,.gtwiz_reset_rx_cdr_stable_out           (gtwiz_reset_rx_cdr_stable_out            )
    ,.gtwiz_reset_tx_done_out                 (gtwiz_reset_tx_done_int                  )
    ,.gtwiz_reset_rx_done_out                 (gtwiz_reset_rx_done_int                  )

    ,.gtwiz_userdata_tx_in                    (gtwiz_userdata_tx_int                    )
    ,.gtwiz_userdata_rx_out                   (gtwiz_userdata_rx_int                    )

    ,.drpclk_in                               (sys_clk                                  )
    ,.gtrefclk0_in                            (gt_refclk                                )
    ,.loopback_in                             (loopback_in                              )
    ,.rx8b10ben_in                            (1'b1                                     )
    ,.rxbufreset_in                           (1'b0                                     )
    ,.tx8b10ben_in                            (1'b1                                     )
    ,.txcominit_in                            (tx_cominit                               )
    ,.txcomwake_in                            (tx_comwake                               )
    ,.txctrl0_in                              (16'd0                                    )
    ,.txctrl1_in                              (16'd0                                    )
    ,.txctrl2_in                              (tx_charisk                               )
    ,.txdiffctrl_in                           (DIFFCTRL                                 )
    ,.txpolarity_in                           (txpolarity_in                            )
    ,.txpostcursor_in                         (POSTCUSOR                                )
    ,.txprecursor_in                          (PRECUSOR                                 )
    ,.gtpowergood_out                         (gtpowergood_out                          )
    ,.rxbufstatus_out                         (rxbufstatus_out                          )
    ,.rxbyteisaligned_out                     (rxbyteisaligned_out                      )
    ,.rxclkcorcnt_out                         (rxclkcorcnt_out                          )
    ,.rxcominitdet_out                        (rx_cominit                               )
    ,.rxcomwakedet_out                        (rx_comwake                               )
    ,.rxctrl0_out                             (rx_charisk                               )
    ,.rxctrl1_out                             (rxctrl1_out                              )
    ,.rxctrl2_out                             (rxctrl2_out                              )
    ,.rxctrl3_out                             (rxctrl3_out                              )
    ,.rxpmaresetdone_out                      (rxpmaresetdone_int                       )
    ,.txpmaresetdone_out                      (txpmaresetdone_int                       )

    ,.rxelecidlemode_in                       (2'b00                                    )                                    // input wire [1 : 0] rxelecidlemode_in
    ,.rxelecidle_out                          (rxelecidle_out                           )                                          // output wire [0 : 0] rxelecidle_out
    ,.txcomfinish_out                         (txcomfinish_out                          )                                        // output wire [0 : 0] txcomfinish_out
);

`endif

endmodule