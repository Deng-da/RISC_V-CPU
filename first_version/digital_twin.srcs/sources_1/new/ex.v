`timescale 1ns / 1ps

module ex(
    input   wire            rst,
    input   wire   [4:0]    alu_op,
    input   wire   [31:0]   reg_1,
    input   wire   [31:0]   reg_2,
    input   wire   [4:0]    wb_addr,
    input   wire            reg_write,
    input   wire   [31:0]   ex_inst,
    input   wire   [31:0]   ex_pc,
    input   wire   [31:0]   link_addr,

    output  reg    [2:0]    mem_op,
    output  reg    [31:0]   mem_addr,
    output  reg    [31:0]   mem_data,

    output  reg    [31:0]   wb_data,
    output  reg    [4:0]    wb_addr_o,
    output  reg             reg_write_o,

    output  wire            this_inst_is_load
);

localparam [4:0] ALU_ADD       = 5'd1;
localparam [4:0] ALU_SUB       = 5'd2;
localparam [4:0] ALU_SLT       = 5'd3;
localparam [4:0] ALU_SLTU      = 5'd4;
localparam [4:0] ALU_AND       = 5'd5;
localparam [4:0] ALU_OR        = 5'd6;
localparam [4:0] ALU_XOR       = 5'd7;
localparam [4:0] ALU_SLL       = 5'd8;
localparam [4:0] ALU_SRL       = 5'd10;
localparam [4:0] ALU_SRA       = 5'd12;
localparam [4:0] ALU_LINK      = 5'd15;
localparam [4:0] ALU_LB        = 5'd16;
localparam [4:0] ALU_LH        = 5'd17;
localparam [4:0] ALU_LW        = 5'd18;
localparam [4:0] ALU_LBU       = 5'd19;
localparam [4:0] ALU_LHU       = 5'd20;
localparam [4:0] ALU_SB        = 5'd21;
localparam [4:0] ALU_SH        = 5'd22;
localparam [4:0] ALU_SW        = 5'd23;
localparam [4:0] ALU_LUI       = 5'd24;
localparam [4:0] ALU_AUIPC     = 5'd25;

assign this_inst_is_load = (alu_op == ALU_LB)  ||
                           (alu_op == ALU_LH)  ||
                           (alu_op == ALU_LW)  ||
                           (alu_op == ALU_LBU) ||
                           (alu_op == ALU_LHU);

wire [31:0] imm_i = {{20{ex_inst[31]}}, ex_inst[31:20]};
wire [31:0] imm_s = {{20{ex_inst[31]}}, ex_inst[31:25], ex_inst[11:7]};

always @(*) begin
    if (rst == 1'b1) begin
        reg_write_o = 1'b0;
        wb_addr_o   = 5'b0;
        wb_data     = 32'h0;
    end else begin
        reg_write_o = reg_write;
        wb_addr_o   = wb_addr;
        wb_data     = 32'h0;

        case (alu_op)
            ALU_ADD:   wb_data = reg_1 + reg_2;
            ALU_SUB:   wb_data = reg_1 - reg_2;
            ALU_SLT:   wb_data = ($signed(reg_1) < $signed(reg_2)) ? 32'd1 : 32'd0;
            ALU_SLTU:  wb_data = (reg_1 < reg_2) ? 32'd1 : 32'd0;
            ALU_AND:   wb_data = reg_1 & reg_2;
            ALU_OR:    wb_data = reg_1 | reg_2;
            ALU_XOR:   wb_data = reg_1 ^ reg_2;
            ALU_SLL:   wb_data = reg_1 << reg_2[4:0];
            ALU_SRL:   wb_data = reg_1 >> reg_2[4:0];
            ALU_SRA:   wb_data = $signed(reg_1) >>> reg_2[4:0];
            ALU_LINK:  wb_data = link_addr;
            ALU_LUI:   wb_data = reg_1;
            ALU_AUIPC: wb_data = ex_pc + reg_1;
            default:   wb_data = 32'h0;
        endcase
    end
end

always @(*) begin
    if (rst == 1'b1) begin
        mem_op   = 3'h0;
        mem_addr = 32'h0;
        mem_data = 32'h0;
    end else begin
        case (alu_op)
            ALU_LB: begin
                mem_op   = 3'b001;
                mem_addr = reg_1 + imm_i;
                mem_data = 32'h0;
            end
            ALU_LH: begin
                mem_op   = 3'b010;
                mem_addr = reg_1 + imm_i;
                mem_data = 32'h0;
            end
            ALU_LW: begin
                mem_op   = 3'b011;
                mem_addr = reg_1 + imm_i;
                mem_data = 32'h0;
            end
            ALU_LBU: begin
                mem_op   = 3'b100;
                mem_addr = reg_1 + imm_i;
                mem_data = 32'h0;
            end
            ALU_LHU: begin
                mem_op   = 3'b101;
                mem_addr = reg_1 + imm_i;
                mem_data = 32'h0;
            end
            ALU_SB: begin
                mem_op   = 3'b110;
                mem_addr = reg_1 + imm_s;
                mem_data = reg_2;
            end
            ALU_SH: begin
                mem_op   = 3'b111;
                mem_addr = reg_1 + imm_s;
                mem_data = reg_2;
            end
            ALU_SW: begin
                mem_op   = 3'b000;
                mem_addr = reg_1 + imm_s;
                mem_data = reg_2;
            end
            default: begin
                mem_op   = 3'h0;
                mem_addr = 32'h0;
                mem_data = 32'h0;
            end
        endcase
    end
end

endmodule
