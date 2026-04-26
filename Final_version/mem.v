`timescale 1ns / 1ps

module mem(
    input    wire            rst,
    input    wire   [31:0]   mem_pc,
    input    wire            mem_reg_write,
    input    wire   [4:0]    mem_wb_addr,
    input    wire   [31:0]   mem_wb_data,
    input    wire   [3:0]    mem_op,
    input    wire   [31:0]   mem_addr,
    input    wire   [31:0]   mem_data,

    input    wire   [31:0]   ram_data,

    output   reg             reg_write,
    output   reg    [4:0]    wb_addr,
    output   reg    [31:0]   wb_data,

    output   reg    [31:0]   mem_addr_o,
    output   reg    [31:0]   mem_data_o,
    output   reg             mem_we_n,
    output   reg    [3:0]    mem_sel_n,
    output   reg             mem_ce
);

localparam [3:0] MEM_NONE = 4'd0;
localparam [3:0] MEM_LB   = 4'd1;
localparam [3:0] MEM_LH   = 4'd2;
localparam [3:0] MEM_LW   = 4'd3;
localparam [3:0] MEM_LBU  = 4'd4;
localparam [3:0] MEM_LHU  = 4'd5;
localparam [3:0] MEM_SB   = 4'd6;
localparam [3:0] MEM_SH   = 4'd7;
localparam [3:0] MEM_SW   = 4'd8;

localparam [31:0] DRAM_START  = 32'h8010_0000;
localparam [31:0] DRAM_END    = 32'h8013_FFFF;
localparam [31:0] PERIP_START = 32'h8020_0000;
localparam [31:0] PERIP_END   = 32'h8020_00FF;

wire addr_is_dram      = (mem_addr >= DRAM_START)  && (mem_addr <= DRAM_END);
wire addr_is_perip     = (mem_addr >= PERIP_START) && (mem_addr <= PERIP_END);
wire addr_word_aligned = (mem_addr[1:0] == 2'b00);

reg [7:0]  lb_byte;
reg [15:0] lh_half;

always @(*) begin
    if (rst == 1'b1) begin
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
        reg_write  = mem_reg_write;
        wb_addr    = mem_wb_addr;
        wb_data    = mem_wb_data;
        mem_addr_o = mem_addr;
        mem_data_o = 32'h0;
        mem_we_n   = 1'b1;
        mem_sel_n  = 4'b1111;
        mem_ce     = 1'b1;
        lb_byte    = 8'h0;
        lh_half    = 16'h0;

        case (mem_op)
            MEM_LB: begin
                if (addr_is_dram) begin
                    mem_ce = 1'b0;
                    case (mem_addr[1:0])
                        2'b00: begin mem_sel_n = 4'b1110; lb_byte = ram_data[7:0];   end
                        2'b01: begin mem_sel_n = 4'b1101; lb_byte = ram_data[15:8];  end
                        2'b10: begin mem_sel_n = 4'b1011; lb_byte = ram_data[23:16]; end
                        2'b11: begin mem_sel_n = 4'b0111; lb_byte = ram_data[31:24]; end
                    endcase
                    wb_data = {{24{lb_byte[7]}}, lb_byte};
                end
            end

            MEM_LH: begin
                if (addr_is_dram) begin
                    mem_ce = 1'b0;
                    case (mem_addr[1])
                        1'b0: begin mem_sel_n = 4'b1100; lh_half = ram_data[15:0];  end
                        1'b1: begin mem_sel_n = 4'b0011; lh_half = ram_data[31:16]; end
                    endcase
                    wb_data = {{16{lh_half[15]}}, lh_half};
                end
            end

            MEM_LW: begin
                if (addr_is_dram || (addr_is_perip && addr_word_aligned)) begin
                    mem_ce    = 1'b0;
                    mem_sel_n = 4'b0000;
                    wb_data   = ram_data;
                end
            end

            MEM_LBU: begin
                if (addr_is_dram) begin
                    mem_ce = 1'b0;
                    case (mem_addr[1:0])
                        2'b00: begin mem_sel_n = 4'b1110; lb_byte = ram_data[7:0];   end
                        2'b01: begin mem_sel_n = 4'b1101; lb_byte = ram_data[15:8];  end
                        2'b10: begin mem_sel_n = 4'b1011; lb_byte = ram_data[23:16]; end
                        2'b11: begin mem_sel_n = 4'b0111; lb_byte = ram_data[31:24]; end
                    endcase
                    wb_data = {24'h0, lb_byte};
                end
            end

            MEM_LHU: begin
                if (addr_is_dram) begin
                    mem_ce = 1'b0;
                    case (mem_addr[1])
                        1'b0: begin mem_sel_n = 4'b1100; lh_half = ram_data[15:0];  end
                        1'b1: begin mem_sel_n = 4'b0011; lh_half = ram_data[31:16]; end
                    endcase
                    wb_data = {16'h0, lh_half};
                end
            end

            MEM_SB: begin
                if (addr_is_dram) begin
                    mem_ce   = 1'b0;
                    mem_we_n = 1'b0;
                    case (mem_addr[1:0])
                        2'b00: begin mem_sel_n = 4'b1110; mem_data_o = {24'h0, mem_data[7:0]};      end
                        2'b01: begin mem_sel_n = 4'b1101; mem_data_o = {16'h0, mem_data[7:0], 8'h0}; end
                        2'b10: begin mem_sel_n = 4'b1011; mem_data_o = {8'h0, mem_data[7:0], 16'h0};  end
                        2'b11: begin mem_sel_n = 4'b0111; mem_data_o = {mem_data[7:0], 24'h0};        end
                    endcase
                    wb_data = 32'h0;
                end
            end

            MEM_SH: begin
                if (addr_is_dram) begin
                    mem_ce   = 1'b0;
                    mem_we_n = 1'b0;
                    case (mem_addr[1])
                        1'b0: begin mem_sel_n = 4'b1100; mem_data_o = {16'h0, mem_data[15:0]}; end
                        1'b1: begin mem_sel_n = 4'b0011; mem_data_o = {mem_data[15:0], 16'h0}; end
                    endcase
                    wb_data = 32'h0;
                end
            end

            MEM_SW: begin
                if ((addr_is_dram && addr_word_aligned) || (addr_is_perip && addr_word_aligned)) begin
                    mem_ce     = 1'b0;
                    mem_we_n   = 1'b0;
                    mem_sel_n  = 4'b0000;
                    mem_data_o = mem_data;
                    wb_data    = 32'h0;
                end
            end

            default: begin
            end
        endcase
    end
end

endmodule
