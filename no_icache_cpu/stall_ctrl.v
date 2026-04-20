`timescale 1ns / 1ps

module stall_ctrl(

 input wire rst,
 input wire stallask_from_id,
 output reg [5:0] stall

 );

 always@(*)begin
 if(rst==1'b0) begin
  stall = 6'b000000;
 end else if (stallask_from_id) begin
  stall = 6'b000011;
 end else begin
  stall = 6'b000000;
 end
 end

endmodule