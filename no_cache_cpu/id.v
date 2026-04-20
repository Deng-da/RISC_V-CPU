`timescale 1ns / 1ps

module id(
    input   wire           rst,          // 高有效复位（比赛标准）
    
    input   wire   [31:0]  id_pc,
    input   wire   [31:0]  id_inst,

// 从 reg_file 获取的数据
    input   wire   [31:0]  reg_1_data,
    input   wire   [31:0]  reg_2_data,
    
// 传往 reg_file
    output  reg    [4:0]   reg_1_addr,
    output  reg            re_1,
    output  reg    [4:0]   reg_2_addr,
    output  reg            re_2,
  
// 传往 EX
    output  reg    [4:0]   alu_op,
    output  reg    [31:0]  reg_1,
    output  reg    [31:0]  reg_2,
    output  reg            reg_write,
    output  reg    [4:0]   wb_addr,
    output  wire   [31:0]  inst_o,
    
// 分支跳转
    output  reg            branch,
    output  reg    [31:0]  branch_address_o,
    output  reg    [31:0]  link_address_o,
    
// EX 阶段前递
    input   wire           pre_inst_is_load,
    input   wire   [4:0]   ex_wb_addr,
    input   wire   [31:0]  ex_wb_data,
    input   wire           ex_reg_write,
    
// MEM 阶段前递
    input   wire           mem_reg_write,
    input   wire   [4:0]   mem_wb_addr,
    input   wire   [31:0]  mem_wb_data,

// 暂停请求
    output  wire           stallask
);

// RV32I 指令字段
wire [6:0]  opcode  = id_inst[6:0];
wire [2:0]  funct3  = id_inst[14:12];
wire [6:0]  funct7  = id_inst[31:25];
wire [4:0]  rs1     = id_inst[19:15];
wire [4:0]  rs2     = id_inst[24:20];
wire [4:0]  rd      = id_inst[11:7];

// RV32I 立即数生成
wire [31:0] imm_i = {{20{id_inst[31]}}, id_inst[31:20]};
wire [31:0] imm_s = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};
wire [31:0] imm_b = {{19{id_inst[31]}}, id_inst[31], id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
wire [31:0] imm_j = {{11{id_inst[31]}}, id_inst[31], id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
wire [31:0] imm_u = {id_inst[31:12], 12'b0};

reg [31:0]  imm_o;
assign inst_o = id_inst;
wire [31:0] next_pc = id_pc + 32'd4;

//============================================================
// RV32I 指令译码（比赛标准）
//============================================================
always @(*) begin
    if(rst == 1'b1) begin  // 高有效复位
        alu_op      = 5'h0;
        reg_1_addr  = 5'h0;
        re_1        = 1'b0;
        reg_2_addr  = 5'h0;
        re_2        = 1'b0;
        reg_write   = 1'b0;
        wb_addr     = 5'h0;
        imm_o       = 32'h0;
    end
    else begin
        // 默认值
        alu_op      = 5'h0;
        reg_1_addr  = rs1;
        re_1        = 1'b1;
        reg_2_addr  = rs2;
        re_2        = 1'b1;
        reg_write   = 1'b0;
        wb_addr     = rd;
        imm_o       = 32'h0;

        case(opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                case(funct3)
                    3'b000: alu_op = funct7[5] ? 5'd2  : 5'd1;  // sub / add
                    3'b001: alu_op = 5'd3;                     // sll
                    3'b010: alu_op = 5'd4;                     // slt
                    3'b011: alu_op = 5'd8;                     // sltu
                    3'b100: alu_op = 5'd5;                     // xor
                    3'b101: alu_op = funct7[5] ? 5'd10 : 5'd9; // sra / srl
                    3'b110: alu_op = 5'd6;                     // or
                    3'b111: alu_op = 5'd7;                     // and
                endcase
            end

            7'b0010011: begin // I-type 运算
                reg_write = 1'b1;
                re_2 = 1'b0;
                imm_o = imm_i;
                case(funct3)
                    3'b000: alu_op = 5'd1;  // addi
                    3'b010: alu_op = 5'd4;  // slti
                    3'b011: alu_op = 5'd8;  // sltiu
                    3'b100: alu_op = 5'd5;  // xori
                    3'b110: alu_op = 5'd6;  // ori
                    3'b111: alu_op = 5'd7;  // andi
                    3'b001: alu_op = 5'd3;  // slli
                    3'b101: alu_op = funct7[5] ? 5'd10 : 5'd9; // srai / srli
                endcase
            end

            7'b0000011: begin // load
                reg_write = 1'b1;
                re_2 = 1'b0;
                imm_o = imm_i;
                alu_op = 5'd11;
            end

            7'b0100011: begin // store
                re_1 = 1'b1;
                re_2 = 1'b1;
                imm_o = imm_s;
                alu_op = 5'd12;
            end

            7'b1100011: begin // branch
                re_1 = 1'b1;
                re_2 = 1'b1;
                imm_o = imm_b;
            end

            7'b1101111: begin // jal
                reg_write = 1'b1;
                re_1 = 1'b0;
                re_2 = 1'b0;
                imm_o = imm_j;
                alu_op = 5'd13;
            end

            7'b1100111: begin // jalr
                reg_write = 1'b1;
                re_2 = 1'b0;
                imm_o = imm_i;
                alu_op = 5'd13;
            end

            7'b0110111: begin // lui
                reg_write = 1'b1;
                re_1 = 1'b0;
                re_2 = 1'b0;
                imm_o = imm_u;
                alu_op = 5'd14;
            end

            7'b0010111: begin // auipc
                reg_write = 1'b1;
                re_1 = 1'b0;
                re_2 = 1'b0;
                imm_o = imm_u;
                alu_op = 5'd15;
            end
        endcase
    end
end

//============================================================
// 分支 / 跳转逻辑（RV32I 标准）
//============================================================
always @(*) begin
    if(rst == 1'b1) begin
        branch           = 1'b0;
        branch_address_o = 32'h0;
        link_address_o   = 32'h0;
    end
    else begin
        branch           = 1'b0;
        branch_address_o = 32'h0;
        link_address_o   = 32'h0;

        case(opcode)
            7'b1100011: begin // B-type
                case(funct3)
                    3'b000: branch = (reg_1 == reg_2);
                    3'b001: branch = (reg_1 != reg_2);
                    3'b100: branch = ($signed(reg_1) < $signed(reg_2));
                    3'b101: branch = ($signed(reg_1) >= $signed(reg_2));
                    3'b110: branch = (reg_1 < reg_2);
                    3'b111: branch = (reg_1 >= reg_2);
                endcase
                if(branch) branch_address_o = id_pc + imm_b;
            end

            7'b1101111: begin // jal
                branch           = 1'b1;
                branch_address_o = id_pc + imm_j;
                link_address_o   = next_pc;
            end

            7'b1100111: begin // jalr
                branch           = 1'b1;
                branch_address_o = (reg_1 + imm_i) & 32'hfffffffe;
                link_address_o   = next_pc;
            end
        endcase
    end
end

//============================================================
// 操作数 1 选择 + 冒险检测
//============================================================
reg stallask_from_reg1;
always @(*) begin
    reg_1             = 32'h0;
    stallask_from_reg1 = 1'b0;

    if(rst == 1'b1) begin
        reg_1 = 32'h0;
        stallask_from_reg1 = 1'b0;
    end
    else if(pre_inst_is_load && (reg_1_addr == ex_wb_addr) && re_1) begin
        stallask_from_reg1 = 1'b1;
    end
    else if(re_1 && ex_reg_write && (reg_1_addr == ex_wb_addr)) begin
        reg_1 = ex_wb_data;
    end
    else if(mem_reg_write && (reg_1_addr == mem_wb_addr)) begin
        reg_1 = mem_wb_data;
    end
    else if(re_1) begin
        reg_1 = reg_1_data;
    end
    else begin
        reg_1 = imm_o;
    end
end

//============================================================
// 操作数 2 选择 + 冒险检测
//============================================================
reg stallask_from_reg2;
always @(*) begin
    reg_2             = 32'h0;
    stallask_from_reg2 = 1'b0;

    if(rst == 1'b1) begin
        reg_2 = 32'h0;
        stallask_from_reg2 = 1'b0;
    end
    else if(pre_inst_is_load && (reg_2_addr == ex_wb_addr) && re_2) begin
        stallask_from_reg2 = 1'b1;
    end
    else if(re_2 && ex_reg_write && (reg_2_addr == ex_wb_addr)) begin
        reg_2 = ex_wb_data;
    end
    else if(mem_reg_write && (reg_2_addr == mem_wb_addr)) begin
        reg_2 = mem_wb_data;
    end
    else if(re_2) begin
        reg_2 = reg_2_data;
    end
    else begin
        reg_2 = imm_o;
    end
end

assign stallask = ~rst & (stallask_from_reg1 | stallask_from_reg2);

endmodule