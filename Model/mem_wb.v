`timescale 1ns / 1ps

// MEM/WB 流水线寄存器
// RISC-V 32I 完全兼容，无指令逻辑修改
module mem_wb(
    input    wire           clk,   
    input    wire           rst,   
    input    wire   [5:0]   stall,
    
//来自MEM阶段的信息（mem模块）   
    input    wire   [4:0]   mem_wb_addr,  
    input    wire   [31:0]  mem_wb_data,   
    input    wire           mem_reg_write, 
    
//送往WB阶段的信息（reg_file模块）  
    output   reg    [4:0]   wb_wb_addr,
    output   reg    [31:0]  wb_wb_data,
    output   reg            wb_reg_write  
    );
    
    always @(posedge clk)begin
        if(rst==1'b1)begin
            // 修复：地址是5位，不是32位
            wb_wb_addr    <= 5'h0;   
            wb_wb_data    <= 32'h0;
            wb_reg_write  <= 1'b0;
        end
        else if(stall[4] == 1'b1) begin//暂停保持不变
            wb_wb_addr    <= wb_wb_addr;  
            wb_wb_data    <= wb_wb_data; 
            wb_reg_write  <= wb_reg_write;
        end
        else begin
            wb_wb_addr    <= mem_wb_addr;
            wb_wb_data    <= mem_wb_data;
            wb_reg_write  <= mem_reg_write;
        end
    end
endmodule
