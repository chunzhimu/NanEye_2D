module bayer2rgb(
	input wire clk,
	input wire reset,
	input wire dec_start,
	input wire[7:0] idata,
	output wire[15:0] IDATA_ADDRESS
	
	
);



/*-------------------------------------------------------------------
--parameters for bayer decode
-------------------------------------------------------------------*/
parameter ROW=250;
parameter COL=250;

reg[15:0] idata_address;


wire ODATA_EN/*synthesis keep*/;
wire[31:0] odata/*synthesis keep*/;
wire[15:0] ODATA_ADDRESS/*synthesis keep*/;
reg[15:0] odata_address;

(* noprune *)reg [3:0] cnt=0;

(* noprune *)reg[7:0] data1,data2,data3,data4;
(* noprune *)reg[7:0] data_1,data_2,data_3,data_4;
(* noprune *)reg[7:0] red,green,blue;

(* noprune *)reg[7:0] X=0,Y=0;

assign odata={8'b00000000,red,green,blue};
assign IDATA_ADDRESS=idata_address;
assign ODATA_ADDRESS=odata_address;
/*---------------------------------------------------------------
----------------------------------------------------------------
--FSM for channel value recovery 
----------------------------------------------------------------
---------------------------------------------------------------*/
parameter IDLE = 4'b0000, 			//waiting for decode start signal 
			 PIXEL_DEC = 4'b0001,	//decide the location of the pixel
			 BLUE = 4'b0010,			//blue pixel
			 RED = 4'b0100,			//red pixel
			 GREEN1 = 4'b0110,			//green pixel
			 GREEN2 =4'b0011,
			 EDGE = 4'b1000,			//pixel on the edge 
			 INC = 4'b1001;			//address increase
			 
(* noprune *)reg[3:0] c_state,n_state;


/*------------------------state reg------------------------------------*/
always@(posedge clk or negedge reset)
begin
	if(reset==0)
		begin
			c_state <= IDLE;
		end
	else
		begin
			c_state <= n_state;
		end
end


/*-----------------------state transation---------------------------------------*/
always@(c_state,X,Y,cnt)
begin
	case(c_state)
	IDLE:begin
			if(dec_start==1)
				n_state <= PIXEL_DEC;
			else
				n_state <= IDLE;
			end
	
	PIXEL_DEC:begin
					if(Y<250)
						begin
							if((X==0)||(X==249)||(Y==0)||(Y==249))		//neglect the edge pixels
								begin
									n_state <= EDGE;
								end
							else
								begin													//if not edge pixels
								if((X[0]==0)&(Y[0]==1))			//Blue pixel
									begin
										n_state <= BLUE;
									end
								else
									if((X[0]==1)&(Y[0]==0))		//Red pixel
										begin
											n_state <= RED;
										end
									else
										if((X[0]==0)&(Y[0]==0))		//Green1 pixel
											begin
												n_state <= GREEN1;
											end
										else							//Green2 pixel：if((X[0]==1)&(Y[0]==1))	
											begin
												n_state <= GREEN2;
											end
								end
						end
					else
						begin
							n_state <= IDLE;
						end
				 end
			
	BLUE:begin
				if(cnt==9)
					n_state <= INC;
				else
					n_state <= c_state;
			end
	
	RED:begin
				if(cnt==9)
					n_state <= INC;
				else
					n_state <= c_state;
			end
	
	GREEN1:begin
				if(cnt==5)
					n_state <= INC;
				else
					n_state <= c_state;
			end
	
	GREEN2:begin
				if(cnt==5)
					n_state <= INC;
				else
					n_state <= c_state;
			end
			
	EDGE:begin
				if(cnt==1)
					n_state <= INC;
				else
					n_state <= c_state;
			end
	
	INC:begin
			n_state <= PIXEL_DEC;
		end
	
	default:n_state <= IDLE;
	endcase
end

/*-----------------------state output---------------------------------------*/
always@(posedge clk)
begin
	case(c_state)
	IDLE:begin
			X<=0;
			Y<=0;
			cnt<=0;
			end
	
	PIXEL_DEC:begin
					cnt<=0;
				end
			
	BLUE:begin
				if(cnt<9)
				begin
					cnt<=cnt+1'b1;
				end
				else
					cnt<=cnt;
			end
	
	RED:begin
				if(cnt<9)
					cnt<=cnt+1'b1;
				else
					cnt<=cnt;
			end
	
	GREEN1:begin
				if(cnt<5)
					cnt<=cnt+1'b1;
				else
					cnt<=cnt;
			end

	GREEN2:begin
				if(cnt<5)
					cnt<=cnt+1'b1;
				else
					cnt<=cnt;
			end	
	
	EDGE:begin
			if(cnt<1)
				cnt<=cnt+1'b1;
			else
				cnt<=cnt;
			
			end
			
	INC:begin
			cnt<=cnt;
			if(Y<250)
				if(X==249)
					begin
						X<=0;
						Y<=Y+1'b1;
					end
				else
					begin
						X<=X+1'b1;
					end
			
		end
		
	
			
	default:begin
			X<=0;
			Y<=0;
			cnt<=0;
			end
			
	endcase
	
end
/*------------------------------------------------------------
--calculate the value of rgb channel of a pixel 
---------------------------------------------------------------*/
always@(posedge clk)
begin
	case(c_state)
	IDLE:begin
			idata_address<=0;
			odata_address<=odata_address;
			data1<=0;
			data2<=0;
			data3<=0;
			data4<=0;
			data_1<=0;
			data_2<=0;
			data_3<=0;
			data_4<=0;
			red<=red;
			green<=green;
			blue<=blue;
			end
	
	PIXEL_DEC:begin
					idata_address<=Y*ROW+X;
					odata_address<=Y*ROW+X;
					red<=0;
					green<=0;
					blue<=0;
				end
			
	BLUE:begin
				case(cnt)
				4'b0000:begin idata_address<=Y*ROW+(X-1); blue<=idata; end
				
				4'b0001:begin idata_address<=Y*ROW+(X+1); data1<=idata; end
				4'b0010:begin idata_address<=(Y-1)*ROW+X; data2<=idata; green<=(data1>>2); end
				4'b0011:begin idata_address<=(Y+1)*ROW+X; data3<=idata; green<=green+(data2>>2); end
				4'b0100:begin idata_address<=(Y+1)*ROW+(X-1); data4<=idata; green<=green+(data3>>2); end
				
				4'b0101:begin idata_address<=(Y+1)*ROW+(X+1); data_1<=idata; green<=green+(data4>>2);end
				4'b0110:begin idata_address<=(Y-1)*ROW+(X-1); data_2<=idata; red<=(data_1>>2); end
				4'b0111:begin idata_address<=(Y-1)*ROW+(X+1); data_3<=idata; red<=red+(data_2>>2); end
				4'b1000:begin idata_address<=idata_address;	 data_4<=idata; red<=red+(data_3>>2); end
				4'b1001:begin red<=red+(data_4>>2); end
				//default:begin idata_address<=idata_address;	 data_3<=idata; end
				endcase
			end
	
	RED:begin
				case(cnt)
				4'b0000:begin idata_address<=Y*ROW+(X-1); red<=idata; end
				
				4'b0001:begin idata_address<=Y*ROW+(X+1); data1<=idata; end
				4'b0010:begin idata_address<=(Y-1)*ROW+X; data2<=idata; green<=(data1>>2); end
				4'b0011:begin idata_address<=(Y+1)*ROW+X; data3<=idata; green<=green+(data2>>2); end
				4'b0100:begin idata_address<=(Y+1)*ROW+(X-1); data4<=idata; green<=green+(data3>>2); end
				
				4'b0101:begin idata_address<=(Y+1)*ROW+(X+1); data_1<=idata; green<=green+(data4>>2);end
				4'b0110:begin idata_address<=(Y-1)*ROW+(X-1); data_2<=idata; blue<=(data_1>>2); end
				4'b0111:begin idata_address<=(Y-1)*ROW+(X+1); data_3<=idata; blue<=blue+(data_2>>2); end
				4'b1000:begin idata_address<=idata_address;	 data_4<=idata; blue<=blue+(data_3>>2); end
				4'b1001:begin blue<=blue+(data_4>>2); end
				//default:begin idata_address<=idata_address;	 data_3<=idata; end
				endcase
			end
	
	GREEN1:begin
				case(cnt)
				4'b0000:begin idata_address<=(Y-1)*ROW+X; green<=idata; end
				
				4'b0001:begin idata_address<=(Y+1)*ROW+X; data1<=idata; end
				4'b0010:begin idata_address<=Y*ROW+(X-1); data2<=idata; blue<=(data1>>1); end
				4'b0011:begin idata_address<=Y*ROW+(X+1); data_1<=idata; blue<=blue+(data2>>1); end
				4'b0100:begin idata_address<=(Y+1)*ROW+(X-1); data_2<=idata; red<=red+(data_1>>1); end
				4'b0101:begin red<=red+(data_2>>1);  end
				
				//default:begin idata_address<=idata_address;	 data_3<=idata; end
				endcase
			end

	GREEN2:begin
				case(cnt)
				4'b0000:begin idata_address<=(Y-1)*ROW+X; green<=idata; end
				
				4'b0001:begin idata_address<=(Y+1)*ROW+X; data1<=idata; end
				4'b0010:begin idata_address<=Y*ROW+(X-1); data2<=idata; red<=(data1>>1); end
				4'b0011:begin idata_address<=Y*ROW+(X+1); data_1<=idata; red<=red+(data2>>1); end
				4'b0100:begin idata_address<=(Y+1)*ROW+(X-1); data_2<=idata; blue<=blue+(data_1>>1); end
				4'b0101:begin blue<=blue+(data_2>>1);  end
				
				//default:begin idata_address<=idata_address;	 data_3<=idata; end
				endcase
			end
		
	EDGE:begin
			red<=idata; 
			green<=idata; 
			blue<=idata; 
			X<=X;
			Y<=Y;
			end
	
	
	INC:begin
			red<=red;
			green<=green;
			blue<=blue;
		end
	
	default:begin
				red<=red;
				green<=green;
				blue<=blue;
				idata_address<=idata_address;
				odata_address<=odata_address;
			  end
	
	endcase
	
end

/*------------------------------------------------------------------------------------
--generate write enable signal
--------------------------------------------------------------------------------------*/
reg odata_en=0;

always@(c_state)
begin
	case(c_state)
	IDLE:begin
				odata_en<=1'b0;
			end
	
	PIXEL_DEC:begin
				odata_en<=1'b0;
			end
			
	BLUE:begin
				odata_en<=1'b1;
			end
	
	RED:begin
				odata_en<=1'b1;
			end
	
	GREEN1:begin
				odata_en<=1'b1;
			end

	GREEN2:begin
				odata_en<=1'b1;
			end
		
	EDGE:begin
				odata_en<=1'b1;
			end
	
	
	INC:begin
				odata_en<=1'b1;
			end
	
	default:begin
				odata_en<=1'b0;
			end
	
	endcase
	
end

assign ODATA_EN=odata_en;

/*--------------------------------------------------------------------------
--RAM for decoded 8-bit rgb data
---------------------------------------------------------------------------*/
RAM24	RAM24_inst (
	.data ( odata ),
	.wraddress ( ODATA_ADDRESS ),
	.wrclock ( clk ),
	.wren ( ODATA_EN ),
	
	.rdaddress ( rdaddress_sig ),
	.rdclock ( rdclock_sig ),
	.rden ( rden_sig ),
	.q ( q_sig )
	);



endmodule