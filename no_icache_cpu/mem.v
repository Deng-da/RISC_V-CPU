`timescale 1ns / 1ps

// RISC-V 32I 数据访存阶段 MEM
// 支持：lb, lh, lw, lbu, lhu, sb, sh, sw
module mem(   
    input    wire            rst,
    
    //来自EX/MEM阶段的数据
    input    wire   [31:0]   mem_pc,      
    input    wire            mem_reg_write,        
    input    wire   [4:0]    mem_wb_addr,      
    input    wire   [31:0]   mem_wb_data,    
    input    wire   [2:0]    mem_op,      
    input    wire   [31:0]   mem_addr,      
    input    wire   [31:0]   mem_data, 
    
    //来自数据存储器读取的数据     
    input    wire   [31:0]   ram_data,      
    
    //送往WB阶段的信息（同时送往ID阶段用于解决Load_Use冒险）
    output   reg             reg_write, 
    output   reg    [4:0]    wb_addr,     
    output   reg    [31:0]   wb_data,
         
    //送往数据存储器的数据
    output   reg    [31:0]   mem_addr_o,    
    output   reg    [31:0]   mem_data_o,      
    output   reg             mem_we_n,      // 写使能 低有效
    output   reg    [3:0]    mem_sel_n,     // 字节使能 低有效
    output   reg             mem_ce         // 片选使能 低有效
          
    );
    
    // 临时变量：提取字节/半字
    reg [7:0]  lb_byte;
    reg [15:0] lh_half;
    
    always @(*) begin
        // 复位初始化
        if(rst == 1'b0) begin
            reg_write  = 1'b0;
            wb_addr    = 5'h0;
            wb_data    = 32'h0;
            mem_addr_o = 32'h0;
            mem_data_o = 32'h0;
            mem_we_n   = 1'b1; 
            mem_sel_n  = 4'b1111;
            mem_ce     = 1'b1; 
            lb_byte    = 8'h0;
            lh_half    = 16'h0;
        end else begin
            // 默认传递流水线信号
            reg_write  = mem_reg_write;
            wb_addr    = mem_wb_addr;
            wb_data    = mem_wb_data;
            mem_addr_o = mem_addr;
            mem_data_o = 32'h0;
            mem_we_n   = 1'b1;
            mem_ce     = 1'b0;
            mem_sel_n  = 4'b1111;

            // ===================== RISC-V 完整 Load/Store 指令 =====================
            case(mem_op)
                // ========== Load 指令 读存储器 ==========
                3'b001: begin // lb  有符号字节加载
                    mem_we_n  = 1'b1;
                    case(mem_addr[1:0])
                        2'b00: {mem_sel_n, lb_byte} = {4'b1110, ram_data[7:0]};
                        2'b01: {mem_sel_n, lb_byte} = {4'b1101, ram_data[15:8]};
                        2'b10: {mem_sel_n, lb_byte} = {4'b1011, ram_data[23:16]};
                        2'b11: {mem_sel_n, lb_byte} = {4'b0111, ram_data[31:24]};
                    endcase
                    wb_data = {{24{lb_byte[7]}}, lb_byte}; // 符号扩展
                end
                
                3'b010: begin // lh  有符号半字加载
                    mem_we_n  = 1'b1;
                    case(mem_addr[1])
                        1'b0: {mem_sel_n, lh_half} = {4'b1100, ram_data[15:0]};
                        1'b1: {mem_sel_n, lh_half} = {4'b0011, ram_data[31:16]};
                    endcase
                    wb_data = {{16{lh_half[15]}}, lh_half}; // 符号扩展
                end
                
                3'b011: begin // lw  字加载
                    mem_we_n  = 1'b1;
                    mem_sel_n = 4'b0000;
                    wb_data   = ram_data;
                end
                
                3'b100: begin // lbu 无符号字节加载
                    mem_we_n  = 1'b1;
                    case(mem_addr[1:0])
                        2'b00: {mem_sel_n, lb_byte} = {4'b1110, ram_data[7:0]};
                        2'b01: {mem_sel_n, lb_byte} = {4'b1101, ram_data[15:8]};
                        2'b10: {mem_sel_n, lb_byte} = {4'b1011, ram_data[23:16]};
                        2'b11: {mem_sel_n, lb_byte} = {4'b0111, ram_data[31:24]};
                    endcase
                    wb_data = {24'h00, lb_byte}; // 零扩展
                end
                
                3'b101: begin // lhu 无符号半字加载
                    mem_we_n  = 1'b1;
                    case(mem_addr[1])
                        1'b0: {mem_sel_n, lh_half} = {4'b1100, ram_data[15:0]};
                        1'b1: {mem_sel_n, lh_half} = {4'b0011, ram_data[31:16]};
                    endcase
                    wb_data = {16'h0000, lh_half}; // 零扩展
                end

                // ========== Store 指令 写存储器 ==========
                3'b110: begin // sb  字节存储
                    mem_we_n  = 1'b0;
                    case(mem_addr[1:0])
                        2'b00: {mem_sel_n, mem_data_o} = {4'b1110, {24'h0, mem_data[7:0]}};
                        2'b01: {mem_sel_n, mem_data_o} = {4'b1101, {16'h0, mem_data[7:0], 8'h0}};
                        2'b10: {mem_sel_n, mem_data_o} = {4'b1011, {8'h0, mem_data[7:0], 16'h0}};
                        2'b11: {mem_sel_n, mem_data_o} = {4'b0111, {mem_data[7:0], 24'h0}};
                    endcase
                    wb_data = 32'h0;
                end
                
                3'b111: begin // sh  半字存储
                    mem_we_n  = 1'b0;
                    case(mem_addr[1])
                        1'b0: {mem_sel_n, mem_data_o} = {4'b1100, {16'h0, mem_data[15:0]}};
                        1'b1: {mem_sel_n, mem_data_o} = {4'b0011, {mem_data[15:0], 16'h0}};
                    endcase
                    wb_data = 32'h0;
                end
                
                3'b000: begin // sw  字存储
                    mem_we_n  = 1'b0;
                    mem_sel_n = 4'b0000;
                    mem_data_o = mem_data;
                    wb_data   = 32'h0;
                end

                // ========== 非访存指令 ==========
                default: begin
                    wb_data    = mem_wb_data;
                    mem_addr_o = 32'h0;
                    mem_data_o = 32'h0;
                    mem_we_n   = 1'b1;
                    mem_ce     = 1'b1;
                    mem_sel_n  = 4'b1111;
                end
            endcase
        end
    end

endmodule