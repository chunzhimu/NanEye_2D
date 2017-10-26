`timescale 1ns/1ns
module deserialize_top(
	input wire CLK,
	input wire RESET,						//module reset key(0)
	input wire ENABLE,				  // module activation switch(0)
	input wire CONFIG_DONE,         // end of config phase (async)key(3)
	input wire RSYNC,               //resynchronize decoder
	output reg SYNC_START,          //start of synchronisation phase
	output reg CONFIG_EN,           //start of config phase
	output reg FRAME_START,         //start of frame
	output reg ERROR_OUT,                 //decoder error
   //output wire [31:0] DEBUG_OUT,          //debug outputs
	
	/////////VGA/////////
	output wire[7:0] VGA_B,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_R,
	
	output wire VGA_BLANK_N,
	output wire VGA_SYNC_N,
	
	output wire VGA_HS,
	output wire VGA_VS,
	
	output wire VGA_CLK,
	
	
	output wire test,
	//output wire led0,
	//output wire   OUTPUT,                  //-- decoded data
	//output wire  OUTPUT_EN,                //-- output data valid
	input wire SENSOR_DATA
);


/*----------------######--CLOCK---########----------------
--generate sample clock 200MHz
--------------------------------------------------------*/
wire SCLOCK;
wire DCLOCK;
	
pll_clk	pll_clk_inst (
	.inclk0 ( CLK ),
	.c0 ( SCLOCK ),
	.c1 ( DCLOCK ),
	.locked ( locked_sig )
	);
	

	
/*----------------------------------------------------------
----------test
----------------------------------------------------------*/
wire CON_ZERO,S_DATA,S_WREN,frame_sync_start;

//OVERSAMPLE P1(
Sample_1 P1(
	.SCLOCK(SCLOCK),
	.RESET(RESET),
	.SENSOR_DATA(SENSOR_DATA),
	

	.frame_sync_start(frame_sync_start),
	.S_DATA(S_DATA),
	.S_WREN(S_WREN)
);


wire   OUTPUT;                  //-- decoded data
wire  OUTPUT_EN;                //-- output data valid
wire PAR_DATA_EN;
wire[7:0] PAR_DATA,q;
wire[7:0] ROW_NUM;
wire[7:0] COL_NUM;
	
wire q_rden,RD_EN;

RX_DESERIALIZER deserializer(
	.SCLOCK(SCLOCK),
	.RESET(RESET),		 
	.FRAME_SYNC_START(frame_sync_start),
	.SER_INPUT(S_DATA),                                  //-- serial input data
   .SER_INPUT_EN(S_WREN),                               //  -- input data valid
	
	.PAR_DATA_EN(PAR_DATA_EN),
	.PAR_DATA(PAR_DATA),
	.ROW_NUM(ROW_NUM),
	.COL_NUM(COL_NUM),
   .DEC_RSYNC(q_rden)                                  //-- resynchronize decoder
	
);

wire[15:0] rdaddress;
wire dec_start;
RAM_CTRL ram_ctrl(
	.RESET(RESET),
	
	.WR_CLOCK(SCLOCK),
	.DATA(PAR_DATA),
	.DATA_WREN(PAR_DATA_EN),
	.ROW_NUM(ROW_NUM),
	.COL_NUM(COL_NUM),
	
	.RD_CLOCK(DCLOCK),
	.RD_EN(1'b1),
	.RD_ADDRESS(rdaddress),
	.q(q),
	.q_rden(dec_start)
	
);

/*
VGA_TEST vga(
	.clk(CLK),
	
	
	.rd_en(q_rden),
	.data(q),
	.RD_EN(RD_EN),
	.rd_address(rdaddress), 
	
	/////////VGA/////////
	//	VGA Side
	.VGA_R(VGA_R ),
	.VGA_G(VGA_G ),
	.VGA_B(VGA_B ),
	
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	
	.VGA_SYNC_N(VGA_SYNC_N),
	.VGA_BLANK_N(VGA_BLANK_N),
	
	.VGA_CLK(VGA_CLK)

);
*/

/*---------------------------------------*/


bayer2rgb rgb(
	.clk(DCLOCK),
	.reset(RESET),
	.dec_start(dec_start),
	.idata(q),
	.IDATA_ADDRESS(rdaddress),
	
	.ODATA_EN(),
	.odata(),
	.ODATA_ADDRESS()
);


endmodule