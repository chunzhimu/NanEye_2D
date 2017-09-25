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
	output wire   OUTPUT,                  //-- decoded data
	output wire  OUTPUT_EN,                //-- output data valid
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
	
/*----------------------------------------------------------
----------test
----------------------------------------------------------*/

//wire   OUTPUT;                  //-- decoded data
//wire  OUTPUT_EN;                //-- output data valid

RX_DECODER decoder(
	.SCLOCK(SCLOCK),
	.RESET(RESET),						//module reset key(0)
	.ENABLE(ENABLE),				  // module activation switch(0)
	.CONFIG_DONE(CONFIG_DONE),         // end of config phase (async)key(3)
	.RSYNC(),               //resynchronize decoder
	.SYNC_START(),          //start of synchronisation phase
	.CONFIG_EN(),           //start of config phase
	.FRAME_START(),         //start of frame
	.ERROR_OUT(),                 //decoder error
   .DEBUG_OUT(),          //debug outputs
	.OUTPUT(OUTPUT),                  //-- decoded data
   .OUTPUT_EN(OUTPUT_EN),                //-- output data valid
	.NANEYE3A_NANEYE2B_N(),
	//output wire led0,
	.SENSOR_DATA(SENSOR_DATA)
);	
	
RX_DESERIALIZER deserializer(
	.SCLOCK(SCLOCK),
	.RESET(RESET),		 
	.SER_INPUT(OUTPUT),                                  //-- serial input data
   .SER_INPUT_EN(OUTPUT_EN),                               //  -- input data valid
   .DEC_RSYNC()                                  //-- resynchronize decoder
);

endmodule