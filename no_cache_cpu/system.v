`timescale 1ns / 1ps

module system_top(
    input  wire           clk,          // 系统时钟
    input  wire           rst,          // 系统复位
    // BaseSRAM 硬件接口
    output wire   [19:0]  base_ram_addr,    // BaseSRAM 地址线
    inout  wire   [31:0]  base_ram_data,    // BaseSRAM 双向数据线
    output wire   [3:0]   base_ram_be_n,    // BaseSRAM 字节使能（低有效）
    output wire           base_ram_ce_n,    // BaseSRAM 片选（低有效）
    output wire           base_ram_oe_n,    // BaseSRAM 读使能（低有效）
    output wire           base_ram_we_n,    // BaseSRAM 写使能（低有效）
    // ExtSRAM 硬件接口
    output wire   [19:0]  ext_ram_addr,     // ExtSRAM 地址线
    inout  wire   [31:0]  ext_ram_data,     // ExtSRAM 双向数据线
    output wire   [3:0]   ext_ram_be_n,     // ExtSRAM 字节使能（低有效）
    output wire           ext_ram_ce_n,     // ExtSRAM 片选（低有效）
    output wire           ext_ram_oe_n,     // ExtSRAM 读使能（低有效）
    output wire           ext_ram_we_n      // ExtSRAM 写使能（低有效）
);

// ===================== 比赛要求 myCPU 接口信号 =====================
wire [31:0] irom_addr;
wire [31:0] irom_data;

wire [31:0] perip_addr;
wire        perip_wen;
wire [1:0]  perip_mask;
wire [31:0] perip_wdata;
wire [31:0] perip_rdata;

// ===================== 比赛 CPU 例化（必须用这个！） =====================
myCPU Core_cpu(
    .cpu_clk     (clk),
    .cpu_rst     (rst),
    
    .irom_addr   (irom_addr),
    .irom_data   (irom_data),
    
    .perip_addr  (perip_addr),
    .perip_wen   (perip_wen),
    .perip_mask  (perip_mask),
    .perip_wdata (perip_wdata),
    .perip_rdata (perip_rdata)
);

// ===================== IROM (BaseSRAM) 接口 =====================
assign base_ram_addr   = irom_addr[21:2];
assign base_ram_ce_n   = 1'b0;
assign base_ram_oe_n   = 1'b0;
assign base_ram_we_n   = 1'b1;
assign base_ram_be_n   = 4'b0000;
assign base_ram_data   = 32'hzzzzzzzz;
assign irom_data       = base_ram_data;

// ===================== DRAM / 外设 (ExtSRAM) 接口 =====================
assign ext_ram_addr     = perip_addr[21:2];
assign ext_ram_ce_n     = 1'b0;
assign ext_ram_we_n     = perip_wen;
assign ext_ram_oe_n     = ~perip_wen;
assign ext_ram_be_n     = perip_mask;

assign ext_ram_data     = (!perip_wen) ? perip_wdata : 32'hzzzzzzzz;
assign perip_rdata      = ext_ram_data;

endmodule