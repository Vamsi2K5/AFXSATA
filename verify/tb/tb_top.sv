`timescale 1ns/1ns

`include "top_define.svh"

module tb_top;

logic                   clk              ;
logic                   rst_n            ;
// output declaration of module sata_link_ctrl
logic   [31     :0]     host_dat_o       ;
logic   [3      :0]     host_datchar_o   ;
logic   [31     :0]     host_dat_i       ;
logic   [3      :0]     host_datchar_i   ;

logic   [31     :0]     device_dat_o     ;
logic   [3      :0]     device_datchar_o ;
logic   [31     :0]     device_dat_i     ;
logic   [3      :0]     device_datchar_i ;

logic                   host_hreset      ;
logic                   host_slumber     ;
logic                   host_partial     ;
logic                   host_nearafelb   ;
logic                   host_farafelb    ;
logic                   host_spdsedl     ;

logic                   device_hreset    ;
logic                   device_slumber   ;
logic                   device_partial   ;
logic                   device_nearafelb ;
logic                   device_farafelb  ;
logic                   device_spdsedl   ;


logic    [31    :0]     s_axis_tdata     ;
logic    [7     :0]     s_axis_tuser     ;
logic                   s_axis_tvalid    ;
logic                   s_axis_tready    ;

logic    [31    :0]     s_dev_axis_tdata     ;
logic    [7     :0]     s_dev_axis_tuser     ;
logic                   s_dev_axis_tvalid    ;
logic                   s_dev_axis_tready    ;

logic    [31    :0]     m_axis_tdata     ;
logic    [7     :0]     m_axis_tuser     ;
logic                   m_axis_tvalid    ;
logic                   m_axis_tready    ;

logic    [31    :0]     m_host_axis_tdata     ;
logic    [7     :0]     m_host_axis_tuser     ;
logic                   m_host_axis_tvalid    ;
logic                   m_host_axis_tready    ;


logic                   host_tl_ok       ;
logic                   host_tl_err      ;

logic                   device_tl_ok     ;
logic                   device_tl_err    ;

assign host_tl_ok   = 1'b1;
assign host_tl_err  = 1'b0;
assign device_tl_ok = 1'b1;
assign device_tl_err = 1'b0;

sata_link_ctrl u_sata_link_ctrl_host(
    .clk              	(clk               ),
    .rst_n            	(rst_n             ),
    .dat_o            	(host_dat_o        ),
    .datchar_o        	(host_datchar_o    ),
    .hreset           	(host_hreset       ),
    .phyrdy           	(1'b1              ),
    .slumber          	(                  ),
    .partial          	(                  ),
    .nearafelb        	(                  ),
    .farafelb         	(                  ),
    .spdsedl          	(                  ),
    .spdmode          	(1'b0              ),
    .device_detect    	(1'b1              ),
    .phy_internal_err 	(1'b0              ),
    .dat_i            	(host_dat_i        ),
    .datchar_i        	(host_datchar_i    ),
    .rxclock          	(1'b0              ),
    .cominit          	(1'b0              ),
    .comwake          	(1'b0              ),
    .comma            	('d0               ),
    .tl_ok            	(host_tl_ok        ),
    .tl_err           	(host_tl_err       ),
    .s_aixs_tdata     	(s_axis_tdata      ),
    .s_aixs_tuser     	(s_axis_tuser      ),
    .s_aixs_tvalid    	(s_axis_tvalid     ),
    .s_aixs_tready    	(s_axis_tready     ),
    .m_aixs_tdata     	(m_host_axis_tdata ),
    .m_aixs_tuser     	(m_host_axis_tuser ),
    .m_aixs_tvalid    	(m_host_axis_tvalid),
    .m_aixs_tready    	(m_host_axis_tready)
);


sata_link_ctrl_dev u_sata_link_ctrl_device(
    .clk              	(clk               ),
    .rst_n            	(rst_n             ),
    .dat_o            	(device_dat_o      ),
    .datchar_o        	(device_datchar_o  ),
    .hreset           	(device_hreset     ),
    .phyrdy           	(1'b1              ),
    .slumber          	(                  ),
    .partial          	(                  ),
    .nearafelb        	(                  ),
    .farafelb         	(                  ),
    .spdsedl          	(                  ),
    .spdmode          	(1'b0              ),
    .device_detect    	(1'b1              ),
    .phy_internal_err 	(1'b0              ),
    .dat_i            	(device_dat_i      ),
    .datchar_i        	(device_datchar_i  ),
    .rxclock          	(1'b0              ),
    .cominit          	(1'b0              ),
    .comwake          	(1'b0              ),
    .comma            	('d0             ),
    .tl_ok            	(device_tl_ok      ),
    .tl_err           	(device_tl_err     ),
    .s_aixs_tdata     	(s_dev_axis_tdata ),
    .s_aixs_tuser     	(s_dev_axis_tuser ),
    .s_aixs_tvalid    	(s_dev_axis_tvalid),
    .s_aixs_tready    	(s_dev_axis_tready),
    .m_aixs_tdata     	(m_axis_tdata      ),
    .m_aixs_tuser     	(m_axis_tuser      ),
    .m_aixs_tvalid    	(m_axis_tvalid     ),
    .m_aixs_tready    	(m_axis_tready     )
);

assign host_dat_i       = device_dat_o    ;
assign host_datchar_i   = device_datchar_o;

assign device_dat_i     = host_dat_o    ;
assign device_datchar_i = host_datchar_o;


`ifdef WAVES
    initial begin
        $fsdbDumpfile("tb_top.fsdb");
        $fsdbDumpvars(0, tb_top,"+all");
    end
`endif

endmodule