module Sample_1(
	input wire SCLOCK,
	input wire RESET,
	input wire SENSOR_DATA,

	output reg frame_sync_start,
	output wire S_DATA,
	output wire	S_WREN
);

parameter C_BIT_LEN_W = 5;
parameter HF_BIT=8,FL_BIT=17;
parameter CNT_250PP=6054,CNT_1PP=153;
/*-------------------######--IDDR---########-----------------------------
 --IDDR register for sampling the input data
 -----------------------------------------------------------------------*/
wire I_IDDR_Q0;
wire I_IDDR_Q1;
reg[1:0] I_IDDR_Q;
reg[1:0] I_LAST_IDDR_Q;
reg[1:0] I_LAST_IDDR_L;
/*-----------------------------------------------------------------------
--double edge sampling
-------------------------------------------------------------------------*/
IDDR	IDDR_inst (
	.aclr ( 1'b0 ),
	.datain ( SENSOR_DATA ),
	.inclock ( SCLOCK ),
	.dataout_h ( I_IDDR_Q0 ),
	.dataout_l ( I_IDDR_Q1 )
	);
	

/*------------------------##############-----------------------------------------
-- 2 bit pipeline register for the input data
--------------------------------------------------------------------------------*/	
always@(posedge SCLOCK or negedge RESET)
begin
	if(RESET==1'b0)
	begin
		I_IDDR_Q <= 2'b0;
		I_LAST_IDDR_Q <= 2'b0;
		I_LAST_IDDR_L <= 2'b0;
	end
	else	
	begin
		I_IDDR_Q[0] <=I_IDDR_Q0;
		I_IDDR_Q[1] <= I_IDDR_Q1;
		I_LAST_IDDR_Q <= I_IDDR_Q;
		I_LAST_IDDR_L <= I_LAST_IDDR_Q;
	end
end



/*----------------######--IDDR_Q_REG_ADDER---########---------------------
-- adder for measuring the duration of a bit
-- count the duration of the bits
-- I_IDDR_Q="00"  if I_LAST_IDDR_Q(0) = '1' (=> I_ADD=2), 	 (=> I_ADD+=2)
-- I_IDDR_Q="01"  (=> I_ADD=1)
-- I_IDDR_Q="10"  (=> I_ADD=1)
-- I_IDDR_Q="11"  if I_LAST_IDDR_Q(0) = '1' (=> I_ADD=2), 	 (=> I_ADD+=2)
-------------------------------------------------------------------------------*/
reg[C_BIT_LEN_W-1:0] I_ADD;
reg[C_BIT_LEN_W-1:0]  I_BIT_LEN,I_BIT_LEN1,I_BIT_LEN_L,I_BIT_LEN_MIN,I_BIT_LEN_MAX;
// (* noprune *)reg[C_BIT_LEN_W-1:0] I_ADD;
// (* noprune *)reg[C_BIT_LEN_W-1:0]  I_BIT_LEN,I_BIT_LEN1,I_BIT_LEN_L,I_BIT_LEN_MIN,I_BIT_LEN_MAX;


always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET ==1'b0) 
	  begin
			I_ADD<=0;
			I_BIT_LEN_L<=0;
	  end
  else
	 case(I_LAST_IDDR_Q) 
		 2'b00:
			begin
			  if (I_LAST_IDDR_L[0] ==1'b1) 
				  begin
					 I_ADD <= 5'b00010;
				  end
			  else
				begin
				 I_ADD <= I_ADD + 5'b00010;
				end
		  end
		 2'b01:begin
					I_ADD <= 5'b00001;
				end
		 2'b10:begin
					I_ADD <= 5'b00001;					
			  end
		 2'b11:
			begin
			  if (I_LAST_IDDR_L[0] == 1'b0)
				begin 
					I_ADD <= 5'b00010;
				end
			  else
				begin
					I_ADD <= I_ADD + 5'b00010;
			   end
			end
		 default:
			begin
			  I_ADD <= 5'b00000;
			end
	 endcase
end

/*--------------------------------------------------------------------------------
-- register for storing the duration of a bit
--------------------------------------------------------------------------------*/
always@(posedge SCLOCK or negedge RESET)		
begin
	if (RESET == 1'b0) 
		I_BIT_LEN<=1'b0;
  else
  begin
	case(I_LAST_IDDR_Q)
	2'b00:
		begin
		  if (I_LAST_IDDR_L[0] ==1'b1) 
			  begin
				 I_BIT_LEN <= I_ADD;
			  end
		  else
				begin
				 I_BIT_LEN <= I_BIT_LEN;
				end
		end
	 2'b01:begin
				I_BIT_LEN <= I_ADD+5'b1;
			end
	 2'b10:begin
				I_BIT_LEN <= I_ADD+5'b1;
		  end
	 2'b11:
		begin
		  if (I_LAST_IDDR_L[0] == 1'b0)
			begin 
				I_BIT_LEN <= I_ADD;
			end
		  else
			begin
				I_BIT_LEN <= I_BIT_LEN;
			end
		end
	 default:
		begin
		  I_BIT_LEN <= I_BIT_LEN;
		end
	endcase
  end

end


/*------------------------#######---BIT_TRANS_EVAL---#######---------------------
--judging from the data in I_LAST_IDDR_Q and I_LAST_IDDR_L
--I_BIT_TRANS is activated every time a transition in the bit stream occurs 
--------------------------------------------------------------------------------*/
reg I_BIT_TRANS;
//(* noprune *)reg I_BIT_TRANS;

always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
    I_BIT_TRANS <= 1'b0;
  else 
    case(I_LAST_IDDR_Q)
      2'b00:begin
			  if (I_LAST_IDDR_L[0] == 1'b1)
				 I_BIT_TRANS <= 1'b1;
			  else
				 I_BIT_TRANS <= 1'b0;
        end
      2'b01:begin
				I_BIT_TRANS <= 1'b1;
		  end
      2'b10:begin
				I_BIT_TRANS <= 1'b1;
		  end
      2'b11:begin
			  if (I_LAST_IDDR_L[0] == 1'b0)
				 I_BIT_TRANS <= 1'b1;
			  else
				 I_BIT_TRANS <= 1'b0;
        end
      default:begin
				I_BIT_TRANS <= 1'b0;
		  end
    endcase
end


/**----------------------------------------------------------------------------
-- I_COMP_EN <= I_BIT_TRANS   delayed by one clock cycle
-- I_CHECK_EN <= I_COMP_EN    delayed by one clock cycle
----------------------------------------------------------------------------**/
reg  I_COMP_EN,I_CHECK_EN;
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		 I_COMP_EN <= 1'b0;
		 I_CHECK_EN <= 1'b0;
	  end
  else
	  begin
		I_CHECK_EN <= I_COMP_EN;
		I_COMP_EN <= I_BIT_TRANS;
	  end
end


/*-----------------------------------------------------------------------
--data valid signal
-------------------------------------------------------------------------*/
reg con_zero=0;						//indicating the continuous zero time
//(* noprune *)reg con_zero=0;

always@(posedge SCLOCK or negedge RESET)		
begin
  if (RESET == 1'b0) 
	con_zero<=1'b0;
  else
	  if(I_IDDR_Q[0]==1'b0)
		begin
			if(I_ADD>FL_BIT)
				begin	con_zero<=1'b1;end
			else
				begin	con_zero<=con_zero;end
		end
		else	
			begin con_zero<=1'b0;end
end




reg con_zero_L=0;	
//(* noprune *)reg con_zero_L=0;

always@(posedge SCLOCK or negedge RESET)
begin
	if (RESET == 1'b0)
		con_zero_L <= 1'b0;
   else 
	begin
		con_zero_L <= con_zero;
	end
end


/*--------------------------------------------------------------------------------
-- comparator which decides, whether a "half"-bit period or "full" bit was received
--------------------------------------------------------------------------------*/
reg  I_HB_PERIOD,I_FB_PERIOD,I_B_ERROR;

always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		I_HB_PERIOD<=1'b0;
		I_FB_PERIOD<=1'b0;
	  end
  else
	  begin
		  if(con_zero==1'b0)
				begin
					if(I_COMP_EN == 1'b1)
						begin
							if(I_BIT_LEN>HF_BIT)
								begin
									I_HB_PERIOD<=1'b0;
									I_FB_PERIOD<=1'b1;
								end
							else
								begin
									I_HB_PERIOD<=1'b1;
									I_FB_PERIOD<=1'b0;
								end
						end
					else
					begin
						I_FB_PERIOD<=I_FB_PERIOD;
						I_HB_PERIOD<=I_HB_PERIOD;
					end
				end
			else
				begin
					I_FB_PERIOD<=0;
					I_HB_PERIOD<=0;
				end
		end
end


always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		I_B_ERROR<=1'b0;
	  end
  else
	if(I_CHECK_EN == 1'b1)
	if((I_HB_PERIOD==1'b1)&(I_FB_PERIOD==1'b1))
		I_B_ERROR<=1'b1;
	else
		I_B_ERROR<=1'b0;
end
/********************FSM for data stream*******************
--
******************************************************************/

reg [3:0] c_state,n_state/* synthesis noprune */;

parameter         //state encode
idle = 4'b0000, //reset,waiting for start_Sig
s_frame_sync	= 4'b0001,//start 250pp
s_dec_start  = 4'b0010, //cnt=6000;
s_dec_end_1pp = 4'b0100, //frame end 
s_upstream = 4'b1000;//upstream period


reg[7:0] cnt_1pp=0;
reg [12:0] cnt_250pp=0;
/*************REG****************/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
		c_state <= idle;
	else
		c_state <= n_state;
end

/*************state transation****************/
always@(con_zero_L,con_zero,c_state,cnt_250pp,cnt_1pp )
	begin
		case(c_state)
		idle:
		begin
			if((con_zero_L==1)&(con_zero==0))   //if con_zero falling edge (250pp start)
 				n_state <= s_frame_sync;
			else
				n_state <= idle;	
		end
		
		s_frame_sync:
		begin
			if(cnt_250pp==CNT_250PP)		//if cnt_250pp=6000 start the decoding process
				n_state <= s_dec_start;
			else
				n_state <= s_frame_sync;
			
		end		
		
		s_dec_start:
		begin
			if((con_zero_L==0)&(con_zero==1))//if con_zero rising edge (1pp start)
				n_state <= s_dec_end_1pp;
			else
				n_state <= s_dec_start;
		end
		
		s_dec_end_1pp:							//if cnt_1pp=153 start the uptream process
		begin
			if(cnt_1pp==CNT_1PP)
				n_state <= s_upstream;
			else
				n_state <= s_dec_end_1pp;
		end
			
		s_upstream:								//if uptream process finished go to s_frame_sync counting 6000
		begin
			n_state <= idle;
		end
		
		default:n_state <= idle;
		endcase
	end


/*************state output****************/
always@(posedge SCLOCK )
begin
  if (RESET == 1'b0) 
	begin
		cnt_250pp <= 0;
		cnt_1pp <= 0;
	end
  else
	begin
		case(c_state)
		
		s_frame_sync:
			begin
				if(I_CHECK_EN==1'b1)
					cnt_250pp<=cnt_250pp+1'b1;	
				else
					cnt_250pp<=cnt_250pp;
			end		
		
		s_dec_end_1pp:							//if cnt_1pp=153 start the uptream process
			begin
				cnt_1pp<=cnt_1pp+1'b1;	
			end
			
		default:
			begin
				cnt_250pp <= 0;
				cnt_1pp <= 0;
			end
		endcase
	end
end







/*****************************************
--COM2:Decode Output--------
*****************************************/

reg I_OUTPUT=0;

always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
	  I_OUTPUT <= 1'b0;
	  end
	else
	begin
		if(n_state == s_dec_start)
			begin	
				if(I_CHECK_EN==1'b1)
					begin
						if(I_FB_PERIOD==1'b1)
							I_OUTPUT <= ~I_OUTPUT;
						else
							I_OUTPUT <= I_OUTPUT;
					end
				else
					begin I_OUTPUT <= I_OUTPUT;end
			end
		else
			begin
				I_OUTPUT <= 1'b0;
			end
	end

end
/*****************************************
--write enable generate--------
*****************************************/
reg  M_WREN=0;
reg cnt=0 ; 
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		cnt <= 0;
	  end
	else
	begin
		//if(I_FB_PERIOD==1'b1)
		//if(I_COMP_EN == 1'b1)
		if(I_BIT_TRANS == 1'b1)
		begin
			cnt <= ~cnt;
		end
		else
		begin
			cnt <= cnt;
		end
	end	
end


always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		M_WREN <= 0;
	  end
	else
	begin
		if(n_state == s_dec_start)
		begin
			//if((I_CHECK_EN == 1'b1)&(cnt==1'b1)|(I_CHECK_EN == 1'b1)&(I_FB_PERIOD==1'b1))
			if((I_COMP_EN == 1'b1)&(cnt==1'b1)|(I_COMP_EN == 1'b1)&(I_FB_PERIOD==1'b1))
			begin
				M_WREN <= 1'b1;
			end
			else
			begin
				M_WREN <= 1'b0;
			end
		end
		else
		begin
			M_WREN <= 1'b0;
		end
	end	
end

assign S_DATA=I_OUTPUT;
assign S_WREN=M_WREN;


/*****************************************
--frame start for deserializer--------
*****************************************/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
	  begin
		frame_sync_start <= 0;
	  end
	else
	begin
		if(c_state != s_dec_start)
			begin
				frame_sync_start<=1'b0;
			end
		else
			begin
				frame_sync_start <= 1'b1;
			end
	end	
end


endmodule