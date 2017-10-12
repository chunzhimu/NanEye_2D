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
   output wire [31:0] DEBUG_OUT,          //debug outputs
	
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
pll_clk	pll_clk_inst (
	.inclk0 ( CLK ),
	.c0 ( SCLOCK ),
	.locked ( locked_sig )
	);
	
	
	
/*------------------------------------------------------
-------rxdecoder-------
------------------------------------------------------*/
/*
RX_DECODER king
(
    .RESET(RESET),                                  // async. Reset
    .CLOCK(SCLOCK),                                  // sampling clock
    .ENABLE(1'b1),                        // module activation
    .RSYNC(),                          // resynchronize decoder
    .INPUT(SENSOR_DATA),                                 // manchester coded input
    .CONFIG_DONE(),                                // end of config phase (async)
    .CONFIG_EN(),                             // start of config phase
    .SYNC_START(),                       // start of synchronisation phase
    .FRAME_START(),                                          // start of frame
    .OUTPUT(),                                          // decoded data
    .OUTPUT_EN()                                      // output data valid
    //NANEYE3A_NANEYE2B_N(),        out std_logic;                                  // '0'=NANEYE2B, '1'=NANEYE3A
    //ERROR_OUT(),                  out std_logic;                                  // decoder error
    //DEBUG_OUT:                  out std_logic_vector(31 downto 0)             // debug outputs
);
*/
	
	
/*----------------------------------------------------------
----------test
----------------------------------------------------------*/
wire CON_ZERO,S_DATA,S_WREN,frame_syns_tart;
//OVERSAMPLE P1(
Sample_1 P1(
	.SCLOCK(SCLOCK),
	.RESET(RESET),
	.SENSOR_DATA(SENSOR_DATA),
	

	.CON_ZERO(CON_ZERO),
	.S_DATA(S_DATA),
	.S_WREN(S_WREN)
);
/*
FRAME_SYNC_START P2(
	.SCLOCK(SCLOCK),
	.RESET(RESET),
	.con_zero(CON_ZERO),
	
	.frame_syns_tart(frame_syns_tart)

);
*/
/*
MANC_DEC	P3(
	.SCLOCK(SCLOCK),
	.RESET(RESET),
	.frame_syns_tart(frame_syns_tart),
	.S_DATA(S_DATA),
	.S_WREN(S_WREN),
	.con_zero(CON_ZERO),
	
	.M_DATA(OUTPUT),
	.M_WREN(OUTPUT_EN)
);
*/
wire   OUTPUT;                  //-- decoded data
wire  OUTPUT_EN;                //-- output data valid

RX_DESERIALIZER deserializer(
	.SCLOCK(SCLOCK),
	.RESET(RESET),		 
	.SER_INPUT(S_DATA),                                  //-- serial input data
   .SER_INPUT_EN(S_WREN),                               //  -- input data valid
   .DEC_RSYNC()                                  //-- resynchronize decoder
);



endmodule