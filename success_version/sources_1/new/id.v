`timescale 1ns / 1ps

module id(
    input   wire           rst,
    input   wire   [31:0]  id_pc,
    input   wire   [31:0]  id_inst,

    input   wire   [31:0]  reg_1_data,
    input   wire   [31:0]  reg_2_data,

    output  reg    [4:0]   reg_1_addr,
    output  reg            re_1,
    output  reg    [4:0]   reg_2_addr,
    output  reg            re_2,

    output  reg    [4:0]   alu_op,
    output  reg    [3:0]   mem_op,
    output  reg    [31:0]  reg_1,
    output  reg    [31:0]  reg_2,
    output  reg    [31:0]  store_data,
    output  reg            reg_write,
    output  reg    [4:0]   wb_addr,
    output  reg            is_load,
    output  wire   [31:0]  inst_o,

    output  reg            branch,
    output  reg    [31:0]  branch_address_o,
    output  reg    [31:0]  link_address_o,

    input   wire           pre_inst_is_load,
    input   wire   [4:0]   ex_wb_addr,
    input   wire   [31:0]  ex_wb_data,
    input   wire           ex_reg_write,

    input   wire           mem_reg_write,
    input   wire   [4:0]   mem_wb_addr,
    input   wire   [31:0]  mem_wb_data,

    output  wire           stallask
);

localparam [4:0] ALU_NOP   = 5'd0;
localparam [4:0] ALU_ADD   = 5'd1;
localparam [4:0] ALU_SUB   = 5'd2;
localparam [4:0] ALU_SLT   = 5'd3;
localparam [4:0] ALU_SLTU  = 5'd4;
localparam [4:0] ALU_AND   = 5'd5;
localparam [4:0] ALU_OR    = 5'd6;
localparam [4:0] ALU_XOR   = 5'd7;
localparam [4:0] ALU_SLL   = 5'd8;
localparam [4:0] ALU_SRL   = 5'd10;
localparam [4:0] ALU_SRA   = 5'd12;
localparam [4:0] ALU_LINK  = 5'd15;
localparam [4:0] ALU_LUI   = 5'd24;
localparam [4:0] ALU_AUIPC = 5'd25;

localparam [3:0] MEM_NONE = 4'd0;
localparam [3:0] MEM_LB   = 4'd1;
localparam [3:0] MEM_LH   = 4'd2;
localparam [3:0] MEM_LW   = 4'd3;
localparam [3:0] MEM_LBU  = 4'd4;
localparam [3:0] MEM_LHU  = 4'd5;
localparam [3:0] MEM_SB   = 4'd6;
localparam [3:0] MEM_SH   = 4'd7;
localparam [3:0] MEM_SW   = 4'd8;

wire [6:0] opcode = id_inst[6:0];
wire [2:0] funct3 = id_inst[14:12];
wire [6:0] funct7 = id_inst[31:25];
wire [4:0] rs1    = id_inst[19:15];
wire [4:0] rs2    = id_inst[24:20];
wire [4:0] rd     = id_inst[11:7];

wire [31:0] imm_i = {{20{id_inst[31]}}, id_inst[31:20]};
wire [31:0] imm_s = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};
wire [31:0] imm_b = {{19{id_inst[31]}}, id_inst[31], id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
wire [31:0] imm_j = {{11{id_inst[31]}}, id_inst[31], id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
wire [31:0] imm_u = {id_inst[31:12], 12'b0};

reg [31:0] imm_o;
reg        op2_is_imm;
reg        stallask_from_reg1;
reg        stallask_from_reg2;

wire [31:0] next_pc = id_pc + 32'd4;
assign inst_o = id_inst;

always @(*) begin
    if (rst == 1'b1) begin
        alu_op     = ALU_NOP;
        mem_op     = MEM_NONE;
        reg_1_addr = 5'h0;
        re_1       = 1'b0;
        reg_2_addr = 5'h0;
        re_2       = 1'b0;
        reg_write  = 1'b0;
        wb_addr    = 5'h0;
        is_load    = 1'b0;
        imm_o      = 32'h0;
        op2_is_imm = 1'b0;
    end else begin
        alu_op     = ALU_NOP;
        mem_op     = MEM_NONE;
        reg_1_addr = rs1;
        re_1       = 1'b1;
        reg_2_addr = rs2;
        re_2       = 1'b1;
        reg_write  = 1'b0;
        wb_addr    = rd;
        is_load    = 1'b0;
        imm_o      = 32'h0;
        op2_is_imm = 1'b0;

        case (opcode)
            7'b0110011: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: begin
                        reg_write = 1'b0;
                        alu_op    = ALU_NOP;
                    end
                endcase
            end

            7'b0010011: begin
                reg_write  = 1'b1;
                re_2       = 1'b0;
                op2_is_imm = 1'b1;
                imm_o      = imm_i;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
                    default: begin
                        reg_write = 1'b0;
                        alu_op    = ALU_NOP;
                    end
                endcase
            end

            7'b0000011: begin
                reg_write  = 1'b1;
                re_2       = 1'b0;
                op2_is_imm = 1'b1;
                imm_o      = imm_i;
                alu_op     = ALU_ADD;
                is_load    = 1'b1;
                case (funct3)
                    3'b000: mem_op = MEM_LB;
                    3'b001: mem_op = MEM_LH;
                    3'b010: mem_op = MEM_LW;
                    3'b100: mem_op = MEM_LBU;
                    3'b101: mem_op = MEM_LHU;
                    default: begin
                        reg_write = 1'b0;
                        is_load   = 1'b0;
                        mem_op    = MEM_NONE;
                    end
                endcase
            end

            7'b0100011: begin
                re_1       = 1'b1;
                re_2       = 1'b1;
                op2_is_imm = 1'b1;
                imm_o      = imm_s;
                alu_op     = ALU_ADD;
                case (funct3)
                    3'b000: mem_op = MEM_SB;
                    3'b001: mem_op = MEM_SH;
                    3'b010: mem_op = MEM_SW;
                    default: mem_op = MEM_NONE;
                endcase
            end

            7'b1100011: begin
                re_1  = 1'b1;
                re_2  = 1'b1;
                imm_o = imm_b;
            end

            7'b1101111: begin
                reg_write = 1'b1;
                re_1      = 1'b0;
                re_2      = 1'b0;
                imm_o     = imm_j;
                alu_op    = ALU_LINK;
            end

            7'b1100111: begin
                reg_write  = 1'b1;
                re_2       = 1'b0;
                op2_is_imm = 1'b1;
                imm_o      = imm_i;
                alu_op     = ALU_LINK;
            end

            7'b0110111: begin
                reg_write = 1'b1;
                re_1      = 1'b0;
                re_2      = 1'b0;
                imm_o     = imm_u;
                alu_op    = ALU_LUI;
            end

            7'b0010111: begin
                reg_write = 1'b1;
                re_1      = 1'b0;
                re_2      = 1'b0;
                imm_o     = imm_u;
                alu_op    = ALU_AUIPC;
            end

            default: begin
                alu_op     = ALU_NOP;
                mem_op     = MEM_NONE;
                reg_write  = 1'b0;
                wb_addr    = 5'h0;
                re_1       = 1'b0;
                re_2       = 1'b0;
                is_load    = 1'b0;
                imm_o      = 32'h0;
                op2_is_imm = 1'b0;
            end
        endcase
    end
end

always @(*) begin
    if (rst == 1'b1 || stallask_from_reg1 || stallask_from_reg2) begin
        branch           = 1'b0;
        branch_address_o = 32'h0;
        link_address_o   = 32'h0;
    end else begin
        branch           = 1'b0;
        branch_address_o = 32'h0;
        link_address_o   = 32'h0;

        case (opcode)
            7'b1100011: begin
                case (funct3)
                    3'b000: branch = (reg_1 == store_data);
                    3'b001: branch = (reg_1 != store_data);
                    3'b100: branch = ($signed(reg_1) <  $signed(store_data));
                    3'b101: branch = ($signed(reg_1) >= $signed(store_data));
                    3'b110: branch = (reg_1 <  store_data);
                    3'b111: branch = (reg_1 >= store_data);
                    default: branch = 1'b0;
                endcase
                if (branch) begin
                    branch_address_o = id_pc + imm_b;
                end
            end

            7'b1101111: begin
                branch           = 1'b1;
                branch_address_o = id_pc + imm_j;
                link_address_o   = next_pc;
            end

            7'b1100111: begin
                branch           = 1'b1;
                branch_address_o = (reg_1 + imm_i) & 32'hffff_fffe;
                link_address_o   = next_pc;
            end

            default: begin
                branch           = 1'b0;
                branch_address_o = 32'h0;
                link_address_o   = 32'h0;
            end
        endcase
    end
end

always @(*) begin
    reg_1              = 32'h0;
    stallask_from_reg1 = 1'b0;

    if (rst == 1'b1) begin
        reg_1              = 32'h0;
        stallask_from_reg1 = 1'b0;
    end else if (pre_inst_is_load && re_1 && (reg_1_addr != 5'h0) && (reg_1_addr == ex_wb_addr)) begin
        stallask_from_reg1 = 1'b1;
    end else if (re_1 && ex_reg_write && (ex_wb_addr != 5'h0) && (reg_1_addr == ex_wb_addr)) begin
        reg_1 = ex_wb_data;
    end else if (re_1 && mem_reg_write && (mem_wb_addr != 5'h0) && (reg_1_addr == mem_wb_addr)) begin
        reg_1 = mem_wb_data;
    end else if (re_1) begin
        reg_1 = reg_1_data;
    end else begin
        reg_1 = imm_o;
    end
end

always @(*) begin
    reg_2              = 32'h0;
    store_data         = 32'h0;
    stallask_from_reg2 = 1'b0;

    if (rst == 1'b1) begin
        reg_2              = 32'h0;
        store_data         = 32'h0;
        stallask_from_reg2 = 1'b0;
    end else if (pre_inst_is_load && re_2 && (reg_2_addr != 5'h0) && (reg_2_addr == ex_wb_addr)) begin
        stallask_from_reg2 = 1'b1;
    end else begin
        if (re_2 && ex_reg_write && (ex_wb_addr != 5'h0) && (reg_2_addr == ex_wb_addr)) begin
            store_data = ex_wb_data;
        end else if (re_2 && mem_reg_write && (mem_wb_addr != 5'h0) && (reg_2_addr == mem_wb_addr)) begin
            store_data = mem_wb_data;
        end else if (re_2) begin
            store_data = reg_2_data;
        end else begin
            store_data = 32'h0;
        end

        reg_2 = op2_is_imm ? imm_o : store_data;
    end
end

assign stallask = ~rst & (stallask_from_reg1 | stallask_from_reg2);

endmodule
