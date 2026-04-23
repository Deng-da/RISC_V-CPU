`timescale 1ns / 1ps

// Wrapper for competition template integration.
// If the template requires module name `Core_cpu`, include this file and keep myCPU unchanged.
module Core_cpu(
    input  wire         cpu_clk,
    input  wire         cpu_rst,
    output wire [31:0]  irom_addr,
    input  wire [31:0]  irom_data,
    output wire [31:0]  perip_addr,
    output wire         perip_wen,
    output wire [3:0]   perip_mask,
    output wire [31:0]  perip_wdata,
    input  wire [31:0]  perip_rdata
);

myCPU u_myCPU(
    .cpu_clk     (cpu_clk),
    .cpu_rst     (cpu_rst),
    .irom_addr   (irom_addr),
    .irom_data   (irom_data),
    .perip_addr  (perip_addr),
    .perip_wen   (perip_wen),
    .perip_mask  (perip_mask),
    .perip_wdata (perip_wdata),
    .perip_rdata (perip_rdata)
);

endmodule
