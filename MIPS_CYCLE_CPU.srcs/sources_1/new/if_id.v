`timescale 1ns / 1ps
module if_id(
    input   wire           clk,
    input   wire           rst,
    
    //IF阶段传来的信息   
    input   wire   [31:0]  if_pc, 
    input   wire   [31:0]  if_inst,
    
    //传给ID阶段的信息
    output  reg    [31:0]  id_pc,
    output  reg    [31:0]  id_inst,
    
    //流水线暂停信号
    input   wire   [5:0]   stall   
    );
    always @(posedge clk)begin
        if(rst == 1'b0) begin
            id_pc    <= 32'h0;
            id_inst  <= 32'h0;
    //若if与id阶段都暂停，则保持不变
        end 
        else if(stall[1] == 1'b1) begin
            id_pc    <= id_pc;
            id_inst  <= id_inst;
        end
        else begin
            id_pc    <= if_pc;
            id_inst  <= if_inst;
        end
    
    end
endmodule
