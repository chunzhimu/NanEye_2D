module RX_DESERIALIZER(
	input wire SCLOCK,
	input wire RESET,		
	input wire FRAME_SYNC_START,
	input wire SER_INPUT,                                  //-- serial input data
   input wire SER_INPUT_EN,                               //  -- input data valid
	
	output wire[7:0] COL_NUM,
	output wire[7:0] ROW_NUM,
	output wire[7:0] PAR_DATA,
	output reg PAR_DATA_EN,
   output reg DEC_RSYNC                                  //-- resynchronize decoder
	

	
);


parameter C_INPUT_EN_CNT_WIDTH=8;
parameter[C_INPUT_EN_CNT_WIDTH-1 : 0] C_INPUT_EN_CNT_END=255;
parameter CNT_3PP=36;
parameter C_ROWS=250;
parameter C_COWS=250;

reg[11:0] I_SREG;

reg I_BIT_CNT_EN;
reg[3:0] I_BIT_CNT;
reg I_OUTREG_LOAD;
reg I_OUTREG_LOAD1;
reg I_PIXEL_ERROR;
reg[7:0] I_COL_CNT=0;
reg[7:0] I_ROW_CNT=0;

reg[11:0] I_OUTPUT;
reg[7:0] P_DATA;
//reg[15:0] prefix=16'h3ff;




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


reg frame_start=0;
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


reg[2:0] I_C_STATE,I_N_STATE;



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
			DEC_RSYNC <= 1;
			if((FRAME_SYNC_START==1)&(frame_start==0))   //if FRAME_SYNC_START rising edge waiting for  frame start 
 				I_N_STATE <= FR_START;
			else
				I_N_STATE <= IDLE;	
		end
	
		FR_START:
		begin
			DEC_RSYNC <= 0;
			if(I_SREG==12'b000000000000)		//if I_SREG==12'b000000000000 3pp detected, go to pixel data collecting
				I_N_STATE <= LINE_VALID;
			else
				I_N_STATE <= FR_START;
			
		end	
		
		LINE_VALID:
		begin
			DEC_RSYNC <= 0;
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
			DEC_RSYNC <= 0;
			if(I_SREG==12'b000000000000)
				I_N_STATE <= INC_ROW_CNT;
			else
				I_N_STATE <= I_C_STATE;
		end
		
		INC_ROW_CNT:
		begin		
			DEC_RSYNC <= 0;
			I_N_STATE <= LINE_VALID;
		end
			
		FRAME_END:								//if uptream process finished go to s_frame_sync counting 6000
		begin
			I_N_STATE <= IDLE;
			DEC_RSYNC <= 1;
		end
		
		default:begin I_N_STATE <= IDLE; DEC_RSYNC <= 0; end
		endcase
	end


/*************state output****************/
reg[3:0] cnt_l=0;

always@(posedge SCLOCK)
begin
	case(I_C_STATE)
	IDLE:
	begin
		cnt_l<=0;
		I_BIT_CNT_EN<=1'b0;
		I_ROW_CNT<=0;
		I_COL_CNT<=0;
	end
	
	FR_START:
	begin
		cnt_l<=0;
		I_COL_CNT<=0;
		I_ROW_CNT<=0;
		I_BIT_CNT_EN<=1'b0;
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
		I_ROW_CNT<=I_ROW_CNT;
		/*create a delay for appendix pixel fro each row end*/
		
		if(cnt_l<8)
		begin
			cnt_l<=cnt_l+1'b1;
			I_COL_CNT<=250;
		end
		else
		begin
			cnt_l<=cnt_l;
			I_COL_CNT<=0;
		end
	end
	
	INC_ROW_CNT:
	begin
		cnt_l<=0;
		I_COL_CNT<=0;
		I_BIT_CNT_EN<=1'b0;
		I_ROW_CNT <= I_ROW_CNT+1'b1;
	end
	
	FRAME_END:
	begin
		I_COL_CNT<=248;
		I_ROW_CNT<=I_ROW_CNT;
		I_BIT_CNT_EN<=1'b0;
	end
	
	default:begin I_BIT_CNT_EN<=1'b0; end
	endcase
	
end


assign COL_NUM=I_COL_CNT;
assign ROW_NUM=I_ROW_CNT;
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


/********************************************************************************
--------------------------------------------------------------------------
-----generate parallel output data and output en
---------------------------------------------------------------------------
********************************************************************************/
always@(posedge SCLOCK or negedge RESET)
begin
	if (RESET == 1'b0) 
	begin
		P_DATA <= 0;
		PAR_DATA_EN <= 1'b0;
	end
	else
	begin
	if(SER_INPUT_EN == 1'b1)
		begin
			if(I_OUTREG_LOAD==1'b1)
				begin
					P_DATA <= I_SREG[10:3];
					PAR_DATA_EN <= 1'b1;
				end
			else
				begin
					P_DATA <= 0;
					PAR_DATA_EN <= 1'b0;
				end
		end
	else
	if((I_ROW_CNT==(C_ROWS-1))&(I_COL_CNT==(C_ROWS-3)))
		if(I_BIT_CNT==4'd11)
		begin
			P_DATA <= I_SREG[10:3];
			PAR_DATA_EN <= 1'b1;
		end
		else
		begin
			P_DATA <= 0;
			PAR_DATA_EN <= 1'b0;
		end
	else	
		begin
			P_DATA <= 0;
			PAR_DATA_EN <= 1'b0;
		end
	end
end

assign PAR_DATA=P_DATA;



endmodule