module RX_DECODER(
	input wire SCLOCK,
	input wire RESET,						//module reset key(0)
	input wire ENABLE,				  // module activation switch(0)
	input wire CONFIG_DONE,         // end of config phase (async)key(3)
	input wire RSYNC,               //resynchronize decoder
	input wire SENSOR_DATA,				//data from sensor
	
	output reg SYNC_START,          //start of synchronisation phase
	output reg CONFIG_EN,           //start of config phase
	output wire FRAME_START,         //start of frame
	output reg ERROR_OUT,                 //decoder error
   output wire [31:0] DEBUG_OUT,          //debug outputs
	output wire   OUTPUT,                  //-- decoded data
   output wire  OUTPUT_EN,                //-- output data valid
	output wire  NANEYE3A_NANEYE2B_N		//-- '0'=NANEYE2B, '1'=NANEYE3A
	

);

/*----------------######--CLOCK---########----------------
--generate sample clock 200MHz
--------------------------------------------------------*/


parameter G_CLOCK_PERIOD_PS = 5555;                               // CLOCK period in ps	
parameter C_BIT_LEN_W = 5;
parameter C_HISTOGRAM_ENTRIES = 2**C_BIT_LEN_W;
parameter C_HISTOGRAM_ENTRY_W = 12;
parameter C_CAL_CNT_W = 14;
parameter C_HB_PERIOD_CNT_W = 14;
parameter C_CAL_CNT_FR_END = (850000/G_CLOCK_PERIOD_PS);  //153
parameter C_CAL_CNT_SYNC = 32;
parameter C_RSYNC_PER_CNT_END = 1;
parameter C_RSYNC_PP_THR = 2*350*12;
	
parameter HF_BIT=9,FL_BIT=18;
/*-------------------######--IDDR---########-----------------------------
 --IDDR register for sampling the input data
 -----------------------------------------------------------------------*/
wire I_IDDR_Q0;
wire I_IDDR_Q1;
reg[1:0] I_IDDR_Q;
reg[1:0] I_LAST_IDDR_Q;
/*-----------------------------------------------------------------------
--double edge sampling
-------------------------------------------------------------------------*/
IDDR	IDDR_inst (
	.aclr ( ~RESET ),
	.datain ( SENSOR_DATA ),
	.inclock ( SCLOCK ),
	.dataout_h ( I_IDDR_Q0 ),
	.dataout_l ( I_IDDR_Q1 )
	);
	
/*-----------------------------------------------------------------------
--data valid signal
-------------------------------------------------------------------------*/
(* noprune *)reg con_zero=0;						//indicating the continuous zero time

always@(posedge SCLOCK or negedge RESET)		
begin
  if (RESET == 1'b0) 
	con_zero<=1'b0;
  else
  begin
	if(I_IDDR_Q[0]==1'b0)
	begin
		if(I_ADD_L>FL_BIT) 				
			begin	con_zero<=1'b1;end
	end
	else	
		begin con_zero<=1'b0;end
  end
end
/*------------------------##############-----------------------------------------
-- 2 bit pipeline register for the input data
--------------------------------------------------------------------------------*/	
always@(posedge SCLOCK or negedge RESET)
begin
	if(RESET==1'b0)
	begin
		I_IDDR_Q <= 2'b0;
		I_LAST_IDDR_Q <= 2'b0;
	end
	else	
	begin
		I_IDDR_Q[0] <=I_IDDR_Q1;
		I_IDDR_Q[1] <= I_IDDR_Q0;
		I_LAST_IDDR_Q <= I_IDDR_Q;
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
 reg[C_BIT_LEN_W-1:0] I_ADD_L,I_ADD_H,I_ADD;
 reg[C_BIT_LEN_W-1:0]  I_BIT_LEN;


always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET ==1'b0) 
	  begin
			I_ADD_L<=0;
			I_ADD_H<=0;
	  end
  else
	 case(I_IDDR_Q) 
		 2'b00:
			begin
			  I_ADD_H <= 5'b00000;
			  if (I_LAST_IDDR_Q[0] ==1'b1) 
				  begin
					 I_ADD_L <= 5'b00010;
				  end
			  else
				begin
				 I_ADD_L <= I_ADD_L + 5'b00010;
				end
		  end
		 2'b01:begin
					I_ADD_L <= I_ADD_L+5'b00001;
					I_ADD_H <= 5'b00001;
				end
		 2'b10:begin
				I_ADD_H <= I_ADD_H+5'b00001;
				I_ADD_L <= 5'b00001;
			  end
		 2'b11:
			begin
				I_ADD_L <= 5'b00000;
			  if (I_LAST_IDDR_Q[0] == 1'b0)
				begin 
					I_ADD_H <= 5'b00010;
				end
			  else
				begin
					I_ADD_H <= I_ADD_H + 5'b00010;
			   end
			end
		 default:
			begin
			  I_ADD_L <= 5'b00000;
			  I_ADD_H <= 5'b00000;
			end
	 endcase
end


/*--------------------######--BIT_LEN_REG---########-----------------------------
-- register for storing the duration of a bit
--------------------------------------------------------------------------------*/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
    I_BIT_LEN <= 0;
  else
    case(I_IDDR_Q)
      2'b00:begin
				  if (I_LAST_IDDR_Q[0] == 1'b1)
					 I_BIT_LEN <= I_ADD_L;
					else
					 I_BIT_LEN <= I_BIT_LEN;
				end
      2'b01:begin
					I_BIT_LEN <= I_ADD_L +5'b00001;
			  end
      2'b10:begin
					I_BIT_LEN <= I_ADD_L +5'b00001;
			  end
     2'b11:begin
				  if (I_LAST_IDDR_Q[0] == 1'b0)
					 I_BIT_LEN <= I_ADD_L;
					else
					 I_BIT_LEN <= I_BIT_LEN;
			end
      default:
				begin
				  I_BIT_LEN <= I_BIT_LEN;
				end
    endcase
end

/*#################################*/












/*------------------------#######---BIT_TRANS_EVAL---#######---------------------
-- I_BIT_TRANS is activated every time a transition in the bit stream occurs
--------------------------------------------------------------------------------*/
reg I_BIT_TRANS;

always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0)
    I_BIT_TRANS <= 1'b0;
		
    case(I_IDDR_Q)
      2'b00:begin
			  if (I_LAST_IDDR_Q[0] == 1'b1)
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
			  if (I_LAST_IDDR_Q[0] == 1'b0)
				 I_BIT_TRANS <= 1'b1;
				else
				 I_BIT_TRANS <= 1'b0;
        end
      default:begin
				I_BIT_TRANS <= 1'b0;
		  end
    endcase
end



/********************FSM for oversample output *******************
--
******************************************************************/

reg [5:0] c_state,n_state;

parameter         //state encode
idle = 6'b000001, //reset,waiting for start_Sig
s_0  = 6'b000010, //single 0
s_00 = 6'b000100, //double 0 
all_0= 6'b001000, //continuous all 0 
s_1  = 6'b010000, //single 1
s_11 = 6'b100000; //double 1 


/*************REG****************/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
		c_state <= idle;
	else	
	   c_state <= n_state;
end


/*************COM1:State Convert**************
--idle->s_0/s_1:if count number in the range(2,6)
--s_0->s_00:if count number in the range(5,10)
--s_00->all_0:if count number in the range(10，*)
--s_1->s_11:if count number in the range(5,10)

*********************************************/
always@(c_state,I_ADD_L,I_IDDR_Q,I_ADD_H,I_BIT_LEN)
begin
	case(c_state)
	idle:
	begin
		if(con_zero==0)
		begin
			if((I_ADD_L>2 && I_ADD_L<6))
				n_state<=s_0;
			else
				if(I_ADD_H>2 && I_ADD_H<6)
					n_state<=s_1;
				else
					n_state<=idle;
		end	
	end
	
	s_0:
	begin
		if(I_ADD_L>HF_BIT && I_ADD_L<FL_BIT)//(cnt_L>6 && cnt_L<10)
			n_state<=s_00;
		else	
			if (I_IDDR_Q[0]==1'b1)
				n_state<=s_1;
			else	
				n_state<=s_0;	
	end		
	
	s_00:
	begin
		if(I_IDDR_Q[0]==1'b1)
			n_state<=s_1;	
		else 
			if(con_zero==1'b1)
				n_state<=all_0;
			else
				n_state<=s_00;	
	end
	
	all_0:
	begin
	   if(I_IDDR_Q[0]==1'b1)
			n_state<=s_1;
		else
			n_state<=all_0;
	end
			
	s_1:
	begin
		if(I_ADD_H>HF_BIT && I_ADD_H<FL_BIT)//(cnt_H>6 && cnt_H<10)
			n_state<=s_11;
		else
			if (I_IDDR_Q[0]==1'b0)
				n_state<=s_0;
			else
				n_state<=s_1;	
	end
			
	s_11:
	begin
		if(I_IDDR_Q[0]==1'b0)
			n_state<=s_0;
		else
			n_state<=s_11;
	end
	
	default:n_state<=idle;
	endcase
end


/************COM2:Decode Output**********/


/*****************************************
--write enable generate--------
******************************************/
reg [3:0] wr_once;
reg wren_s;
always@(posedge SCLOCK)
begin
	case(c_state)
	idle: 
		begin 
			wren_s<=1'b0; 
			wr_once<=4'b0000; 
		end
		
	s_0:  
	begin 
		if(wr_once!=4'b0001) 
			wren_s<=1'b1;
		else	
			wren_s<=1'b0; 
		wr_once<=4'b0001; 
	end
	
	s_1:  
	begin 
		if(wr_once!=4'b0010) 
			wren_s<=1'b1; 
		else	
			wren_s<=1'b0; 
		wr_once<=4'b0010; 
	end
	
	s_00: 
	begin 
		if(wr_once!=4'b0100) 
			wren_s<=1'b1; 
		else	
			wren_s<=1'b0; 
		wr_once<=4'b0100; 
	end
	
	s_11: 
	begin 
		if(wr_once!=4'b1000) 
			wren_s<=1'b1; 
		else	
			wren_s<=1'b0; 
		wr_once<=4'b1000; 
	end
	
	all_0:
	begin 
		wren_s<=1'b0; 
		wr_once<=4'b0000; 
	end 
	
	default:
	begin 
		wren_s<=1'b0; 
		wr_once<=4'b0000; 
	end
	endcase
end


/*****************************************
--recovered data after oversample--------
******************************************/
reg Start_Sig;
reg out_s;
always@(c_state)
begin
	case(c_state)
	idle: begin Start_Sig<=1'b0;out_s<=1'b0;end
	s_0:  begin Start_Sig<=1'b1;out_s<=1'b0;end
	s_1:  begin Start_Sig<=1'b1;out_s<=1'b1;end
	s_00: begin Start_Sig<=1'b1;out_s<=1'b0;end
	s_11: begin Start_Sig<=1'b1;out_s<=1'b1;end
	all_0:begin Start_Sig<=1'b0;out_s<=1'b0;end 
	default:begin Start_Sig<=1'b0;out_s<=1'b0;end
	endcase
end



//assign OUTPUT_EN=wren_s;
//assign OUTPUT=out_s;

/*******************************************************/
 /*********FSM for manchester decode output ************/
 /******************************************************/

reg [1:0] c_dstate,n_dstate;

parameter         //state encode
dec_idle = 2'b00, //reset,waiting for 00/11
dec_s_0  = 2'b01, //decode 0
dec_s_1  = 2'b10; //decode 1

wire DATA_VALID/* synthesis keep */;
assign DATA_VALID=(!con_zero)&wren_s;
(* noprune *)reg[1:0] ODD1,ODD2;
/*************REG****************/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
		c_dstate <= dec_idle;
	else	
	   c_dstate <= n_dstate;
end
/*-------------------------------------------------------------
--two bit pipeline for shift serialised manchester code
--------------------------------------------------------------*/
always@(posedge SCLOCK )
begin
	if(DATA_VALID==1'b1)
		begin
			ODD1[0]<=out_s;
			ODD1[1]<=ODD1[0];
		end
	else		
		begin
			ODD1<=ODD1;
		end
end
/*
(* noprune *)reg king=0;
(* noprune *)reg cnt=0;
always@(posedge SCLOCK )
begin
	if(DATA_VALID==1'b1)
		begin
			if(ODD1==2'b11)
				begin
					king<=1'b1;
				end
//			else	
//			begin
//				king<=1'b0;
//			end
		end
	else
		king<=1'b0;
end

(* noprune *)reg king1=0;
always@(posedge SCLOCK )
begin
	if(con_zero==1'b0)
		if(wren_s==1'b1)
		begin
			if(ODD1==2'b00)
				begin
					king1<=1'b1;
				end
			else	
			begin
				king1<=1'b0;
			end
		end
		else
			king1<=1'b0;
end

*/

/********************************************************************
--FSM for manchester decode
********************************************************************/
parameter S_idle=2'b00,  //wait for decode start signal
			 S_dec=2'b01,
			 S0=2'b10,	//output the decoded data 0
			 S1=2'b11;	//output the decoded data 1
			 
(* noprune *)reg[1:0] md_c_state,md_n_state;
reg Mdecode_start,FRAME_END;
/*---------------------------------------*/
always@(posedge SCLOCK or negedge RESET)
begin
  if (RESET == 1'b0) 
		md_c_state <= S_idle;
	else	
	   md_c_state <= md_n_state;
end

always@(md_c_state)
begin
	case(md_c_state)
	S_idle:begin
		if(ODD1==2'b11)
			begin
			md_n_state<=S_dec;
			end
		else
			begin
				md_n_state<=S_idle;
			end
		end
	
	S_dec:begin
			if(ODD1==2'b10)
				md_n_state<=S0;
			else
				if(ODD1==2'b01)
					md_n_state<=S1;
			end
	
	S0:begin
		if(con_zero==1'b1)
			md_n_state<=S_idle;
		else
			md_n_state<=S_dec;
	end
	
	S1:begin
			if(con_zero==1'b1)
				md_n_state<=S_idle;
			else
				md_n_state<=S_dec;
		end
	
	default:
	begin 
		md_n_state<=S_idle;
	end
	endcase
end


/*************************************************
--MANchester DECODE write enable generate--------
**************************************************/
reg [3:0] M_wr_once;
reg mdout /*synthesis noprune*/;

reg mdwren /*synthesis noprune*/;

reg M_Start_Sig;

always@(posedge SCLOCK)
begin
	case(c_state)
	S_idle: 
		begin 
			mdwren<=1'b0; 
			M_wr_once<=4'b0000; 
		end
		
	S_dec:  
	begin 
		mdwren<=1'b0; 
		M_wr_once<=4'b0000; 
	end
	
	S0:  
	begin 
		if(M_wr_once!=4'b0001) 
			mdwren<=1'b1; 
		else	
			mdwren<=1'b0; 
		M_wr_once<=4'b0001; 
	end
	
	S1: 
	begin 
		if(M_wr_once!=4'b0010) 
			mdwren<=1'b1; 
		else	
			mdwren<=1'b0; 
		M_wr_once<=4'b0010; 
	end
	
	default:
	begin 
		mdwren<=1'b0; 
		M_wr_once<=4'b0000; 
	end
	endcase
end
/*-------------------------------------------
--OUTPUT DATA
-------------------------------------------*/
always@(md_c_state)
begin
	case(md_c_state)
	S_idle: begin M_Start_Sig<=1'b0;mdout<=1'b0;end
	S_dec:  begin M_Start_Sig<=1'b0;mdout<=1'b0;end
	S0:  begin M_Start_Sig<=1'b1;mdout<=1'b0;end
	S1: begin M_Start_Sig<=1'b1;mdout<=1'b1;end
	default:begin M_Start_Sig<=1'b0;mdout<=1'b0;end
	endcase
end

assign OUTPUT=mdout;
assign OUTPUT_EN=mdwren;
assign NANEYE3A_NANEYE2B_N=1'b0;




FRAME_START_GEN frame_start_gen(
	.SCLOCK(SCLOCK),
	.RESET(RESET),	
	.I_data(out_s),                  //-- decoded data
   .I_data_en(wren_s),        
	.start_Sig(con_zero),			 //indicating the start of 250pp frame end signal					
	.FRAME_START(FRAME_START)         //start of frame

);


endmodule