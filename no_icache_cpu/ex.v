`timescale 1ns / 1ps

// RISC-V 32I 执行阶段模块 EX
// 适配：ALU运算、分支判断、Load/Store地址生成、冒险检测
module ex(
    // 来自ID/EX流水线寄存器的输入
    input   wire            rst,
    input   wire   [4:0]    alu_op,        // RISC-V ALU操作编码
    input   wire   [31:0]   reg_1,         // rs1 数据
    input   wire   [31:0]   reg_2,         // rs2 / 立即数
    input   wire   [4:0]    wb_addr,       // 目的寄存器 rd
    input   wire            reg_write,     // 寄存器写使能
    input   wire   [31:0]   ex_inst,       // 当前指令
    input   wire   [31:0]   ex_pc,         // 当前PC
    input   wire   [31:0]   link_addr,     // JAL/JALR 返回地址 (PC+4)

    // 送往MEM阶段
    output  reg    [2:0]    mem_op,        // 访存操作类型
    output  reg    [31:0]   mem_addr,      // 访存地址
    output  reg    [31:0]   mem_data,      // 存储数据（Store用）

    // 送往WB阶段 + 旁路
    output  reg    [31:0]   wb_data,       // 写回数据
    output  reg    [4:0]    wb_addr_o,     // 目的寄存器
    output  reg             reg_write_o,   // 写使能

    // 冒险检测：当前是否是 Load 指令
    output  wire            this_inst_is_load
);

// ===================== RISC-V 核心修改 1 =====================
// Load 指令判断（RISC-V：lb,lh,lw,lbu,lhu）
assign this_inst_is_load = (alu_op == 5'b10000) ||  // lb
                            (alu_op == 5'b10001) ||  // lh
                            (alu_op == 5'b10010) ||  // lw
                            (alu_op == 5'b10011) ||  // lbu
                            (alu_op == 5'b10100);    // lhu

// ===================== RISC-V 核心修改 2 =====================
// RISC-V I型立即数生成（符号扩展）：inst[31:20]
wire [31:0] imm_i = {{20{ex_inst[31]}}, ex_inst[31:20]};

// ===================== RISC-V 核心修改 3 =====================
// RISC-V S型立即数生成（Store指令用）：inst[31:25] | inst[11:7]
wire [31:0] imm_s = {{20{ex_inst[31]}}, ex_inst[31:25], ex_inst[11:7]};

// ===================== ALU 运算 & 写回 =====================
always @(*) begin
    if(rst == 1'b0) begin
        reg_write_o = 1'b0;
        wb_addr_o   = 5'b0;
        wb_data     = 32'h0;
    end else begin
        reg_write_o = reg_write;
        wb_addr_o   = wb_addr;
        wb_data     = 32'h0;

        case(alu_op)
            // 算术逻辑运算
            5'b00001: wb_data = reg_1 + reg_2;                // add/addi
            5'b00010: wb_data = reg_1 - reg_2;                // sub
            5'b00011: wb_data = ($signed(reg_1) < $signed(reg_2)) ? 32'd1 : 32'd0;  // slt
            5'b00100: wb_data = (reg_1 < reg_2) ? 32'd1 : 32'd0; // sltu (无符号)
            5'b00101: wb_data = reg_1 & reg_2;                // and/andi
            5'b00110: wb_data = reg_1 | reg_2;                // or/ori
            5'b00111: wb_data = reg_1 ^ reg_2;                // xor/xori
            5'b01000: wb_data = reg_2 << reg_1[4:0];          // sll/slli
            5'b01010: wb_data = reg_2 >> reg_1[4:0];          // srl/srli
            5'b01100: wb_data = $signed(reg_2) >>> reg_1[4:0];// sra/srai
            
            // 跳转指令写回 PC+4
            5'b01111: wb_data = link_addr;                    // jal/jalr
        endcase
    end
end

// ===================== 访存控制（RISC-V Load/Store） =====================
always @(*) begin
    if(rst == 1'b0) begin
        mem_op      = 3'h0;
        mem_addr    = 32'h0;
        mem_data    = 32'h0;
    end else begin
        case(alu_op)
            // RISC-V Load 指令
            5'b10000: begin // lb  字节加载
                mem_op    = 3'b001;
                mem_addr  = reg_1 + imm_i;
                mem_data  = 32'h0;
            end
            5'b10001: begin // lh  半字加载
                mem_op    = 3'b010;
                mem_addr  = reg_1 + imm_i;
                mem_data  = 32'h0;
            end
            5'b10010: begin // lw  字加载
                mem_op    = 3'b011;
                mem_addr  = reg_1 + imm_i;
                mem_data  = 32'h0;
            end
            5'b10011: begin // lbu 无符号字节加载
                mem_op    = 3'b100;
                mem_addr  = reg_1 + imm_i;
                mem_data  = 32'h0;
            end
            5'b10100: begin // lhu 无符号半字加载
                mem_op    = 3'b101;
                mem_addr  = reg_1 + imm_i;
                mem_data  = 32'h0;
            end

            // RISC-V Store 指令（使用 S 型立即数）
            5'b10101: begin // sb  字节存储
                mem_op    = 3'b110;
                mem_addr  = reg_1 + imm_s;
                mem_data  = reg_2;
            end
            5'b10110: begin // sh  半字存储
                mem_op    = 3'b111;
                mem_addr  = reg_1 + imm_s;
                mem_data  = reg_2;
            end
            5'b10111: begin // sw  字存储
                mem_op    = 3'b000; // 自定义编码，保持与mem模块匹配即可
                mem_addr  = reg_1 + imm_s;
                mem_data  = reg_2;
            end

            default: begin
                mem_op      = 3'h0;
                mem_addr    = 32'h0;
                mem_data    = 32'h0;
            end
        endcase
    end
end

endmodule