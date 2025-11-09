`include "sata_wrapper_define.svh"
module tb_top_transport_dma;

parameter USER_W = 8;

logic                    clk                   ;
logic                    rst_n                 ;

// output declaration of module sata_transport
logic  [31         :0]    s_aixs_link_tdata    ;
logic  [4        -1:0]    s_aixs_link_tkeep    ;
logic  [USER_W-4 -1:0]    s_aixs_link_tuser    ;//{drop,err,sop,eop}
logic                     s_aixs_link_tvalid   ;
logic                     s_aixs_link_tready   ;

logic  [31         :0]    m_aixs_link_tdata    ;
logic  [USER_W   -1:0]    m_aixs_link_tuser    ;//{drop,err,keep[3:0],sop,eop}
logic                     m_aixs_link_tvalid   ;
logic                     m_aixs_link_tready   ;

logic  [73       -1:0]    cmd_tdata            ;//{vld,RW,len[22:0],addr[47:0]}
logic                     cmd_ack              ;
logic  [2        -1:0]    ctrl                 ;

logic  [31         :0]    s_aixs_cmd_tdata     ;
logic  [4        -1:0]    s_aixs_cmd_tkeep     ;
logic  [USER_W-4 -1:0]    s_aixs_cmd_tuser     ;//{drop,err,keep[3:0],sop,eop}
logic                     s_aixs_cmd_tvalid    ;
logic                     s_aixs_cmd_tready    ;

logic  [31         :0]    m_aixs_cmd_tdata     ;
logic  [USER_W   -1:0]    m_aixs_cmd_tuser     ;//{drop,err,keep[3:0],sop,eop}
logic                     m_aixs_cmd_tvalid    ;
logic                     m_aixs_cmd_tready    ;

//internal connection

cmd_t                       s_cmd               ;
logic                       s_req               ;
logic                       s_ack               ;
cmd_t                       m_cmd               ;
logic                       m_req               ;
logic                       m_ack               ;

logic                       dma_active          ;
logic                       pio_setup           ;

logic  [31         :0]      s_aixs_trans_tdata  ;
logic  [USER_W   -1:0]      s_aixs_trans_tuser  ;//{drop,err,keep[3:0],sop,eop}
logic                       s_aixs_trans_tvalid ;
logic                       s_aixs_trans_tready ;

logic  [31         :0]      m_aixs_trans_tdata  ;
logic  [USER_W   -1:0]      m_aixs_trans_tuser  ;//{drop,err,keep[3:0],sop,eop}
logic                       m_aixs_trans_tvalid ;
logic                       m_aixs_trans_tready ;

logic  [USER_W   -1:0]      s_aixs_comb_link_tuser;
logic  [USER_W   -1:0]      s_aixs_comb_cmd_tuser ;

logic  [16       -1:0]      read_count           ;

assign s_aixs_comb_link_tuser = {s_aixs_link_tuser[3:2],s_aixs_link_tkeep,s_aixs_link_tuser[1:0]};
assign s_aixs_comb_cmd_tuser  = {s_aixs_cmd_tuser[3:2] ,s_aixs_cmd_tkeep ,s_aixs_cmd_tuser [1:0]};

// initial begin
//     rst_n = 1;
//     #1
//     rst_n = 0;
//     repeat(10) @(posedge clk);
//     rst_n = 1;
// end



sata_transport #(
    .USER_W 	(USER_W  )
)
u_sata_transport(
    .clk                 	(clk                    ),
    .rst_n               	(rst_n                  ),
    .s_aixs_link_tdata   	(s_aixs_link_tdata      ),
    .s_aixs_link_tuser   	(s_aixs_comb_link_tuser ),
    .s_aixs_link_tvalid  	(s_aixs_link_tvalid     ),
    .s_aixs_link_tready  	(s_aixs_link_tready     ),
    .m_aixs_link_tdata   	(m_aixs_link_tdata      ),
    .m_aixs_link_tuser   	(m_aixs_link_tuser      ),
    .m_aixs_link_tvalid  	(m_aixs_link_tvalid     ),
    .m_aixs_link_tready  	(m_aixs_link_tready     ),
    
    .m_cmd               	(m_cmd                  ),
    .m_req               	(m_req                  ),
    .m_ack               	(m_ack                  ),
    .s_cmd               	(s_cmd                  ),
    .s_req               	(s_req                  ),
    .s_ack               	(s_ack                  ),

    .dma_active          	(dma_active             ),
    .pio_setup           	(pio_setup              ),

    .s_aixs_trans_tdata  	(s_aixs_trans_tdata   ),
    .s_aixs_trans_tuser  	(s_aixs_trans_tuser   ),
    .s_aixs_trans_tvalid 	(s_aixs_trans_tvalid  ),
    .s_aixs_trans_tready 	(s_aixs_trans_tready  ),
    .m_aixs_trans_tdata  	(m_aixs_trans_tdata   ),
    .m_aixs_trans_tuser  	(m_aixs_trans_tuser   ),
    .m_aixs_trans_tvalid 	(m_aixs_trans_tvalid  ),
    .m_aixs_trans_tready 	(m_aixs_trans_tready  )
);

sata_command_dma_ctrl #(
    .NULL   	(0      ),
    .USER_W 	(USER_W )
)
u_sata_command_dma_ctrl(
    .clk                 	(clk                  ),
    .rst_n               	(rst_n                ),
    .ctrl                	(ctrl                 ),
    .s_aixs_trans_tdata  	(m_aixs_trans_tdata   ),
    .s_aixs_trans_tuser  	(m_aixs_trans_tuser   ),
    .s_aixs_trans_tvalid 	(m_aixs_trans_tvalid  ),
    .s_aixs_trans_tready 	(m_aixs_trans_tready  ),
    .m_aixs_trans_tdata  	(s_aixs_trans_tdata   ),
    .m_aixs_trans_tuser  	(s_aixs_trans_tuser   ),
    .m_aixs_trans_tvalid 	(s_aixs_trans_tvalid  ),
    .m_aixs_trans_tready 	(s_aixs_trans_tready  ),
    .cmd                	(cmd_tdata            ),
    .cmd_ack             	(cmd_ack              ),
    .read_count             (read_count           ),
    .s_aixs_cmd_tdata    	(s_aixs_cmd_tdata     ),
    .s_aixs_cmd_tuser    	(s_aixs_comb_cmd_tuser),
    .s_aixs_cmd_tvalid   	(s_aixs_cmd_tvalid    ),
    .s_aixs_cmd_tready   	(s_aixs_cmd_tready    ),
    .m_aixs_cmd_tdata    	(m_aixs_cmd_tdata     ),
    .m_aixs_cmd_tuser    	(m_aixs_cmd_tuser     ),
    .m_aixs_cmd_tvalid   	(m_aixs_cmd_tvalid    ),
    .m_aixs_cmd_tready   	(m_aixs_cmd_tready    ),
    .m_cmd               	(m_cmd                ),
    .m_req               	(m_req                ),
    .m_ack               	(m_ack                ),
    .s_cmd               	(s_cmd                ),
    .s_req               	(s_req                ),
    .s_ack               	(s_ack                ),
    .dma_active          	(dma_active           ),
    .pio_setup           	(pio_setup            )
);

initial begin
    $fsdbDumpfile("tb_top_transport_dma.fsdb");
    $fsdbDumpvars(0, tb_top_transport_dma,"+all");
end

endmodule