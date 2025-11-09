/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_transport.sv
Last Update     : 2025/04/06 20:09:04
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/06 20:09:04
Version         : 1.0
Description     : SATA Transport Layer Module - Implements the transport layer of the SATA 
                  protocol stack. This module handles command processing, data streaming, 
                  and interface management between the link layer and user application. It 
                  routes different types of FIS (Frame Information Structure) packets to 
                  appropriate submodules for processing.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Transport Layer Module
// This module implements the transport layer of the SATA protocol stack. The transport layer
// is responsible for:
// 1. Routing incoming FIS packets from the link layer to appropriate processing modules
// 2. Managing command interface between user application and SATA device
// 3. Handling data streaming for read/write operations
// 4. Processing DMA, PIO, and packet-based data transfers
// 5. Generating control signals for DMA and PIO operations
module sata_transport #(
    parameter USER_W = 8               // User data width for AXI Stream interface
)(
    /**** System Interface ****/
    input    logic                     clk                  ,   // Main clock signal
    input    logic                     rst_n                ,   // Active-low reset signal

    /**** Transport Layer Acknowledge ****/
    output   logic  [1          :0]    tl_ack               ,   // Transport layer acknowledge signals

    /**** Link Layer Interface (Slave) ****/
    // AXI Stream interface for receiving data from link layer
    input    logic  [31         :0]    s_aixs_link_tdata    ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_link_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_link_tvalid   ,   // Slave data valid signal
    output   logic                     s_aixs_link_tready   ,   // Slave ready signal

    /**** Link Layer Interface (Master) ****/
    // AXI Stream interface for transmitting data to link layer
    output   logic  [31         :0]    m_aixs_link_tdata    ,   // Master data payload
    output   logic  [USER_W   -1:0]    m_aixs_link_tuser    ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_link_tvalid   ,   // Master data valid signal
    input    logic                     m_aixs_link_tready   ,   // Master ready signal

    /**** Command Interface ****/
    // Interface for command processing between transport layer and user application
    input    cmd_t                     m_cmd                ,   // Master command input (H2D format)
    input    logic                     m_req                ,   // Master command request
    output   logic                     m_ack                ,   // Master command acknowledge

    output   cmd_t                     s_cmd                ,   // Slave command output (D2H format)
    output   logic                     s_req                ,   // Slave command request
    input    logic                     s_ack                ,   // Slave command acknowledge

    /**** DMA Control ****/
    // DMA activation signal for data transfer operations
    output   logic                     dma_active           ,   // DMA active signal output

    /**** PIO Control ****/
    // PIO setup signal for programmed I/O operations
    output   logic                     pio_setup            ,   // PIO setup signal output

    /**** Data Stream Interface ****/
    // AXI Stream interface for data streaming between user application and transport layer
    input    logic  [31         :0]    s_aixs_trans_tdata   ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_trans_tuser   ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_trans_tvalid  ,   // Slave data valid signal
    output   logic                     s_aixs_trans_tready  ,   // Slave ready signal

    output   logic  [31         :0]    m_aixs_trans_tdata   ,   // Master data payload
    output   logic  [USER_W   -1:0]    m_aixs_trans_tuser   ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_trans_tvalid  ,   // Master data valid signal
    input    logic                     m_aixs_trans_tready  ,   // Master ready signal

    /**** Statistics Counters ****/
    // Link layer packet counters
    output   logic  [31         :0]    rx_link_sop_cnt      ,   // Received link start of packet counter
    output   logic  [31         :0]    rx_link_eop_cnt      ,   // Received link end of packet counter
    output   logic  [31         :0]    tx_link_sop_cnt      ,   // Transmitted link start of packet counter
    output   logic  [31         :0]    tx_link_eop_cnt      ,   // Transmitted link end of packet counter

    // Command counters
    output   logic  [31         :0]    rx_cmd_cnt           ,   // Received command counter
    output   logic  [31         :0]    tx_cmd_cnt           ,   // Transmitted command counter

    // Transport layer packet counters
    output   logic  [31         :0]    rx_trans_sop_cnt     ,   // Received transport start of packet counter
    output   logic  [31         :0]    rx_trans_eop_cnt     ,   // Received transport end of packet counter
    output   logic  [31         :0]    tx_trans_sop_cnt     ,   // Transmitted transport start of packet counter
    output   logic  [31         :0]    tx_trans_eop_cnt       // Transmitted transport end of packet counter
);

// Output declarations for submodules
// Wire declarations for command submodule interface
wire                s_aixs_link_cmd_tready    ;   // Command submodule ready signal
wire [31      :0]   m_aixs_link_cmd_tdata     ;   // Command submodule data output
wire [USER_W-1:0]   m_aixs_link_cmd_tuser     ;   // Command submodule user signals output
wire                m_aixs_link_cmd_tvalid    ;   // Command submodule data valid output

// Wire declarations for DMA submodule interface
wire                s_aixs_link_dma_tready    ;   // DMA submodule ready signal

// Wire declarations for packet submodule interface
wire                s_aixs_link_pak_tready    ;   // Packet submodule ready signal
wire [31        :0] m_aixs_link_pak_tdata     ;   // Packet submodule data output
wire [USER_W  -1:0] m_aixs_link_pak_tuser     ;   // Packet submodule user signals output
wire                m_aixs_link_pak_tvalid    ;   // Packet submodule data valid output

// Wire declarations for PIO submodule interface
wire                s_aixs_link_pio_tready    ;   // PIO submodule ready signal

// Internal signal declarations
logic               s_aixs_cmdlink_tvalid     ;   // Command link valid signal
logic               s_aixs_paklink_tvalid     ;   // Packet link valid signal

// Transport layer acknowledge signal assignment
assign tl_ack = 2'b01;

// Generate block for slave axis link interface
// This block handles routing of incoming FIS packets to appropriate submodules
// based on the FIS type detected in the packet header
generate begin:S_AXIS_LINK
    logic [4      -1:0] r_mode_sel       ;   // Registered mode selection based on FIS type

    // Mode selection logic based on FIS type
    // Detects the FIS type from the packet header and routes to appropriate submodule
    always_ff @(posedge clk or negedge rst_n)begin
        if(!rst_n)
            r_mode_sel <= 'd0;  // Reset mode selection
        else if(s_aixs_link_tuser[1]) case(s_aixs_link_tdata[24+:8])  // At SOP, check FIS type
            8'h34:r_mode_sel <= 4'b0001;  // FIS type 0x34 - Host to Device command
            8'h39:r_mode_sel <= 4'b0010;  // FIS type 0x39 - DMA Setup
            8'h41:r_mode_sel <= 4'b0010;  // FIS type 0x41 - DMA Activate
            8'h5F:r_mode_sel <= 4'b0100;  // FIS type 0x5F - PIO Setup
            8'h46:r_mode_sel <= 4'b1000;  // FIS type 0x46 - Data FIS
            default:r_mode_sel <= 4'b0000; // Unknown FIS type
        endcase
        // Clear mode selection at end of packet
        else if(s_aixs_link_tuser[0] && s_aixs_link_tvalid && s_aixs_link_tready)begin
            r_mode_sel <= 'd0;
        end
    end
    
    // FIS routing logic - directs incoming packets to appropriate submodules
    // based on FIS type and current mode selection
    always_comb begin
        if(s_aixs_link_tuser[1])case(s_aixs_link_tdata[24+:8])  // At SOP, check FIS type
            8'h34:begin 
                s_aixs_link_tready = s_aixs_link_cmd_tready;  // Route to command submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = s_aixs_link_tvalid;   // Enable command link
            end
            8'h39:begin 
                s_aixs_link_tready = s_aixs_link_dma_tready;  // Route to DMA submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
            8'h41:begin 
                s_aixs_link_tready = s_aixs_link_dma_tready;  // Route to DMA submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
            8'h5F:begin 
                s_aixs_link_tready = s_aixs_link_pio_tready;  // Route to PIO submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
            8'h46:begin 
                s_aixs_link_tready = s_aixs_link_pak_tready;  // Route to packet submodule
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
                s_aixs_paklink_tvalid = s_aixs_link_tvalid;   // Enable packet link
            end
            default:begin 
                s_aixs_link_tready = 1'b1;                    // Default ready
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
            end
        endcase
        else case(r_mode_sel)  // For continuation packets, use registered mode
            4'b0001:begin 
                s_aixs_link_tready = s_aixs_link_cmd_tready;  // Route to command submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = s_aixs_link_tvalid;   // Enable command link
            end
            4'b0010:begin 
                s_aixs_link_tready = s_aixs_link_dma_tready;  // Route to DMA submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
            4'b0100:begin 
                s_aixs_link_tready = s_aixs_link_pio_tready;  // Route to PIO submodule
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
            4'b1000:begin 
                s_aixs_link_tready = s_aixs_link_pak_tready;  // Route to packet submodule
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
                s_aixs_paklink_tvalid = s_aixs_link_tvalid;   // Enable packet link
            end
            default:begin 
                s_aixs_link_tready = 1'b1;                    // Default ready
                s_aixs_paklink_tvalid = 1'b0;                 // Disable packet link
                s_aixs_cmdlink_tvalid = 1'b0;                 // Disable command link
            end
        endcase
    end
end endgenerate

// Master axis link interface
// Multiplexes output from command and packet submodules to the link layer
always_comb begin:M_AXIS_LINK
    case({m_aixs_link_cmd_tvalid,m_aixs_link_pak_tvalid})  // Select based on submodule valid signals
        2'b01:begin  // Packet data valid
            m_aixs_link_tdata  = m_aixs_link_pak_tdata ;   // Output packet data
            m_aixs_link_tuser  = m_aixs_link_pak_tuser ;   // Output packet user signals
            m_aixs_link_tvalid = m_aixs_link_pak_tvalid;   // Output packet valid
        end
        2'b10:begin  // Command data valid
            m_aixs_link_tdata  = m_aixs_link_cmd_tdata ;   // Output command data
            m_aixs_link_tuser  = m_aixs_link_cmd_tuser ;   // Output command user signals
            m_aixs_link_tvalid = m_aixs_link_cmd_tvalid;   // Output command valid
        end
        default:begin  // No data valid
            m_aixs_link_tdata  = 'd0;                      // Zero data
            m_aixs_link_tuser  = 'd0;                      // Zero user signals
            m_aixs_link_tvalid = 'd0;                      // Not valid
        end
    endcase
end

// Instantiate SATA transport command submodule
// Handles Host to Device (H2D) and Device to Host (D2H) command FIS processing
sata_transport_command #(
    .USER_W   	(USER_W  )                                  // User data width parameter
)
u_sata_transport_command(
    .clk                	(clk                    ),         // Clock signal
    .rst_n              	(rst_n                  ),         // Reset signal
    .s_aixs_link_tdata  	(s_aixs_link_tdata      ),         // Link data input
    .s_aixs_link_tuser  	(s_aixs_link_tuser      ),         // Link user signals input
    .s_aixs_link_tvalid 	(s_aixs_cmdlink_tvalid  ),         // Link valid input (command path)
    .s_aixs_link_tready 	(s_aixs_link_cmd_tready ),         // Link ready output (command path)
    .m_aixs_link_tdata  	(m_aixs_link_cmd_tdata  ),         // Link data output (command path)
    .m_aixs_link_tuser  	(m_aixs_link_cmd_tuser  ),         // Link user signals output (command path)
    .m_aixs_link_tvalid 	(m_aixs_link_cmd_tvalid ),         // Link valid output (command path)
    .m_aixs_link_tready 	(m_aixs_link_tready     ),         // Link ready input
    .m_cmd              	(m_cmd                  ),         // Master command input
    .m_req              	(m_req                  ),         // Master request input
    .m_ack              	(m_ack                  ),         // Master acknowledge output
    .s_cmd              	(s_cmd                  ),         // Slave command output
    .s_req              	(s_req                  ),         // Slave request output
    .s_ack              	(s_ack                  )          // Slave acknowledge input
);

// Instantiate SATA transport DMA submodule
// Detects DMA setup/activate FIS and generates DMA active signal
sata_transport_dma #(
    .USER_W 	(USER_W  )                                   // User data width parameter
)
u_sata_transport_dma(
    .clk                	(clk                    ),          // Clock signal
    .rst_n              	(rst_n                  ),          // Reset signal
    .s_aixs_link_tdata  	(s_aixs_link_tdata      ),          // Link data input
    .s_aixs_link_tuser  	(s_aixs_link_tuser      ),          // Link user signals input
    .s_aixs_link_tvalid 	(s_aixs_link_tvalid     ),          // Link valid input
    .s_aixs_link_tready 	(s_aixs_link_dma_tready ),          // Link ready output (DMA path)
    .dma_active         	(dma_active             )           // DMA active output signal
);

// Instantiate SATA transport packet submodule
// Handles data FIS processing for read/write data transfers
sata_transport_packet #(
    .USER_W    	(USER_W  )                                    // User data width parameter
)
u_sata_transport_packet(
    .clk                 	(clk                    ),          // Clock signal
    .rst_n               	(rst_n                  ),          // Reset signal
    .s_aixs_link_tdata   	(s_aixs_link_tdata      ),          // Link data input
    .s_aixs_link_tuser   	(s_aixs_link_tuser      ),          // Link user signals input
    .s_aixs_link_tvalid  	(s_aixs_paklink_tvalid  ),          // Link valid input (packet path)
    .s_aixs_link_tready  	(s_aixs_link_pak_tready ),          // Link ready output (packet path)
    .m_aixs_link_tdata   	(m_aixs_link_pak_tdata  ),          // Link data output (packet path)
    .m_aixs_link_tuser   	(m_aixs_link_pak_tuser  ),          // Link user signals output (packet path)
    .m_aixs_link_tvalid  	(m_aixs_link_pak_tvalid ),          // Link valid output (packet path)
    .m_aixs_link_tready  	(m_aixs_link_tready     ),          // Link ready input
    .s_aixs_trans_tdata  	(s_aixs_trans_tdata     ),          // Transaction data input
    .s_aixs_trans_tuser  	(s_aixs_trans_tuser     ),          // Transaction user signals input
    .s_aixs_trans_tvalid 	(s_aixs_trans_tvalid    ),          // Transaction valid input
    .s_aixs_trans_tready 	(s_aixs_trans_tready    ),          // Transaction ready output
    .m_aixs_trans_tdata  	(m_aixs_trans_tdata     ),          // Transaction data output
    .m_aixs_trans_tuser  	(m_aixs_trans_tuser     ),          // Transaction user signals output
    .m_aixs_trans_tvalid 	(m_aixs_trans_tvalid    ),          // Transaction valid output
    .m_aixs_trans_tready 	(m_aixs_trans_tready    )           // Transaction ready input
);

// Instantiate SATA transport PIO submodule
// Detects PIO setup FIS and generates PIO setup signal
sata_transport_pio #(
    .USER_W 	(USER_W  )                                     // User data width parameter
)
u_sata_transport_pio(
    .clk                	(clk                        ),       // Clock signal
    .rst_n              	(rst_n                      ),       // Reset signal
    .s_aixs_link_tdata  	(s_aixs_link_tdata          ),       // Link data input
    .s_aixs_link_tuser  	(s_aixs_link_tuser          ),       // Link user signals input
    .s_aixs_link_tvalid 	(s_aixs_link_tvalid         ),       // Link valid input
    .s_aixs_link_tready 	(s_aixs_link_pio_tready     ),       // Link ready output (PIO path)
    .pio_setup          	(pio_setup                  )        // PIO setup output signal
);

// Received link start of packet counter
// Counts the number of start of packet occurrences on the link interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_link_sop_cnt <= 'd0;                                 // Reset counter
    else if(s_aixs_link_tvalid && s_aixs_link_tready && s_aixs_link_tuser[1])
        rx_link_sop_cnt <= rx_link_sop_cnt + 1'b1;              // Increment on SOP
end

// Received link end of packet counter
// Counts the number of end of packet occurrences on the link interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_link_eop_cnt <= 'd0;                                 // Reset counter
    else if(s_aixs_link_tvalid && s_aixs_link_tready && s_aixs_link_tuser[0])
        rx_link_eop_cnt <= rx_link_eop_cnt + 1'b1;              // Increment on EOP
end

// Transmitted link start of packet counter
// Counts the number of start of packet occurrences on the link interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_link_sop_cnt <= 'd0;                                 // Reset counter
    else if(m_aixs_link_tvalid && m_aixs_link_tready && m_aixs_link_tuser[1])
        tx_link_sop_cnt <= tx_link_sop_cnt + 1'b1;              // Increment on SOP
end

// Transmitted link end of packet counter
// Counts the number of end of packet occurrences on the link interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_link_eop_cnt <= 'd0;                                 // Reset counter
    else if(m_aixs_link_tvalid && m_aixs_link_tready && m_aixs_link_tuser[0])
        tx_link_eop_cnt <= tx_link_eop_cnt + 1'b1;              // Increment on EOP
end

// Received command counter
// Counts the number of commands received from the user application
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_cmd_cnt <= 'd0;                                      // Reset counter
    else if(m_req && m_ack)
        rx_cmd_cnt <= rx_cmd_cnt + 1'b1;                        // Increment on command acknowledge
end

// Transmitted command counter
// Counts the number of commands transmitted to the user application
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_cmd_cnt <= 'd0;                                      // Reset counter
    else if(s_req && s_ack)
        tx_cmd_cnt <= tx_cmd_cnt + 1'b1;                        // Increment on command acknowledge
end

// Received transport start of packet counter
// Counts the number of start of packet occurrences on the transport interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_trans_sop_cnt <= 'd0;                                // Reset counter
    else if(s_aixs_trans_tvalid && s_aixs_trans_tready && s_aixs_trans_tuser[1])
        rx_trans_sop_cnt <= rx_trans_sop_cnt + 1'b1;            // Increment on SOP
end

// Received transport end of packet counter
// Counts the number of end of packet occurrences on the transport interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rx_trans_eop_cnt <= 'd0;                                // Reset counter
    else if(s_aixs_trans_tvalid && s_aixs_trans_tready && s_aixs_trans_tuser[0])
        rx_trans_eop_cnt <= rx_trans_eop_cnt + 1'b1;            // Increment on EOP
end

// Transmitted transport start of packet counter
// Counts the number of start of packet occurrences on the transport interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_trans_sop_cnt <= 'd0;                                // Reset counter
    else if(m_aixs_trans_tvalid && m_aixs_trans_tready && m_aixs_trans_tuser[1])
        tx_trans_sop_cnt <= tx_trans_sop_cnt + 1'b1;            // Increment on SOP
end

// Transmitted transport end of packet counter
// Counts the number of end of packet occurrences on the transport interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_trans_eop_cnt <= 'd0;                                // Reset counter
    else if(m_aixs_trans_tvalid && m_aixs_trans_tready && m_aixs_trans_tuser[0])
        tx_trans_eop_cnt <= tx_trans_eop_cnt + 1'b1;            // Increment on EOP
end

endmodule