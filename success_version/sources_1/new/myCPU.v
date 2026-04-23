`timescale 1ns / 1ps

module myCPU(
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

wire        branch;
wire [31:0] branch_address;
wire [5:0]  stall;
wire [31:0] pc_to_if;
wire        pc_ce_to_if;

assign irom_addr = pc_to_if;

pc pc_reg(
    .clk            (cpu_clk),
    .rst            (cpu_rst),
    .pc             (pc_to_if),
    .ce             (pc_ce_to_if),
    .branch         (branch),
    .branch_address (branch_address),
    .stall          (stall)
);

wire [31:0] id_pc;
wire [31:0] if_id_inst_o;

if_id if_id_o(
    .clk      (cpu_clk),
    .rst      (cpu_rst),
    .if_pc    (pc_to_if),
    .if_inst  (irom_data),
    .flush    (branch),
    .id_pc    (id_pc),
    .id_inst  (if_id_inst_o),
    .stall    (stall)
);

wire [31:0] reg_1_data_o;
wire [31:0] reg_2_data_o;
wire [4:0]  reg_1_addr_i;
wire        re_1_i;
wire [4:0]  reg_2_addr_i;
wire        re_2_i;
wire        wb_reg_write;
wire [4:0]  wb_addr;
wire [31:0] wb_data;

reg_file reg_file1(
    .clk          (cpu_clk),
    .rst          (cpu_rst),
    .reg_write    (wb_reg_write),
    .wb_addr      (wb_addr),
    .wb_data      (wb_data),
    .reg_1_addr   (reg_1_addr_i),
    .re_1         (re_1_i),
    .reg_1_data   (reg_1_data_o),
    .reg_2_addr   (reg_2_addr_i),
    .re_2         (re_2_i),
    .reg_2_data   (reg_2_data_o)
);

wire [31:0] reg_1_o;
wire [31:0] reg_2_o;
wire [31:0] id_store_data;
wire        id_reg_write;
wire [4:0]  id_wb_addr;
wire [4:0]  id_alu_op;
wire [3:0]  id_mem_op;
wire [31:0] id_inst_o;
wire [31:0] id_link_address;
wire        id_is_load;
wire        ex_is_load;
wire        stallask_from_id;

wire [4:0]  ex_wb_addr_o;
wire [31:0] ex_wb_data_o;
wire        ex_reg_write_o;
wire        mem_reg_write_o;
wire [4:0]  mem_wb_addr_o;
wire [31:0] mem_wb_data_o;

id id_1(
    .rst                (cpu_rst),
    .id_pc              (id_pc),
    .id_inst            (if_id_inst_o),
    .reg_1_data         (reg_1_data_o),
    .reg_2_data         (reg_2_data_o),
    .reg_1_addr         (reg_1_addr_i),
    .re_1               (re_1_i),
    .reg_2_addr         (reg_2_addr_i),
    .re_2               (re_2_i),
    .alu_op             (id_alu_op),
    .mem_op             (id_mem_op),
    .reg_1              (reg_1_o),
    .reg_2              (reg_2_o),
    .store_data         (id_store_data),
    .reg_write          (id_reg_write),
    .wb_addr            (id_wb_addr),
    .is_load            (id_is_load),
    .inst_o             (id_inst_o),
    .branch             (branch),
    .branch_address_o   (branch_address),
    .link_address_o     (id_link_address),
    .pre_inst_is_load   (ex_is_load),
    .ex_reg_write       (ex_reg_write_o),
    .ex_wb_addr         (ex_wb_addr_o),
    .ex_wb_data         (ex_wb_data_o),
    .mem_reg_write      (mem_reg_write_o),
    .mem_wb_addr        (mem_wb_addr_o),
    .mem_wb_data        (mem_wb_data_o),
    .stallask           (stallask_from_id)
);

wire [4:0]  ex_aluop;
wire [3:0]  ex_mem_op;
wire [31:0] ex_reg_1;
wire [31:0] ex_reg_2;
wire [31:0] ex_store_data;
wire [4:0]  ex_wb_addr;
wire        ex_reg_write;
wire [31:0] ex_inst;
wire [31:0] ex_pc;
wire [31:0] ex_link_address;

id_ex id_ex_o(
    .rst            (cpu_rst),
    .clk            (cpu_clk),
    .id_aluop       (id_alu_op),
    .id_mem_op      (id_mem_op),
    .id_reg_1       (reg_1_o),
    .id_reg_2       (reg_2_o),
    .id_store_data  (id_store_data),
    .id_wb_addr     (id_wb_addr),
    .id_reg_write   (id_reg_write),
    .id_is_load     (id_is_load),
    .id_inst        (id_inst_o),
    .id_pc          (id_pc),
    .ex_aluop       (ex_aluop),
    .ex_mem_op      (ex_mem_op),
    .ex_reg_1       (ex_reg_1),
    .ex_reg_2       (ex_reg_2),
    .ex_store_data  (ex_store_data),
    .ex_wb_addr     (ex_wb_addr),
    .ex_reg_write   (ex_reg_write),
    .ex_is_load     (ex_is_load),
    .ex_inst        (ex_inst),
    .ex_pc          (ex_pc),
    .id_link_addr   (id_link_address),
    .ex_link_addr   (ex_link_address),
    .stall          (stall)
);

wire [3:0]  mem_op;
wire [31:0] ex_mem_addr;
wire [31:0] ex_mem_data;

ex ex1(
    .rst                (cpu_rst),
    .alu_op             (ex_aluop),
    .mem_op_i           (ex_mem_op),
    .reg_1              (ex_reg_1),
    .reg_2              (ex_reg_2),
    .store_data         (ex_store_data),
    .wb_addr            (ex_wb_addr),
    .reg_write          (ex_reg_write),
    .ex_inst            (ex_inst),
    .ex_pc              (ex_pc),
    .link_addr          (ex_link_address),
    .mem_op             (mem_op),
    .mem_addr           (ex_mem_addr),
    .mem_data           (ex_mem_data),
    .wb_data            (ex_wb_data_o),
    .wb_addr_o          (ex_wb_addr_o),
    .reg_write_o        (ex_reg_write_o)
);

wire [31:0] mem_pc;
wire        mem_reg_write;
wire [4:0]  mem_wb_addr;
wire [31:0] mem_wb_data;
wire [3:0]  mem_op_o;
wire [31:0] mem_addr;
wire [31:0] mem_data;

ex_mem ex_mem_o(
    .clk              (cpu_clk),
    .rst              (cpu_rst),
    .ex_pc            (ex_pc),
    .ex_reg_write     (ex_reg_write_o),
    .ex_wb_addr       (ex_wb_addr_o),
    .ex_wb_data       (ex_wb_data_o),
    .ex_mem_op        (mem_op),
    .mem_mem_op       (mem_op_o),
    .ex_mem_addr      (ex_mem_addr),
    .ex_mem_data      (ex_mem_data),
    .stall            (stall),
    .mem_pc           (mem_pc),
    .mem_reg_write    (mem_reg_write),
    .mem_wb_addr      (mem_wb_addr),
    .mem_wb_data      (mem_wb_data),
    .mem_mem_addr     (mem_addr),
    .mem_mem_data     (mem_data),
    .last_store_addr  (),
    .last_store_data  ()
);

mem mem1(
    .rst            (cpu_rst),
    .mem_pc         (mem_pc),
    .mem_reg_write  (mem_reg_write),
    .mem_wb_addr    (mem_wb_addr),
    .mem_wb_data    (mem_wb_data),
    .mem_op         (mem_op_o),
    .mem_addr       (mem_addr),
    .mem_data       (mem_data),
    .ram_data       (perip_rdata),
    .reg_write      (mem_reg_write_o),
    .wb_addr        (mem_wb_addr_o),
    .wb_data        (mem_wb_data_o),
    .mem_addr_o     (perip_addr),
    .mem_data_o     (perip_wdata),
    .mem_we_n       (perip_wen),
    .mem_sel_n      (perip_mask),
    .mem_ce         ()
);

mem_wb mem_wb_o(
    .clk            (cpu_clk),
    .rst            (cpu_rst),
    .stall          (stall),
    .mem_wb_addr    (mem_wb_addr_o),
    .mem_wb_data    (mem_wb_data_o),
    .mem_reg_write  (mem_reg_write_o),
    .wb_wb_addr     (wb_addr),
    .wb_wb_data     (wb_data),
    .wb_reg_write   (wb_reg_write)
);

stall_ctrl stall_ctrl1(
    .rst                (cpu_rst),
    .stallask_from_id    (stallask_from_id),
    .stall              (stall)
);

endmodule
