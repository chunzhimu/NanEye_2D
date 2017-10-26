module RAM_CTRL(
	input wire RESET,
	
	input wire WR_CLOCK,
	input wire[7:0] DATA,
	input wire DATA_WREN,
	input wire[7:0] ROW_NUM,
	input wire[7:0] COL_NUM,
	
	input wire RD_CLOCK,
	input wire RD_EN,
	input wire[15:0] RD_ADDRESS,
	output wire q_rden,
	output wire[7:0] q
	
	
);

parameter col=250;
parameter row=250;
parameter pixel_num=62500;


reg[7:0] black_pixel=0;
reg[15:0] WR_ADDRESS;
reg[7:0] WR_DATA;

/*******************************************************************
--------------------------------------------------------------------
--get the first balck pixel value
---------------------------------------------------------------------
********************************************************************/
always@(posedge WR_CLOCK or negedge RESET)
begin
	if(RESET==1'b0)
		begin
			black_pixel<=0;
		end
	else
		begin
			if(DATA_WREN==1'b1)
				if((COL_NUM==1)&(ROW_NUM==0))			
					begin
						black_pixel<=DATA;
					end
					else
					begin
						black_pixel<=black_pixel;
					end
			else
				begin
					black_pixel<=black_pixel;
				end
						
		end
end
/*******************************************************************
--------------------------------------------------------------------
--get the  pixel value and corresponding address and pixel data
---------------------------------------------------------------------
********************************************************************/
always@(posedge WR_CLOCK or negedge RESET)
begin
	if(RESET==1'b0)
		begin
			WR_ADDRESS<=0;
			WR_DATA<=0;
		end
	else
		begin
			if(ROW_NUM<(row-1))
			begin
				if(COL_NUM<col-1)	
					begin
						if(DATA_WREN==1'b1)		
							begin
								WR_ADDRESS<=ROW_NUM*row+COL_NUM;
								WR_DATA<=DATA;
							end	
						else
							begin
								WR_ADDRESS<=WR_ADDRESS;
								WR_DATA<=WR_DATA;
							end
					end
				else
					begin
						WR_ADDRESS<=ROW_NUM*row+COL_NUM;
						WR_DATA<=black_pixel;
					end
			end
			else
			begin
				if(COL_NUM<(col-2))	
					begin
						if(DATA_WREN==1'b1)		
							begin
								WR_ADDRESS<=ROW_NUM*row+COL_NUM;
								WR_DATA<=DATA;
							end	
						else
							begin
								WR_ADDRESS<=WR_ADDRESS;
								WR_DATA<=WR_DATA;
							end
					end
				else
					begin
						if(WR_ADDRESS<pixel_num)
						begin
							WR_ADDRESS<=WR_ADDRESS+1'b1;
							WR_DATA<=black_pixel;
						end
						else
						begin
							WR_ADDRESS<=WR_ADDRESS;
							WR_DATA<=black_pixel;
						end
					end
			end		
			
			
		end
end



/*******************************************************************
--------------------------------------------------------------------
--ram for storing the pixel data
---------------------------------------------------------------------
********************************************************************/
/*--------------------------------------------------------------------------
--
---------------------------------------------------------------------------*/
reg dataread=0;
always@(posedge WR_CLOCK or negedge RESET)
begin
	if(RESET==1'b0)
		begin
			dataread<=1'b0;
		end
	else
		begin
			if((WR_ADDRESS>16'd62490)&(WR_ADDRESS<16'd62500))
				dataread<=1'b1;
			else
				dataread<=1'b0;
		end
end

assign q_rden=dataread;
RAM	RAM_inst (
	.data ( WR_DATA ),
	.wraddress ( WR_ADDRESS ),
	.wrclock ( WR_CLOCK ),
	.wren ( 1'b1 ),
	
	.rdaddress ( RD_ADDRESS ),
	.rdclock ( RD_CLOCK ),
	.rden ( RD_EN ),
	.q ( q )
	);


endmodule