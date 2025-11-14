//------------------------------------------------------------------------------
//  (c) Copyright 2013-2018 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------


`timescale 1ps/1ps

// =====================================================================================================================
// This example design wrapper module instantiates the core and any helper blocks which the user chose to exclude from
// the core, connects them as appropriate, and maps enabled ports
// =====================================================================================================================

module gth_sata_wrapper (
  input  wire [0:0] gthrxn_in
 ,input  wire [0:0] gthrxp_in
 ,output wire [0:0] gthtxn_out
 ,output wire [0:0] gthtxp_out
 ,input  wire [0:0] gtwiz_userclk_tx_reset_in
 ,output wire [0:0] gtwiz_userclk_tx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_tx_active_out
 ,input  wire [0:0] gtwiz_userclk_rx_reset_in
 ,output wire [0:0] gtwiz_userclk_rx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_rx_active_out
 ,input  wire [0:0] gtwiz_reset_clk_freerun_in
 ,input  wire [0:0] gtwiz_reset_all_in
 ,input  wire [0:0] gtwiz_reset_tx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_tx_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_datapath_in
 ,output wire [0:0] gtwiz_reset_rx_cdr_stable_out
 ,output wire [0:0] gtwiz_reset_tx_done_out
 ,output wire [0:0] gtwiz_reset_rx_done_out
 ,input  wire [31:0] gtwiz_userdata_tx_in
 ,output wire [31:0] gtwiz_userdata_rx_out
 ,input  wire [0:0] drpclk_in
 ,input  wire [0:0] gtrefclk0_in
 ,input  wire [2:0] loopback_in
 ,input  wire [0:0] rx8b10ben_in
 ,input  wire [0:0] rxbufreset_in
 ,input  wire [0:0] tx8b10ben_in
 ,input  wire [0:0] txcominit_in
 ,input  wire [0:0] txcomwake_in
 ,input  wire [15:0] txctrl0_in
 ,input  wire [15:0] txctrl1_in
 ,input  wire [7:0] txctrl2_in
 ,input  wire [3:0] txdiffctrl_in
 ,input  wire [0:0] txpolarity_in
 ,input  wire [0:0] rxpolarity_in
 ,input  wire [4:0] txpostcursor_in
 ,input  wire [4:0] txprecursor_in
 ,output wire [0:0] gtpowergood_out
 ,output wire [2:0] rxbufstatus_out
 ,output wire [0:0] rxbyteisaligned_out
 ,output wire [1:0] rxclkcorcnt_out
 ,output wire [0:0] rxcominitdet_out
 ,output wire [0:0] rxcomwakedet_out
 ,output wire [15:0] rxctrl0_out
 ,output wire [15:0] rxctrl1_out
 ,output wire [7:0] rxctrl2_out
 ,output wire [7:0] rxctrl3_out
 ,output wire [0:0] rxpmaresetdone_out
 ,output wire [0:0] txpmaresetdone_out
 ,input wire [1:0] rxelecidlemode_in                                    // input wire [1 : 0] rxelecidlemode_in
 ,output wire rxelecidle_out                                      // output wire [0 : 0] rxelecidle_out
 ,output wire txcomfinish_out                                    // output wire [0 : 0] txcomfinish_out
);

//------------------------------------------------------------------------------
//  (c) Copyright 2013-2018 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------


// =====================================================================================================================
// This file contains functions available for example design HDL generation as required
// =====================================================================================================================

// Function to populate a bit mapping of enabled transceiver common blocks to transceiver quads
function [47:0] f_pop_cm_en (
  input integer in_null
);
begin : main_f_pop_cm_en
  integer i;
  reg [47:0] tmp;
  for (i = 0; i < 192; i = i + 4) begin
    if ((P_CHANNEL_ENABLE[i]   ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+1] ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+2] ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+3] ==  1'b1))
      tmp[i/4] = 1'b1;
    else
      tmp[i/4] = 1'b0;
  end
  f_pop_cm_en = tmp;
end
endfunction

// Function to calculate a pointer to a master channel's packed index
function integer f_calc_pk_mc_idx (
  input integer idx_mc
);
begin : main_f_calc_pk_mc_idx
  integer i, j;
  integer tmp;
  j = 0;
  for (i = 0; i < 192; i = i + 1) begin
    if (P_CHANNEL_ENABLE[i] == 1'b1) begin
      if (i == idx_mc)
        tmp = j;
      else
        j = j + 1;
    end
  end
  f_calc_pk_mc_idx = tmp;
end
endfunction

// Function to calculate the upper bound of a transceiver common-related signal within a packed vector, for a given
// signal width and unpacked common index
function integer f_ub_cm (
  input integer width,
  input integer index
);
begin : main_f_ub_cm
  integer i, j;
  j = 0;
  for (i = 0; i <= index; i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1)
      j = j + 1;
  end
  f_ub_cm = (width * j) - 1;
end
endfunction

// Function to calculate the lower bound of a transceiver common-related signal within a packed vector, for a given
// signal width and unpacked common index
function integer f_lb_cm (
  input integer width,
  input integer index
);
begin : main_f_lb_cm
  integer i, j;
  j = 0;
  for (i = 0; i < index; i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1)
      j = j + 1;
  end
  f_lb_cm = (width * j);
end
endfunction

// Function to calculate the packed vector index of a transceiver common, provided the packed vector index of the
// associated transceiver channel
function integer f_idx_cm (
  input integer index
);
begin : main_f_idx_cm
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (P_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+2] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+1] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i]   == 1'b1)
        j = j + 1;
    end

    if (j >= (index + 1)) begin
      flag   = 1;
      result = k;
    end
  end
  f_idx_cm = result - 1;
end
endfunction

// Function to calculate the packed vector index of the upper bound transceiver channel which is associated with the
// provided transceiver common packed vector index
function integer f_idx_ch_ub (
  input integer index
);
begin : main_f_idx_ch_ub
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin

    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (P_CHANNEL_ENABLE[i]   == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+1] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+2] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
      if (k == index + 1) begin
        flag   = 1;
        result = j;
      end
    end

  end
  f_idx_ch_ub = result - 1;
end
endfunction

// Function to calculate the packed vector index of the lower bound transceiver channel which is associated with the
// provided transceiver common packed vector index
function integer f_idx_ch_lb (
  input integer index
);
begin : main_f_idx_ch_lb
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin

    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (k == index + 1) begin
        flag   = 1;
        result = j + 1;
      end
      else begin
        if (P_CHANNEL_ENABLE[i]   == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+1] == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+2] == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+3] == 1'b1)
          j = j + 1;
      end
    end

  end
  f_idx_ch_lb = result - 1;
end
endfunction

  // ===================================================================================================================
  // PARAMETERS AND FUNCTIONS
  // ===================================================================================================================

  // Declare and initialize local parameters and functions used for HDL generation
  localparam [191:0] P_CHANNEL_ENABLE = 192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000;
  localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(12);
  localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(12);


  // ===================================================================================================================
  // HELPER BLOCKS
  // ===================================================================================================================

  // Any helper blocks which the user chose to exclude from the core will appear below. In addition, some signal
  // assignments related to optionally-enabled ports may appear below.

  // -------------------------------------------------------------------------------------------------------------------
  // Transmitter user clocking network helper block
  // -------------------------------------------------------------------------------------------------------------------

  wire [0:0] txusrclk_int;
  wire [0:0] txusrclk2_int;
  wire [0:0] txoutclk_int;

  // Generate a single module instance which is driven by a clock source associated with the master transmitter channel,
  // and which drives TXUSRCLK and TXUSRCLK2 for all channels

  // The source clock is TXOUTCLK from the master transmitter channel
  assign gtwiz_userclk_tx_srcclk_out = txoutclk_int[P_TX_MASTER_CH_PACKED_IDX];

  // Instantiate a single instance of the transmitter user clocking network helper block
  gth_userclk_tx gtwiz_userclk_tx_inst (
    .gtwiz_userclk_tx_srcclk_in   (gtwiz_userclk_tx_srcclk_out),
    .gtwiz_userclk_tx_reset_in    (gtwiz_userclk_tx_reset_in),
    .gtwiz_userclk_tx_usrclk_out  (gtwiz_userclk_tx_usrclk_out),
    .gtwiz_userclk_tx_usrclk2_out (gtwiz_userclk_tx_usrclk2_out),
    .gtwiz_userclk_tx_active_out  (gtwiz_userclk_tx_active_out)
  );

  // Drive TXUSRCLK and TXUSRCLK2 for all channels with the respective helper block outputs
  assign txusrclk_int  = {1{gtwiz_userclk_tx_usrclk_out}};
  assign txusrclk2_int = {1{gtwiz_userclk_tx_usrclk2_out}};

  // -------------------------------------------------------------------------------------------------------------------
  // Receiver user clocking network helper block
  // -------------------------------------------------------------------------------------------------------------------

  wire [0:0] rxusrclk_int;
  wire [0:0] rxusrclk2_int;
  wire [0:0] rxoutclk_int;

  // Generate a single module instance which is driven by a clock source associated with the master receiver channel,
  // and which drives RXUSRCLK and RXUSRCLK2 for all channels

  // The source clock is RXOUTCLK from the master receiver channel
  assign gtwiz_userclk_rx_srcclk_out = rxoutclk_int[P_RX_MASTER_CH_PACKED_IDX];

  // Instantiate a single instance of the receiver user clocking network helper block
  gth_userclk_rx gtwiz_userclk_rx_inst (
    .gtwiz_userclk_rx_srcclk_in   (gtwiz_userclk_rx_srcclk_out),
    .gtwiz_userclk_rx_reset_in    (gtwiz_userclk_rx_reset_in),
    .gtwiz_userclk_rx_usrclk_out  (gtwiz_userclk_rx_usrclk_out),
    .gtwiz_userclk_rx_usrclk2_out (gtwiz_userclk_rx_usrclk2_out),
    .gtwiz_userclk_rx_active_out  (gtwiz_userclk_rx_active_out)
  );

  // Drive RXUSRCLK and RXUSRCLK2 for all channels with the respective helper block outputs
  assign rxusrclk_int  = {1{gtwiz_userclk_rx_usrclk_out}};
  assign rxusrclk2_int = {1{gtwiz_userclk_rx_usrclk2_out}};
  wire [0:0] gtpowergood_int;

  // Required assignment to expose the GTPOWERGOOD port per user request
  assign gtpowergood_out = gtpowergood_int;

  // ----------------------------------------------------------------------------------------------------------------
  // Assignments to expose data ports, or data control ports, per configuration requirement or user request
  // ----------------------------------------------------------------------------------------------------------------

  wire [15:0] txctrl0_int;

  // Required assignment to expose the TXCTRL0 port per configuration requirement or user request
  assign txctrl0_int = txctrl0_in;
  wire [15:0] txctrl1_int;

  // Required assignment to expose the TXCTRL1 port per configuration requirement or user request
  assign txctrl1_int = txctrl1_in;
  wire [15:0] rxctrl0_int;

  // Required assignment to expose the RXCTRL0 port per configuration requirement or user request
  assign rxctrl0_out = rxctrl0_int;
  wire [15:0] rxctrl1_int;

  // Required assignment to expose the RXCTRL1 port per configuration requirement or user request
  assign rxctrl1_out = rxctrl1_int;


  // ===================================================================================================================
  // CORE INSTANCE
  // ===================================================================================================================
gth_sata gth_sata_inst (
  .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_out),                  // input wire [0 : 0] gtwiz_userclk_tx_active_in
  .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_out),                  // input wire [0 : 0] gtwiz_userclk_rx_active_in
  .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),                  // input wire [0 : 0] gtwiz_reset_clk_freerun_in
  .gtwiz_reset_all_in(gtwiz_reset_all_in),                                  // input wire [0 : 0] gtwiz_reset_all_in
  .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),  // input wire [0 : 0] gtwiz_reset_tx_pll_and_datapath_in
  .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),                  // input wire [0 : 0] gtwiz_reset_tx_datapath_in
  .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),  // input wire [0 : 0] gtwiz_reset_rx_pll_and_datapath_in
  .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),                  // input wire [0 : 0] gtwiz_reset_rx_datapath_in
  .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),            // output wire [0 : 0] gtwiz_reset_rx_cdr_stable_out
  .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),                        // output wire [0 : 0] gtwiz_reset_tx_done_out
  .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),                        // output wire [0 : 0] gtwiz_reset_rx_done_out
  .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),                              // input wire [31 : 0] gtwiz_userdata_tx_in
  .gtwiz_userdata_rx_out(gtwiz_userdata_rx_out),                            // output wire [31 : 0] gtwiz_userdata_rx_out
  .drpclk_in(drpclk_in),                                                    // input wire [0 : 0] drpclk_in
  .gtyrxn_in(gthrxn_in),                                                    // input wire [0 : 0] gthrxn_in
  .gtyrxp_in(gthrxp_in),                                                    // input wire [0 : 0] gthrxp_in
  .gtrefclk0_in(gtrefclk0_in),                                              // input wire [0 : 0] gtrefclk0_in
  .rx8b10ben_in(rx8b10ben_in),                                              // input wire [0 : 0] rx8b10ben_in
  .rxbufreset_in(rxbufreset_in),                                            // input wire [0 : 0] rxbufreset_in
  .rxelecidlemode_in(rxelecidlemode_in),                                    // input wire [1 : 0] rxelecidlemode_in
  .rxoobreset_in(1'b0),                                            // input wire [0 : 0] rxoobreset_in
  .rxusrclk_in(rxusrclk_int),                                                // input wire [0 : 0] rxusrclk_in
  .rxusrclk2_in(rxusrclk2_int),                                              // input wire [0 : 0] rxusrclk2_in
  .tx8b10ben_in(tx8b10ben_in),                                              // input wire [0 : 0] tx8b10ben_in
  .txcominit_in(txcominit_in),                                              // input wire [0 : 0] txcominit_in
  .txcomwake_in(txcomwake_in),                                              // input wire [0 : 0] txcomwake_in
  .txctrl0_in(txctrl0_int),                                                  // input wire [15 : 0] txctrl0_in
  .txctrl1_in(txctrl1_int),                                                  // input wire [15 : 0] txctrl1_in
  .txctrl2_in(txctrl2_in),                                                  // input wire [7 : 0] txctrl2_in
  .txdiffctrl_in(txdiffctrl_in),
  .rxpolarity_in(rxpolarity_in),
  .txpolarity_in(txpolarity_in),
  .txpostcursor_in(txpostcursor_in),
  .txprecursor_in(txprecursor_in),
  .loopback_in(loopback_in),                                                // input wire [2 : 0] loopback_in
  .txusrclk_in(txusrclk_int),                                                // input wire [0 : 0] txusrclk_in
  .txusrclk2_in(txusrclk2_int),                                              // input wire [0 : 0] txusrclk2_in
  .gtytxn_out(gthtxn_out),                                                  // output wire [0 : 0] gthtxn_out
  .gtytxp_out(gthtxp_out),                                                  // output wire [0 : 0] gthtxp_out
  .gtpowergood_out(gtpowergood_int),                                        // output wire [0 : 0] gtpowergood_out
  .rxbufstatus_out(rxbufstatus_out),                                        // output wire [2 : 0] rxbufstatus_out
  .rxbyteisaligned_out(rxbyteisaligned_out),
  .rxclkcorcnt_out(rxclkcorcnt_out),                                        // output wire [1 : 0] rxclkcorcnt_out
  .rxcominitdet_out(rxcominitdet_out),                                      // output wire [0 : 0] rxcominitdet_out
  .rxcomsasdet_out(),                                        // output wire [0 : 0] rxcomsasdet_out
  .rxcomwakedet_out(rxcomwakedet_out),                                      // output wire [0 : 0] rxcomwakedet_out
  .rxctrl0_out(rxctrl0_int),                                                // output wire [15 : 0] rxctrl0_out
  .rxctrl1_out(rxctrl1_int),                                                // output wire [15 : 0] rxctrl1_out
  .rxctrl2_out(rxctrl2_out),                                                // output wire [7 : 0] rxctrl2_out
  .rxctrl3_out(rxctrl3_out),                                                // output wire [7 : 0] rxctrl3_out
  .rxelecidle_out(rxelecidle_out),                                          // output wire [0 : 0] rxelecidle_out
  .rxoutclk_out(rxoutclk_int),                                              // output wire [0 : 0] rxoutclk_out
  .rxpmaresetdone_out(rxpmaresetdone_out),                                  // output wire [0 : 0] rxpmaresetdone_out
  .txcomfinish_out(txcomfinish_out),                                        // output wire [0 : 0] txcomfinish_out
  .txoutclk_out(txoutclk_int),                                              // output wire [0 : 0] txoutclk_out
  .txpmaresetdone_out(txpmaresetdone_out)                                  // output wire [0 : 0] txpmaresetdone_out
);

endmodule

