`timescale 1ns / 1ps

// RISC-V 32I 通用寄存器组
// x0 硬零，支持前递，完全符合 RISC-V 标准
module reg_file(
    input    wire           clk,
    input    wire           rst,
    
// MEM/WB 阶段写回信号
    input    wire           reg_write,
    input    wire   [4:0]   wb_addr,
    input    wire   [31:0]  wb_data,
    
// ID 阶段读信号
    input    wire   [4:0]   reg_1_addr,
    input    wire           re_1,
    output   reg    [31:0]  reg_1_data,
    input    wire   [4:0]   reg_2_addr,
    input    wire           re_2,
    output   reg    [31:0]  reg_2_data
    );  

    reg [31:0] registers [31:0];
    integer i;   
    
// 写端口：同步写，RISC-V x0 不可写
    always @(posedge clk) begin  // 移除冗余的 negedge rst，只保留时钟沿
        if(rst == 1'b0) begin
            for(i=0; i<32; i=i+1) begin
                registers[i] <= 32'h0;
            end
        end
        else begin
            // RISC-V 规则：x0 恒为 0，禁止写入
            if(reg_write == 1'b1 && wb_addr != 5'h0) begin
                registers[wb_addr] <= wb_data;
            end
        end
    end
    
// 读端口 1：组合逻辑读，支持前递
    always @(*) begin
        if(rst == 1'b0) begin
            reg_1_data = 32'h0;
        end
        else begin
            if(re_1 == 1'b1) begin
                if(reg_1_addr == 5'h0) begin
                    reg_1_data = 32'h0;           // RISC-V x0 恒零
                end
                else if(reg_1_addr == wb_addr && reg_write == 1'b1) begin
                    reg_1_data = wb_data;         // 数据前递（解决冒险）
                end
                else begin
                    reg_1_data = registers[reg_1_addr];
                end
            end
            else begin
                reg_1_data = 32'h0;
            end
        end
    end
    
// 读端口 2：组合逻辑读，支持前递
    always @(*) begin
        if(rst == 1'b0) begin
            reg_2_data = 32'h0;
        end
        else begin
            if(re_2 == 1'b1) begin
                if(reg_2_addr == 5'h0) begin
                    reg_2_data = 32'h0;           // RISC-V x0 恒零
                end
                else if(reg_2_addr == wb_addr && reg_write == 1'b1) begin
                    reg_2_data = wb_data;         // 数据前递
                end
                else begin
                    reg_2_data = registers[reg_2_addr];
                end
            end
            else begin
                reg_2_data = 32'h0;
            end
        end
    end
    
endmodule