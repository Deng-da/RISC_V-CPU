`timescale 1ns / 1ps

// EX阶段：执行ALU运算、生成访存请求、输出写回信息
module ex(
    // 来自ID/EX流水寄存器的输入
    input    wire            rst,
    input    wire   [4:0]    alu_op,
    input    wire   [31:0]   reg_1,
    input    wire   [31:0]   reg_2, 
    input    wire   [4:0]    wb_addr,
    input    wire            reg_write,
    input    wire   [31:0]   ex_inst,
    input    wire   [31:0]   ex_pc,
    input    wire   [31:0]   link_addr,

    // 送往MEM阶段的信息
    output   reg    [2:0]    mem_op,        
    output   reg    [31:0]   mem_addr,        
    output   reg    [31:0]   mem_data,

    // 送往WB阶段的信息（同时可旁路到ID阶段）
    output   reg    [31:0]   wb_data,        
    output   reg    [4:0]    wb_addr_o,        
    output   reg             reg_write_o,        

    // 当前EX指令是否为load，用于load-use冒险检测
    output   wire            this_inst_is_load

    );

    // lb/lw会在MEM阶段取数，需标记为load指令
    assign this_inst_is_load = (alu_op == 5'b01011) || (alu_op == 5'b01110);//lb和lw指令


    // ALU运算与写回数据生成
    // rst==0时清空输出，避免无效写回
    always @(*)begin
        if(rst==1'b0)begin
            reg_write_o    = 1'b0;
            wb_addr_o      = 32'h0;
            wb_data        = 32'h0;
        end
        else begin
            reg_write_o    = reg_write;
            wb_addr_o      = wb_addr;
            wb_data        = 32'h0;
        end

        // 根据alu_op选择算术/逻辑/移位/链接地址写回结果
        case(alu_op)
            5'b00001: wb_data = reg_1 + reg_2;//add操作 
            5'b00010: wb_data = reg_1 - reg_2;//sub操作
            5'b00011: wb_data = ($signed(reg_1) < $signed(reg_2)) ? 1 : 0;//slt操作
            5'b00100: wb_data = reg_1 * reg_2;//mul操作
            5'b00101: wb_data = reg_1 & reg_2;//and操作
            5'b00110: wb_data = reg_1 | reg_2;//or操作
            5'b00111: wb_data = reg_1 ^ reg_2;//xor操作
            5'b01000: wb_data = reg_2 << reg_1[4:0];//sll操作
            5'b01010: wb_data = reg_2 >> reg_1[4:0];//srl操作
            5'b01100: wb_data = ($signed(reg_2)) >>> reg_1[4:0];//sra操作
            5'b01111: wb_data = link_addr;//jal操作
        endcase
    end

    // I型访存指令立即数符号扩展（base + offset）
    wire [31:0]  imm_s = {{16{ex_inst[15]}},ex_inst[15:0]}; 


    // 访存控制信号与地址/写数据生成
    // 非访存指令时输出清零
    always @(*)begin
        if(rst==1'b0)begin
            mem_op      = 3'h0;
            mem_addr    = 32'h0;
            mem_data    = 32'h0;
        end 
        else begin
            case(alu_op)
                5'b01011:begin//lb
                    // 字节读：地址=rs+offset，写数据无效
                    mem_op    = 3'b001;
                    mem_addr  = reg_1 + imm_s;
                    mem_data  = 32'h0;
                end
                5'b01110:begin//lw
                    // 字读：地址=rs+offset，写数据无效
                    mem_op    = 3'b010;
                    mem_addr  = reg_1 + imm_s;
                    mem_data  = 32'h0;
                end
                5'b01101:begin//sb
                    // 字节写：地址=rs+offset，写入rt低8位由MEM阶段处理
                    mem_op    = 3'b011;
                    mem_addr  = reg_1 + imm_s;
                    mem_data  = reg_2;
                end
                5'b01001:begin//sw
                    // 字写：地址=rs+offset，写入rt全32位
                    mem_op    = 3'b100;
                    mem_addr  = reg_1 + imm_s;
                    mem_data  = reg_2;
                end
                default:begin
                    mem_op      = 3'h0;
                    mem_addr    = 32'h0;
                    mem_data    = 32'h0;
                end
            endcase
        end

    end


endmodule
