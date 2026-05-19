`timescale 1ns / 1ps

module ex(
    input   wire            rst,
    input   wire   [4:0]    alu_op,
    input   wire   [3:0]    mem_op_i,
    input   wire   [31:0]   reg_1,
    input   wire   [31:0]   reg_2,
    input   wire   [31:0]   store_data,
    input   wire   [4:0]    wb_addr,
    input   wire            reg_write,
    input   wire   [31:0]   ex_inst,
    input   wire   [31:0]   ex_pc,
    input   wire   [31:0]   link_addr,

    output  reg    [3:0]    mem_op,
    output  reg    [31:0]   mem_addr,
    output  reg    [31:0]   mem_data,

    output  reg    [31:0]   wb_data,
    output  reg    [4:0]    wb_addr_o,
    output  reg             reg_write_o
);

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

reg [31:0] alu_result;

always @(*) begin
    if (rst == 1'b1) begin
        alu_result  = 32'h0;
        reg_write_o = 1'b0;
        wb_addr_o   = 5'b0;
        wb_data     = 32'h0;
    end else begin
        reg_write_o = reg_write;
        wb_addr_o   = wb_addr;
        alu_result  = 32'h0;

        case (alu_op)
            ALU_ADD:   alu_result = reg_1 + reg_2;
            ALU_SUB:   alu_result = reg_1 - reg_2;
            ALU_SLT:   alu_result = ($signed(reg_1) < $signed(reg_2)) ? 32'd1 : 32'd0;
            ALU_SLTU:  alu_result = (reg_1 < reg_2) ? 32'd1 : 32'd0;
            ALU_AND:   alu_result = reg_1 & reg_2;
            ALU_OR:    alu_result = reg_1 | reg_2;
            ALU_XOR:   alu_result = reg_1 ^ reg_2;
            ALU_SLL:   alu_result = reg_1 << reg_2[4:0];
            ALU_SRL:   alu_result = reg_1 >> reg_2[4:0];
            ALU_SRA:   alu_result = $signed(reg_1) >>> reg_2[4:0];
            ALU_LINK:  alu_result = link_addr;
            ALU_LUI:   alu_result = reg_1;
            ALU_AUIPC: alu_result = ex_pc + reg_1;
            default:   alu_result = 32'h0;
        endcase

        wb_data = alu_result;
    end
end

always @(*) begin
    if (rst == 1'b1) begin
        mem_op   = MEM_NONE;
        mem_addr = 32'h0;
        mem_data = 32'h0;
    end else begin
        mem_op   = mem_op_i;
        mem_addr = (mem_op_i == MEM_NONE) ? 32'h0 : alu_result;
        mem_data = store_data;
    end
end

endmodule
