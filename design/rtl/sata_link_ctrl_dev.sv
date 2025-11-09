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
Description     : var.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

module sata_link_ctrl_dev #(
    parameter USER_W = 8
)
(
    input    logic                     clk             ,
    input    logic                     rst_n           ,

    /***** phy layer *****/
    output   logic  [31         :0]    dat_o           ,
    output   logic  [3          :0]    datchar_o       ,
    output   logic                     hreset          ,
    input    logic                     phyrdy          ,
    output   logic                     slumber         ,
    output   logic                     partial         ,
    output   logic                     nearafelb       ,
    output   logic                     farafelb        ,
    output   logic                     spdsedl         ,
    input    logic                     spdmode         ,
    input    logic                     device_detect   ,
    input    logic                     phy_internal_err,
    input    logic  [31         :0]    dat_i           ,
    input    logic  [3          :0]    datchar_i       ,
    input    logic                     rxclock         ,
    input    logic                     cominit         ,
    input    logic                     comwake         ,
    input    logic                     comma           ,

    /***** trans layer *****/
    input    logic                     tl_ok           ,
    input    logic                     tl_err          ,

    input    logic  [31         :0]    s_aixs_tdata    ,
    input    logic  [USER_W   -1:0]    s_aixs_tuser    ,//{drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_tvalid   ,
    output   logic                     s_aixs_tready   ,

    output   logic  [31         :0]    m_aixs_tdata    ,
    output   logic  [USER_W   -1:0]    m_aixs_tuser    ,//{drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_tvalid   ,
    input    logic                     m_aixs_tready    
);

// output declaration of module sata_link_decode
sata_p_t                          dec_dat_type            ;
logic       [32         -1:0]     dec_dat_o               ;
logic       [4          -1:0]     dec_char_o              ;

// output declaration of module sata_link_encode
logic                             roll_insert             ;

// output declaration of module sata_link_arbt
logic                             wr_req                  ;
logic                             rd_req                  ;

// output declaration of module sata_link_wrmod
logic                             wr_cpl                  ;
logic                             wr_no_busy              ;
sata_p_t                          w_tx_dat_type           ;
logic       [32         -1:0]     w_tx_dat                ;
logic       [4          -1:0]     w_tx_char               ;

// output declaration of module sata_link_rdmod
logic                             rd_cpl                  ;
logic                             rd_no_busy              ;
sata_p_t                          r_tx_dat_type           ;
logic       [32         -1:0]     r_tx_dat                ;
logic       [4          -1:0]     r_tx_char               ;

// output declaration of module sata_link_ingress
logic       [32         -1:0]     ingress_m_aixs_tdata    ;
logic       [USER_W     -1:0]     ingress_m_aixs_tuser    ;//{drop,err,keep[3:0],sop,eop}
logic                             ingress_m_aixs_tvalid   ;
logic                             ingress_m_aixs_tready   ;

// output declaration of module sata_link_egress
logic                             buffer_full             ;
logic       [32         -1:0]     egress_s_aixs_tdata     ;
logic       [USER_W     -1:0]     egress_s_aixs_tuser     ;//{drop,err,keep[3:0],sop,eop}
logic                             egress_s_aixs_tvalid    ;
logic                             egress_s_aixs_tready    ;

sata_link_decode u_sata_link_decode(
    .clk        	(clk            ),
    .rst_n      	(rst_n          ),
    .vld        	(phyrdy         ),
    .dat_i      	(dat_i          ),
    .datachar_i 	(datchar_i      ),
    .dat_type   	(dec_dat_type   ),
    .char_o         (dec_char_o     ),
    .dat_o      	(dec_dat_o      )
);

sata_link_arbt_dev u_sata_link_arbt(
    .clk         	(clk          ),
    .rst_n       	(rst_n        ),
    .rx_req         (s_aixs_tvalid),
    .roll_insert    (roll_insert  ),
    .rx_dat_type 	(dec_dat_type ),
    .phyrdy      	(phyrdy       ),
    .wr_req      	(wr_req       ),
    .wr_cpl      	(wr_cpl       ),
    .wr_no_busy     (wr_no_busy   ),
    .rd_req      	(rd_req       ),
    .rd_cpl      	(rd_cpl       ),
    .rd_no_busy     (rd_no_busy   )
);

sata_link_wrmod_dev #(
    .USER_W 	(USER_W  )
)
u_sata_link_wrmod(
    .clk           	(clk                    ),
    .rst_n         	(rst_n                  ),
    .phyrdy        	(phyrdy                 ),
    .wr_req        	(wr_req                 ),
    .wr_cpl        	(wr_cpl                 ),
    .wr_no_busy     (wr_no_busy             ),
    .roll_insert   	(roll_insert            ),
    .s_aixs_tdata  	(ingress_m_aixs_tdata   ),
    .s_aixs_tuser  	(ingress_m_aixs_tuser   ),
    .s_aixs_tvalid 	(ingress_m_aixs_tvalid  ),
    .s_aixs_tready 	(ingress_m_aixs_tready  ),
    .rx_dat_type   	(dec_dat_type           ),
    .rx_dat        	(dec_dat_o              ),
    .rx_char       	(dec_char_o             ),
    .tx_dat_type   	(w_tx_dat_type          ),
    .tx_dat        	(w_tx_dat               ),
    .tx_char       	(w_tx_char              )
);

sata_link_rdmod #(
    .USER_W 	(USER_W  )
)
u_sata_link_rdmod(
    .clk           	(clk                   ),
    .rst_n         	(rst_n                 ),
    .phyrdy        	(phyrdy                ),
    .rd_req        	(rd_req                ),
    .rd_cpl        	(rd_cpl                ),
    .rd_no_busy     (rd_no_busy            ),
    .roll_insert   	(roll_insert           ),
    .m_aixs_tdata  	(egress_s_aixs_tdata   ),
    .m_aixs_tuser  	(egress_s_aixs_tuser   ),
    .m_aixs_tvalid 	(egress_s_aixs_tvalid  ),
    .m_aixs_tready 	(egress_s_aixs_tready  ),
    .buffer_full   	(buffer_full           ),
    .tl_ok         	(tl_ok                 ),
    .tl_err        	(tl_err                ),
    .rx_dat_type   	(dec_dat_type          ),
    .rx_dat        	(dec_dat_o             ),
    .rx_char       	(dec_char_o            ),
    .tx_dat_type   	(r_tx_dat_type         ),
    .tx_dat        	(r_tx_dat              ),
    .tx_char       	(r_tx_char             )
);

sata_link_encode u_sata_link_encode(
    .clk         	(clk          ),
    .rst_n       	(rst_n        ),
    .phyrdy         (phyrdy       ),
    .vld         	(             ),
    .roll_insert    (roll_insert  ),
    .dat_o       	(dat_o        ),
    .datachar_o  	(datchar_o    ),
    .wr_req      	(wr_req       ),
    .wr_dat_type 	(w_tx_dat_type),
    .wr_char_i   	(w_tx_char    ),
    .wr_dat_i    	(w_tx_dat     ),
    .rd_req      	(rd_req       ),
    .rd_dat_type 	(r_tx_dat_type),
    .rd_char_i   	(r_tx_char    ),
    .rd_dat_i    	(r_tx_dat     )
);

sata_link_ingress #(
    .USER_W    	(USER_W  ),
    .NO_BUFFER 	(1       ) 
)
u_sata_link_ingress(
    .clk           	(clk                    ),
    .rst_n         	(rst_n                  ),
    .s_aixs_tdata  	(s_aixs_tdata           ),
    .s_aixs_tuser  	(s_aixs_tuser           ),
    .s_aixs_tvalid 	(s_aixs_tvalid          ),
    .s_aixs_tready 	(s_aixs_tready          ),
    .m_aixs_tdata  	(ingress_m_aixs_tdata   ),
    .m_aixs_tuser  	(ingress_m_aixs_tuser   ),
    .m_aixs_tvalid 	(ingress_m_aixs_tvalid  ),
    .m_aixs_tready 	(ingress_m_aixs_tready  )
);


sata_link_egress #(
    .USER_W  	(USER_W  )
)
u_sata_link_egress(
    .clk           	(clk                    ),
    .rst_n         	(rst_n                  ),
    .s_aixs_tdata  	(egress_s_aixs_tdata    ),
    .s_aixs_tuser  	(egress_s_aixs_tuser    ),
    .s_aixs_tvalid 	(egress_s_aixs_tvalid   ),
    .s_aixs_tready 	(egress_s_aixs_tready   ),
    .m_aixs_tdata  	(m_aixs_tdata           ),
    .m_aixs_tuser  	(m_aixs_tuser           ),
    .m_aixs_tvalid 	(m_aixs_tvalid          ),
    .m_aixs_tready 	(m_aixs_tready          ),
    .buffer_full   	(buffer_full            )
);


endmodule
