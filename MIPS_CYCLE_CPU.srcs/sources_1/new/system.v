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


// 内部信号定义：连接 MIPS_top 与 SRAM 外设

// MIPS_top 输出的信号（虚地址、控制信号等）
wire   [19:0]  mips_b_addr;
wire           mips_b_ce_n, mips_b_oe_n;
wire   [31:0]  b_ram_read_data;

wire   [31:0]  mips_ext_ram_A;     // MIPS 输出的 ExtSRAM 虚地址（32位）
wire   [31:0]  mips_ext_ram_D_o;   // MIPS 输出的 ExtSRAM 写数据（FPGA→SRAM）
wire   [31:0]  mips_ext_ram_D_i;   // MIPS 接收的 ExtSRAM 读数据（SRAM→FPGA）
wire   [3:0]   mips_ext_ram_BE;    // MIPS 输出的 ExtSRAM 字节使能
wire           mips_ext_ram_CE;    // MIPS 输出的 ExtSRAM 片选
wire           mips_ext_ram_WE;    // MIPS 输出的 ExtSRAM 写使能



MIPS_top mips_core(
    .clk             (clk),
    .rst             (rst),
    // BaseSRAM 交互（MIPS 侧）
    .base_ram_rdata(b_ram_read_data),
    .base_ram_addr(mips_b_addr),
    .base_ram_ce_n(mips_b_ce_n),
    .base_ram_oe_n(mips_b_oe_n),
    // ExtSRAM 交互（MIPS 侧）
    .ext_ram_A       (mips_ext_ram_A),      // MIPS 输出 ExtSRAM 虚地址
    .ext_ram_D_i     (mips_ext_ram_D_i),    // MIPS 接收 ExtSRAM 读数据
    .ext_ram_D_o     (mips_ext_ram_D_o),    // MIPS 输出 ExtSRAM 写数据
    .ext_ram_BE      (mips_ext_ram_BE),     // MIPS 输出 ExtSRAM 字节使能
    .ext_ram_CE      (mips_ext_ram_CE),     // MIPS 输出 ExtSRAM 片选
    .ext_ram_WE      (mips_ext_ram_WE)      // MIPS 输出 ExtSRAM 写使能
);


assign base_ram_addr = mips_b_addr;  // 20 位物理地址（[21:2] 刚好 20 位）

assign base_ram_ce_n = mips_b_ce_n;     // 片选
assign base_ram_we_n = 1'b1;                  // BaseSRAM 只用于取指（只读），写使能永远无效
assign base_ram_oe_n = mips_b_oe_n;     // 读使能：片选有效时，读使能也有效
assign base_ram_be_n = 4'b0000;               // 指令是 4 字节，字节使能全有效（低有效）

// 双向数据总线三态控制（BaseSRAM 只读，永远释放写方向）
assign base_ram_data = 32'hzzzzzzzz;          
assign b_ram_read_data = base_ram_data;    // 接收 BaseSRAM 输出的指令数据，传给 MIPS


assign ext_ram_addr = mips_ext_ram_A[21:2];

assign ext_ram_ce_n = mips_ext_ram_CE;   // 低有效
assign ext_ram_we_n = mips_ext_ram_WE;   // 低有效
assign ext_ram_oe_n = (!mips_ext_ram_CE && mips_ext_ram_WE) ? 1'b0 : 1'b1; // ★修正
assign ext_ram_be_n = mips_ext_ram_BE;


assign ext_ram_data = (!mips_ext_ram_CE && !mips_ext_ram_WE) ? mips_ext_ram_D_o : 32'hzzzzzzzz;

assign mips_ext_ram_D_i = (!mips_ext_ram_CE && mips_ext_ram_WE) ? ext_ram_data : 32'h00000000;

endmodule