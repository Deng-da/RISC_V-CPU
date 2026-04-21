`timescale 1ns / 1ps

module ex_mem(
    input    wire            clk,
    input    wire            rst,
    input    wire   [31:0]   ex_pc,
    input    wire            ex_reg_write,
    input    wire   [4:0]    ex_wb_addr,
    input    wire   [31:0]   ex_wb_data,
    input    wire   [2:0]    ex_mem_op,
    input    wire   [31:0]   ex_mem_addr,
    input    wire   [31:0]   ex_mem_data,
    input    wire   [5:0]    stall,

    output   reg    [31:0]   mem_pc,
    output   reg             mem_reg_write,
    output   reg    [4:0]    mem_wb_addr,
    output   reg    [31:0]   mem_wb_data,

    output   reg    [2:0]    mem_mem_op,
    output   reg    [31:0]   mem_mem_addr,
    output   reg    [31:0]   mem_mem_data,

    output   reg    [31:0]   last_store_addr,
    output   reg    [31:0]   last_store_data
);

always @(posedge clk) begin
    if (rst == 1'b1) begin
        mem_pc          <= 32'h0;
        mem_reg_write   <= 1'b0;
        mem_wb_addr     <= 5'h0;
        mem_wb_data     <= 32'h0;
        mem_mem_op      <= 3'h0;
        mem_mem_addr    <= 32'h0;
        mem_mem_data    <= 32'h0;
        last_store_addr <= 32'h0;
        last_store_data <= 32'h0;
    end else if (stall[3] == 1'b1) begin
        mem_pc          <= mem_pc;
        mem_reg_write   <= mem_reg_write;
        mem_wb_addr     <= mem_wb_addr;
        mem_wb_data     <= mem_wb_data;
        mem_mem_op      <= mem_mem_op;
        mem_mem_addr    <= mem_mem_addr;
        mem_mem_data    <= mem_mem_data;
        last_store_addr <= last_store_addr;
        last_store_data <= last_store_data;
    end else begin
        mem_pc        <= ex_pc;
        mem_reg_write <= ex_reg_write;
        mem_wb_addr   <= ex_wb_addr;
        mem_wb_data   <= ex_wb_data;
        mem_mem_op    <= ex_mem_op;
        mem_mem_addr  <= ex_mem_addr;
        mem_mem_data  <= ex_mem_data;

        case (ex_mem_op)
            3'b110: begin
                last_store_addr <= ex_mem_addr;
                case (ex_mem_addr[1:0])
                    2'b00: last_store_data <= {24'h0, ex_mem_data[7:0]};
                    2'b01: last_store_data <= {16'h0, ex_mem_data[7:0], 8'h0};
                    2'b10: last_store_data <= {8'h0,  ex_mem_data[7:0], 16'h0};
                    2'b11: last_store_data <= {ex_mem_data[7:0], 24'h0};
                endcase
            end
            3'b111: begin
                last_store_addr <= ex_mem_addr;
                case (ex_mem_addr[1])
                    1'b0: last_store_data <= {16'h0, ex_mem_data[15:0]};
                    1'b1: last_store_data <= {ex_mem_data[15:0], 16'h0};
                endcase
            end
            3'b000: begin
                if (ex_reg_write == 1'b0) begin
                    last_store_addr <= ex_mem_addr;
                    last_store_data <= ex_mem_data;
                end else begin
                    last_store_addr <= last_store_addr;
                    last_store_data <= last_store_data;
                end
            end
            default: begin
                last_store_addr <= last_store_addr;
                last_store_data <= last_store_data;
            end
        endcase
    end
end

endmodule
