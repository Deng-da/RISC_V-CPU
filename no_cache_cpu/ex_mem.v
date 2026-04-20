`timescale 1ns / 1ps

// RISC-V 32I 兼容：EX/MEM 流水线寄存器
// 功能：寄存执行阶段结果，处理Store指令字节/半字/字对齐
module ex_mem(
    input    wire            clk,
    input    wire            rst,      // 高有效复位（比赛标准）
    input    wire   [31:0]   ex_pc,
    input    wire            ex_reg_write,   
    input    wire   [4:0]    ex_wb_addr,   
    input    wire   [31:0]   ex_wb_data,   
    input    wire   [2:0]    ex_mem_op,   
    input    wire   [31:0]   ex_mem_addr,   
    input    wire   [31:0]   ex_mem_data, 
    input    wire   [5:0]    stall,
    
//送往WB阶段的信息
    output   reg    [31:0]   mem_pc,  
    output   reg             mem_reg_write,
    output   reg    [4:0]    mem_wb_addr,
    output   reg    [31:0]   mem_wb_data,  
                             
//送往MEM阶段的信息                            
    output   reg    [2:0]    mem_mem_op,              
    output   reg    [31:0]   mem_mem_addr,              
    output   reg    [31:0]   mem_mem_data,
    
    // 上一条存储指令的地址和数据，用于数据旁路/转发
    output   reg    [31:0]   last_store_addr,
    output   reg    [31:0]   last_store_data                  
    );
    
    always @(posedge clk)begin
        // ====================== 关键修改：高有效复位 ======================
        if(rst == 1'b1)begin
            mem_pc           <= 32'h0;
            mem_reg_write    <= 1'b0;
            mem_wb_addr      <= 5'h0;
            mem_wb_data      <= 32'h0;       
            mem_mem_op       <= 3'h0;
            mem_mem_addr     <= 32'h0;
            mem_mem_data     <= 32'h0;                         
            last_store_addr  <= 32'h0;
            last_store_data  <= 32'h0;
        end
        // 流水线停顿：保持当前值不变
        else if(stall[3] == 1'b1) begin
            mem_pc           <= mem_pc;         
            mem_reg_write    <= mem_reg_write;  
            mem_wb_addr      <= mem_wb_addr;    
            mem_wb_data      <= mem_wb_data;    
            mem_mem_op       <= mem_mem_op;     
            mem_mem_addr     <= mem_mem_addr;   
            mem_mem_data     <= mem_mem_data;   
            last_store_addr  <= last_store_addr;
            last_store_data  <= last_store_data;
        end
        else begin
            // 基础流水线信号寄存（无修改）
            mem_pc           <= ex_pc;
            mem_reg_write    <= ex_reg_write;
            mem_wb_addr      <= ex_wb_addr;
            mem_wb_data      <= ex_wb_data;       
            mem_mem_op       <= ex_mem_op;
            mem_mem_addr     <= ex_mem_addr;
            mem_mem_data     <= ex_mem_data;                         
            
            // ===================== RISC-V 核心修改：Store 指令对齐 =====================
            // 适配 RISC-V sb/sh/sw 对齐逻辑，与 ex.v 输出的 mem_op 完全匹配
            case(ex_mem_op)
                3'b110:begin// sb  字节存储 (RISC-V)
                    last_store_addr  <= ex_mem_addr;
                    case(ex_mem_addr[1:0]) // 按字节地址偏移对齐
                        2'b00: last_store_data <= {24'h0, ex_mem_data[7:0]};
                        2'b01: last_store_data <= {16'h0, ex_mem_data[7:0], 8'h0};
                        2'b10: last_store_data <= {8'h0,  ex_mem_data[7:0], 16'h0};
                        2'b11: last_store_data <= {ex_mem_data[7:0], 24'h0};
                        default: last_store_data <= last_store_data;
                    endcase      
                end
                3'b111:begin// sh  半字存储 (RISC-V 新增)
                    last_store_addr  <= ex_mem_addr;
                    case(ex_mem_addr[1]) // 半字地址必须 2 字节对齐
                        1'b0:  last_store_data <= {16'h0, ex_mem_data[15:0]};
                        1'b1:  last_store_data <= {ex_mem_data[15:0], 16'h0};
                        default: last_store_data <= last_store_data;
                    endcase
                end
                3'b000:begin// sw  字存储 (RISC-V)
                    last_store_addr  <= ex_mem_addr;
                    last_store_data  <= ex_mem_data;
                end
                default:begin
                    // 非存储指令，保持上一次的值
                    last_store_addr  <= last_store_addr;
                    last_store_data  <= last_store_data;                
                end            
            endcase
        end
    end
endmodule