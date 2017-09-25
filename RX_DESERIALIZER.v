module RX_DESERIALIZER(
	input wire SCLOCK,
	input wire RESET,		 
	input wire SER_INPUT,                                  //-- serial input data
   input wire SER_INPUT_EN,                               //  -- input data valid
   output reg DEC_RSYNC                                  //-- resynchronize decoder
);


parameter C_INPUT_EN_CNT_WIDTH=8;
parameter[C_INPUT_EN_CNT_WIDTH-1 : 0] C_INPUT_EN_CNT_END=255;

(* noprune *)reg[11:0] I_SREG;
reg I_BIT_CNT_EN;
reg[3:0] I_BIT_CNT;
reg I_OUTREG_LOAD;
reg I_OUTREG_LOAD1;
reg I_PIXEL_ERROR;
reg[8:0] I_COL_CNT;
reg[8:0] I_ROW_CNT;
reg[11:0] I_OUTPUT;
reg I_OUTPUT_EN;
reg I_LINE_END;
reg[C_INPUT_EN_CNT_WIDTH-1:0] I_INPUT_EN_CNT;
reg I_FRAME_START_PULSE;

/*------state machine--------*/
parameter IDLE=3'b000;
parameter FR_START=3'b001;
parameter LINE_VALID=3'b011;
parameter LINE_SYNC=3'b010;
parameter INC_ROW_CNT=3'b110;
parameter FRAME_END=3'b100;


reg[3:0] I_PRESENT_STATE,I_LAST_STATE;

/*-------------------*****---SREG_EVAL---*******---------------------------------
-- shift register
--------------------------------------------------------------------------------*/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 0) 
    I_SREG <= 0;
  else 
	 begin
		 if (SER_INPUT_EN == 1)
			 begin
				I_SREG[11:1] <= I_SREG[10:0];
				I_SREG[0] <= SER_INPUT;
			 end
		 else
			I_SREG <= I_SREG;
	 end
end
reg tesla=0 /*synthesis noprune*/;
always@(I_SREG)
begin
	if((I_SREG[11]==1'b0)&(I_SREG[0]==1'b1))
		tesla<=1'b1;
		
end
///*------------------*****---BIT_CNT_EN_EVAL---*******-------------------------
//-- bit counter is enabled after receiving the first pixel with valid start-
//-- bit after a frame start / line end
//----------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_BIT_CNT_EN <= 0;
//  else
//  begin
//    if (I_PIXEL_ERROR == 1) 
//      I_BIT_CNT_EN <= 0;
//    else
//	 begin
//		 if(I_PRESENT_STATE == LINE_VALID)
//		 begin
//			if (I_SREG[11] == 1) 
//			  I_BIT_CNT_EN <= 1;
//			else
//			  I_BIT_CNT_EN <= I_BIT_CNT_EN;
//		 end 
//		 else
//			I_BIT_CNT_EN <= 0;
//    end 
//  end 
//end 
//
///*-------------------*****---BIT_CNT_EVAL---*******------------------------------
//-- bit counter for generating the load-pulses for the parallel register
//--------------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_BIT_CNT <= 0;
//  else 
//  begin
//    if (I_BIT_CNT_EN == 1) 
//	 begin
//      if (SER_INPUT_EN == 1) 
//		begin
//        if (I_BIT_CNT == 4'b1011) 
//          I_BIT_CNT <= 4'b0000;
//        else
//          I_BIT_CNT <= I_BIT_CNT + 1;
//      end 
//      else
//        I_BIT_CNT <= I_BIT_CNT;
//    end 
//    else
//      I_BIT_CNT <= 0;
//  end
//end 
//
//
///*-----------------*****---OUTREG_LOAD_EVAL---*******---------------------------
//-- load-signal for the parallel output register
//-------------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//  begin
//    I_OUTREG_LOAD  <= 0;
//    I_OUTREG_LOAD1 <= 0;
//  end
//  else
//  begin
//    I_OUTREG_LOAD1 <= I_OUTREG_LOAD;
//    if (I_PRESENT_STATE == LINE_VALID)
//	 begin
//      if ((I_BIT_CNT_EN == 0) && (I_SREG[11] == 1) && (I_SREG[0] == 0)) 
//        I_OUTREG_LOAD <= 1;
//     else 
//	  begin
//		  if (I_BIT_CNT == 4'b1011) 
//			  I_OUTREG_LOAD <= SER_INPUT_EN;
//			else
//			  I_OUTREG_LOAD <= 0;
//	  end
//    end 
//    else
//      I_OUTREG_LOAD <= 0;
//  end 
//end 
//
///*-----------------*****---ERROR_EVAL---*******--------------------------------
//-- activate error, if one pixel doesn't have a valid start-bit or stop-bit
//------------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET ==0)
//    I_PIXEL_ERROR <= 0;
//  else 
//  begin
//    if (I_PRESENT_STATE == LINE_VALID)
//	 begin
//      if ((I_OUTREG_LOAD1 == 1) && ((I_OUTPUT[11] == 0) | (I_OUTPUT[0] == 1)))
//        I_PIXEL_ERROR <= 1;
//      else
//        I_PIXEL_ERROR <= 0;
//    end
//    else
//      I_PIXEL_ERROR <= 0;
//  end 
//end 
//
///*----------------------*****---COL_CNT_EVAL---*******-------------------------
//-- count number of pixels per line
//-----------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_COL_CNT <= 0;
//  else 
//  begin 
//    if ((I_PRESENT_STATE == FR_START) | (I_PRESENT_STATE == LINE_SYNC) | (I_PIXEL_ERROR == 1)) 
//      I_COL_CNT <= 0;
//    else
//	 begin
//		if(I_PRESENT_STATE == LINE_VALID) 
//		begin
//			if (I_OUTREG_LOAD1 == 1) 
//			  I_COL_CNT <= I_COL_CNT + 1;
//			else
//			  I_COL_CNT <= I_COL_CNT;
//      end 
//		else
//			I_COL_CNT <= I_COL_CNT;
//	 end
//  end 
//end 
//
///*----------------------*****---ROW_CNT_EVAL---*******-----------------------
//-- count number of rows per frame
//----------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_ROW_CNT <= 0;
//  else
//  begin
//    if (I_PRESENT_STATE == FR_START)
//      I_ROW_CNT <= 0;
//    else
//		begin
//			if(I_PRESENT_STATE == INC_ROW_CNT) 
//				I_ROW_CNT <= I_ROW_CNT + 1;
//			else
//				I_ROW_CNT <= I_ROW_CNT;
//		end
//  end 
//end 
//
//
///*----------------------*****---OUTPUT_EVAL---*******-----------------------
//-- parallel output register
//---------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_OUTPUT <= 0;
//  else
//  begin
//    if (I_OUTREG_LOAD == 1) 
//      I_OUTPUT <= I_SREG;
//    else
//      I_OUTPUT <= I_OUTPUT;
//  end 
//end
//
///*----------------------*****---OUTPUT_EN_EVAL---*******-----------------------
//-- generating PAR_OUTPUT_EN
//-----------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_OUTPUT_EN <= 0;
//  else
//    I_OUTPUT_EN <= I_OUTREG_LOAD1;
//end
//
//
///*----------------------*****---LINE_END_EVAL---*******-----------------------
//-- I_LINE_END = pulse after the last pixel of each line was received
//------------------------------------------------------------------------------*/
//always@(posedge SCLOCK or negedge RESET)
//begin
//  if (RESET == 0) 
//    I_LINE_END <= 0;
//  else
//  begin
//    if (((I_PRESENT_STATE == LINE_SYNC) && (I_LAST_STATE == LINE_VALID)) | (I_PRESENT_STATE == FRAME_END)) 
//      I_LINE_END <= 1;
//    else
//      I_LINE_END <= 0;
//  end
//end
//
//always@(I_PRESENT_STATE,I_PIXEL_ERROR)
//begin
//	if((I_PRESENT_STATE == INC_ROW_CNT) | (I_PIXEL_ERROR == 1))
//		DEC_RSYNC <= 1;
//	else
//		DEC_RSYNC <=0;
//end
//
//assign PAR_OUTPUT     = I_OUTPUT;
//assign PAR_OUTPUT_EN  = I_OUTPUT_EN;
//assign LINE_END       = I_LINE_END;
//assign PIXEL_ERROR    = I_PIXEL_ERROR;
//assign ERROR_OUT      =0;
//assign DEBUG_OUT = 0;

endmodule