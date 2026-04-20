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
    output  reg    [31:0]  reg_1,
    output  reg    [31:0]  reg_2,
    
    output  reg            reg_write,
    output  reg    [4:0]   wb_addr,
    output  wire   [31:0]  inst_o,
    
    output  reg            branch,
    output  reg    [31:0]  branch_address_o,
    output  reg    [31:0]  link_address_o,
    
    input   wire            pre_inst_is_load,
    input   wire   [31:0]   ex_mem_load_addr, 
    input   wire            ex_reg_write,
    input   wire   [4:0]    ex_wb_addr,
    input   wire   [31:0]   ex_wb_data,
    
    input   wire            mem_reg_write,  
    input   wire   [4:0]    mem_wb_addr,  
    input   wire   [31:0]   mem_wb_data,  

    output  wire            stallask
);

// ==============================
// RISC-V 指令字段解析（正确）
// ==============================
wire [6:0]  opcode  = id_inst[6:0];
wire [2:0]  funct3  = id_inst[14:12];
wire [6:0]  funct7  = id_inst[31:25];
wire [4:0]  rs1     = id_inst[19:15];
wire [4:0]  rs2     = id_inst[24:20];
wire [4:0]  rd      = id_inst[11:7];

// 立即数扩展（RISC‑V 标准）
wire [31:0] imm_i = {{20{id_inst[31]}}, id_inst[31:20]};
wire [31:0] imm_s = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};
wire [31:0] imm_b = {{19{id_inst[31]}}, id_inst[31], id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
wire [31:0] imm_j = {{11{id_inst[31]}}, id_inst[31], id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
wire [31:0] imm_u = {id_inst[31:12], 12'b0};

reg [31:0] imm_o;
assign inst_o = id_inst;
wire [31:0] pc4 = id_pc + 4;

// ==============================
// 译码主逻辑（RISC‑V 32I）
// ==============================
always @(*) begin
    if(!rst) begin
        alu_op = 0; reg_1_addr=0; re_1=0; reg_2_addr=0; re_2=0;
        reg_write=0; wb_addr=0; imm_o=0;
    end else begin
        alu_op = 0; reg_write=0; imm_o=0;
        reg_1_addr = rs1; re_1 = 1;
        reg_2_addr = rs2; re_2 = 1;
        wb_addr = rd;

        case(opcode)
            7'b0110011: begin // R-type
                reg_write = 1;
                case(funct3)
                    3'b000: alu_op = funct7[5] ? 5'd2 : 5'd1;  // sub / add
                    3'b001: alu_op = 5'd3;  // sll
                    3'b010: alu_op = 5'd4;  // slt
                    3'b100: alu_op = 5'd5;  // xor
                    3'b110: alu_op = 5'd6;  // or
                    3'b111: alu_op = 5'd7;  // and
                    3'b101: alu_op = funct7[5] ? 5'd10 : 5'd9; // sra / srl
                endcase
            end
            
            7'b0010011: begin // I-type ALU
                reg_write = 1; re_2 = 0; imm_o = imm_i;
                case(funct3)
                    3'b000: alu_op = 5'd1;  // addi
                    3'b010: alu_op = 5'd4;  // slti
                    3'b100: alu_op = 5'd5;  // xori
                    3'b110: alu_op = 5'd6;  // ori
                    3'b111: alu_op = 5'd7;  // andi
                    3'b001: alu_op = 5'd3;  // slli
                    3'b101: alu_op = funct7[5] ? 5'd10 : 5'd9; // srai / srli
                endcase
            end
            
            7'b0000011: begin // lw
                reg_write=1; re_2=0; imm_o=imm_i; alu_op=5'd11;
            end
            
            7'b0100011: begin // sw
                re_1=1; re_2=1; imm_o=imm_s; alu_op=5'd12;
            end
            
            7'b1100011: begin // beq / bne / blt / bge
                re_1=1; re_2=1; imm_o=imm_b;
            end
            
            7'b1101111: begin // jal
                reg_write=1; re_1=0; re_2=0; imm_o=imm_j; alu_op=5'd13;
            end
            
            7'b1100111: begin // jalr
                reg_write=1; re_2=0; imm_o=imm_i; alu_op=5'd13;
            end
            
            7'b0110111: begin // lui
                reg_write=1; re_1=0; re_2=0; imm_o=imm_u; alu_op=5'd14;
            end
            
            7'b0010111: begin // auipc
                reg_write=1; re_1=0; re_2=0; imm_o=imm_u; alu_op=5'd15;
            end
        endcase
    end
end

// ==============================
// 分支跳转逻辑（RISC‑V 标准）
// ==============================
always @(*) begin
    if(!rst) begin
        branch=0; branch_address_o=0; link_address_o=0;
    end else begin
        branch=0; branch_address_o=0; link_address_o=0;
        case(opcode)
            7'b1100011: begin
                case(funct3)
                    3'b000: if(reg_1 == reg_2) begin branch=1; branch_address_o=id_pc+imm_b; end
                    3'b001: if(reg_1 != reg_2) begin branch=1; branch_address_o=id_pc+imm_b; end
                    3'b100: if($signed(reg_1) < $signed(reg_2))  begin branch=1; branch_address_o=id_pc+imm_b; end
                    3'b101: if($signed(reg_1) >= $signed(reg_2)) begin branch=1; branch_address_o=id_pc+imm_b; end
                endcase
            end

          
            7'b1101111: begin // jal
                branch=1; branch_address_o=id_pc+imm_j; link_address_o=pc4;
            end
            
            7'b1100111: begin // jalr
                branch=1; branch_address_o=(reg_1+imm_i)&32'hfffffffe; link_address_o=pc4;
            end
        endcase
    end
end

// ==============================
// 前递 & 暂停逻辑（完全保留你原来的！）
// ==============================
reg stallask_from_reg1, stallask_from_reg2;

always @(*) begin
    reg_1 = 0; stallask_from_reg1 = 0;
    if(!rst) reg_1=0;
    else if(pre_inst_is_load && reg_1_addr==ex_wb_addr && re_1) stallask_from_reg1=1;
    else if(re_1 && ex_reg_write && reg_1_addr==ex_wb_addr) reg_1=ex_wb_data;
    else if(mem_reg_write && reg_1_addr==mem_wb_addr) reg_1=mem_wb_data;
    else if(re_1) reg_1=reg_1_data;
    else reg_1=imm_o;
end

always @(*) begin
    reg_2=0; stallask_from_reg2=0;
    if(!rst) reg_2=0;
    else if(pre_inst_is_load && reg_2_addr==ex_wb_addr && re_2) stallask_from_reg2=1;
    else if(re_2 && ex_reg_write && reg_2_addr==ex_wb_addr) reg_2=ex_wb_data;
    else if(mem_reg_write && reg_2_addr==mem_wb_addr) reg_2=mem_wb_data;
    else if(re_2) reg_2=reg_2_data;
    else reg_2=imm_o;
end

assign stallask = rst ? (stallask_from_reg1 | stallask_from_reg2) : 1'b0;

endmodule

