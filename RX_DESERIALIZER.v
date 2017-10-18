module RX_DESERIALIZER(
	input wire SCLOCK,
	input wire RESET,		
	input wire FRAME_SYNC_START,
	input wire SER_INPUT,                                  //-- serial input data
   input wire SER_INPUT_EN,                               //  -- input data valid
	
	output reg[9:0] P_DATA,
   output reg DEC_RSYNC                                  //-- resynchronize decoder
	
);


parameter C_INPUT_EN_CNT_WIDTH=8;
parameter[C_INPUT_EN_CNT_WIDTH-1 : 0] C_INPUT_EN_CNT_END=255;
parameter CNT_3PP=36;
parameter C_ROWS=250;
parameter C_COWS=250;

(* noprune *)reg[11:0] I_SREG;

(* noprune *)reg I_BIT_CNT_EN;
(* noprune *)reg[3:0] I_BIT_CNT;
(* noprune *)reg I_OUTREG_LOAD;
reg I_OUTREG_LOAD1;
reg I_PIXEL_ERROR;
(* noprune *)reg[8:0] I_COL_CNT=0;
(* noprune *)reg[8:0] I_ROW_CNT=0;
reg[11:0] I_OUTPUT;
reg I_OUTPUT_EN;
reg I_LINE_END;
reg[C_INPUT_EN_CNT_WIDTH-1:0] I_INPUT_EN_CNT;
reg I_FRAME_START_PULSE;

reg[5:0]cnt_3pp=0;
/*-------------------------------------------------------------------------------
-------------------*****---SREG_EVAL---*******---------------------------------
-- shift register
--------------------------------------------------------------------------------*/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 0) 
    begin I_SREG <= 12'b111111111111; end
  else 
	 begin
	 if(FRAME_SYNC_START==1'b0)
		 begin
			I_SREG <= 12'b111111111111;
		 end
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
end


(* noprune *)reg frame_start=0;
always@(posedge SCLOCK or negedge RESET)		
begin
  if (RESET == 1'b0) 
		begin frame_start<=1'b0; end
  else 
		begin frame_start<=FRAME_SYNC_START; end
end





reg tesla=1'b0/* synthesis noprune */;
always@(posedge SCLOCK or negedge RESET)
begin
	 if (RESET == 1'b0) 
		tesla<=1'b0;
	else
	begin
		if((I_SREG[11]==1'b1)&(I_SREG[0]==1'b0))
			tesla<=1'b1;
		else
			tesla<=1'b0;
	end
end




/*******************************************************************************
---------------------------------------------------------------
--FSM for data receiving--------
---------------------------------------------------------------
*******************************************************************************/

/*------state machine--------*/
parameter IDLE=3'b000;  			//waiting for frame start 
parameter FR_START=3'b001;			//frame start received
parameter LINE_VALID=3'b011;		//waiting until one row was completely received
parameter LINE_SYNC=3'b010;		//waiting for line sync(3pp)
parameter INC_ROW_CNT=3'b110;		//increment row counter
parameter FRAME_END=3'b100;		//complete frame received,switch to IDLE


(* noprune *)reg[2:0] I_C_STATE,I_N_STATE;



/*************REG****************/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
		I_C_STATE <= IDLE;
	else
		I_C_STATE <= I_N_STATE;
end


/*************state transation****************/
always@(I_C_STATE,frame_start,FRAME_SYNC_START,I_SREG)
	begin
		case(I_C_STATE)
		IDLE:
		begin
			if((FRAME_SYNC_START==1)&(frame_start==0))   //if FRAME_SYNC_START rising edge waiting for  frame start 
 				I_N_STATE <= FR_START;
			else
				I_N_STATE <= IDLE;	
		end
	
		FR_START:
		begin
			if(I_SREG==12'b000000000000)		//if I_SREG==12'b000000000000 3pp detected, go to pixel data collecting
				I_N_STATE <= LINE_VALID;
			else
				I_N_STATE <= FR_START;
			
		end	
		
		LINE_VALID:
		begin
			if(I_ROW_CNT<(C_ROWS-1))//if con_zero rising edge (1pp start)
				begin
					if(I_COL_CNT==(C_COWS-1))
						I_N_STATE <= LINE_SYNC;
					else
						I_N_STATE <= I_C_STATE;
				end
			else
				begin
					if(I_COL_CNT==(C_ROWS-2))
						I_N_STATE <= FRAME_END;
					else
						I_N_STATE <= I_C_STATE;
				end
		end
		
		LINE_SYNC:							//if cnt_1pp=153 start the uptream process
		begin
			if(I_SREG==12'b000000000000)
				I_N_STATE <= INC_ROW_CNT;
			else
				I_N_STATE <= I_C_STATE;
		end
		
		INC_ROW_CNT:
		begin		
			I_N_STATE <= LINE_VALID;
		end
			
		FRAME_END:								//if uptream process finished go to s_frame_sync counting 6000
		begin
			I_N_STATE <= IDLE;
		end
		
		default:I_N_STATE <= IDLE;
		endcase
	end


/*************state output****************/


//reg[8:0] I_COL_CNT=0;
//reg[8:0] I_ROW_CNT=0;

//reg[11:0] I_BIT_CNT=0;
//reg I_BIT_CNT_EN=1'b0;
//
//parameter IDLE=3'b000;  			//waiting for frame start 
//parameter FR_START=3'b001;			//frame start received
//parameter LINE_VALID=3'b011;		//waiting until one row was completely received
//parameter LINE_SYNC=3'b010;		//waiting for line sync(3pp)
//parameter INC_ROW_CNT=3'b110;		//increment row counter
//parameter FRAME_END=3'b100;		//complete frame received,switch to IDLE

(* noprune *)reg END=0;


always@(posedge SCLOCK)
begin
	case(I_C_STATE)
	IDLE:
	begin
		END<=1'b0;
		I_BIT_CNT_EN<=1'b0;
		I_ROW_CNT<=0;
		I_COL_CNT<=0;
	end
	
	FR_START:
	begin
		I_COL_CNT<=0;
		I_ROW_CNT<=0;
		I_BIT_CNT_EN<=1'b0;
		END<=1'b0;
	end
	
	LINE_VALID:
	begin
		if(I_SREG[0]==1'b1)
		begin
			I_BIT_CNT_EN<=1'b1;
		end
		else
		begin
			I_BIT_CNT_EN<=I_BIT_CNT_EN;
		end
		
					
		if((I_ROW_CNT==(C_ROWS-1))&(I_COL_CNT==(C_ROWS-3))&(I_BIT_CNT==4'd11))
			begin
			I_COL_CNT  <= I_COL_CNT +1'b1;
			end
		else
			begin
				if(SER_INPUT_EN == 1'b1)
					begin
						if(I_BIT_CNT==4'd11)
							begin
								I_COL_CNT <= I_COL_CNT+1'b1;
							end
						else
							begin
								I_COL_CNT <= I_COL_CNT;
							end
					end
				else
					begin
						I_COL_CNT <= I_COL_CNT;
					end
			end
			
			
	end
	
	LINE_SYNC:
	begin
		I_BIT_CNT_EN<=1'b0;
		I_COL_CNT<=0;
		I_ROW_CNT<=I_ROW_CNT;
	end
	
	INC_ROW_CNT:
	begin
		I_COL_CNT<=0;
		I_BIT_CNT_EN<=1'b0;
		I_ROW_CNT <= I_ROW_CNT+1'b1;
	end
	
	FRAME_END:
	begin
		END<=1'b1;
		I_COL_CNT<=0;
		I_ROW_CNT<=0;
		I_BIT_CNT_EN<=1'b0;
	end
	
	default:begin I_BIT_CNT_EN<=1'b0; end
	endcase
	
end

//----------------pixel data load_en----------------------

always@(posedge SCLOCK or negedge RESET)
begin
	if (RESET == 1'b0) 
		I_BIT_CNT <= 0;
	else
	begin
		if((I_BIT_CNT_EN==1'b1))
			begin
				if(SER_INPUT_EN == 1'b1)
					if(I_OUTREG_LOAD==1'b1)
						begin
							I_BIT_CNT <= 0;
						end
					else
						begin
							I_BIT_CNT <= I_BIT_CNT+1'b1;
						end
				else
					begin
						if(I_C_STATE==FRAME_END)
							I_BIT_CNT <= 0;
						else
							I_BIT_CNT <= I_BIT_CNT;
					end
			end
		else
			begin
				I_BIT_CNT <= 0;
			end		
	end
end



always@(posedge SCLOCK or negedge RESET)
begin
	if (RESET == 1'b0) 
		begin
			I_OUTREG_LOAD <= 0;
		end
	else
		begin
			if(I_BIT_CNT==4'd11)
			begin
				I_OUTREG_LOAD <= 1'b1;
			end
			else
			begin
				I_OUTREG_LOAD <= 1'b0;
			end
		end
end



always@(posedge SCLOCK or negedge RESET)
begin
	if (RESET == 1'b0) 
		P_DATA <= 0;
	else
	begin
	if(SER_INPUT_EN == 1'b1)
		begin
			if(I_OUTREG_LOAD==1'b1)
				begin
					P_DATA <= I_SREG[10:1];
				end
			else
				begin
					P_DATA <= 0;
				end
		end
	else
	if((I_ROW_CNT==(C_ROWS-1))&(I_COL_CNT==(C_ROWS-3)))
		if(I_BIT_CNT==4'd11)
			P_DATA <= I_SREG[10:1];
		else
			P_DATA <= 0;
	else	
		begin
			P_DATA <= 0;
		end
	end
end




/*------------------*****---BIT_CNT_EN_EVAL---*******-------------------------
-- bit counter is enabled after receiving the first pixel with valid start-
-- bit after a frame start / line end
----------------------------------------------------------------------------*/
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