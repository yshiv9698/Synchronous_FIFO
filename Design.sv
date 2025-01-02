// Code your design here
module syn_fifo #(parameter depth=8, data_width=8)(
input clk, rst,
  input [data_width-1:0] data_in,
  input wr_ena, rd_ena,
  output full, empty,
  output reg[data_width-1:0] data_out 
);
  reg[data_width-1:0] fifo [depth-1:0];
  reg [$clog2(depth):0] wr_ptr, rd_ptr;
  
 // reset
  always@(posedge clk)
    begin
      if(rst)
        begin
          wr_ptr<=0;
          rd_ptr<=0;
          data_out<=0;
          
          for(int i=0; i<depth; i++)
            begin
              fifo[i]<=8'b0;
            end
        end
    end
  
  // fifo write operation
  always@(posedge clk)
    begin
      if(wr_ena && !full)
        begin
          fifo[wr_ptr]<=data_in;
          wr_ptr++;
        end
    end
  
  // fifo read opertaion
  always@(posedge clk)
    begin
      if(rd_ena && !empty)
        begin
          data_out<=fifo[rd_ptr];
          rd_ptr++;
        end
    end
  
  // condition for full and empty
  assign empty= wr_ptr==rd_ptr;
  
  assign full= (wr_ptr[$clog2(depth)-1:0] == rd_ptr[$clog2(depth)-1:0]) && (wr_ptr[$clog2(depth)] ^ rd_ptr[$clog2(depth)]);
  
endmodule

interface fifo_inf;
  logic clk, rst;
  logic [7:0] data_in;
  logic wr_ena, rd_ena;
  logic full, empty;
  logic [7:0] data_out;
  
endinterface
