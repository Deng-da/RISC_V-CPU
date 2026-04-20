`timescale 1ns / 1ps

module MIPS_top(
    input    wire           clk,
    input    wire           rst,
    //BaseSRAM    
    input    wire   [31:0]  base_ram_rdata,
    output   wire   [19:0]  base_ram_addr,
    output   wire           base_ram_ce_n,
    output   wire           base_ram_oe_n,
    //ExtSRAM    
    output   wire   [31:0]  ext_ram_A,    
    input    wire   [31:0]  ext_ram_D_i,   
    output   wire   [31:0]  ext_ram_D_o,
    output   wire   [3:0]   ext_ram_BE,   
    output   wire           ext_ram_CE,ext_ram_WE
    
    );
                                                
    wire               branch;      
    wire     [31:0]    branch_address;                
    wire     [5:0]     stall;
    wire [31:0] pc_to_if;
    wire pc_ce_to_if;
    wire [31:0] inst_from_mem;

   pc pc_reg(
 .clk (clk),
 .rst (rst),
 .pc (pc_to_if),
 .ce (pc_ce_to_if),
 .branch (branch),
 .branch_address (branch_address),
 .stall (stall)
);

assign base_ram_addr = pc_to_if[21:2];
assign base_ram_ce_n = pc_ce_to_if;   // pc.ce 低有效，0=请求有效
assign base_ram_oe_n = 1'b0;
assign inst_from_mem = base_ram_rdata;
     
     
     wire   [31:0]   id_pc;
     wire   [31:0]   if_id_inst_o;
     
    if_id if_id_o(
    .clk      (clk),
    .rst      (rst),
    .if_pc (pc_to_if),
    .if_inst (inst_from_mem),
    .id_pc    (id_pc),
    .id_inst  (if_id_inst_o),
    .stall    (stall)
    );
    
    
//reg_fileģ     
//id  reg_fileģ  ֮     Ϣi,o       reg_file  ˵     
    //    reg_file  ȡ        
    wire   [31:0]   reg_1_data_o;
    wire   [31:0]   reg_2_data_o;
//    reg_file    Ϣ
    //    idģ  
    wire   [4:0]    reg_1_addr_i;
    wire            re_1_i;      
    wire   [4:0]    reg_2_addr_i;
    wire            re_2_i;   
    //    mem_wbģ   
    wire            wb_reg_write;
    wire   [4:0]    wb_addr;
    wire   [31:0]   wb_data;
    
    
    reg_file reg_file1(
        .clk          (clk),
        .rst          (rst),  
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
    
//idģ      
    wire   [31:0]   reg_1_o;
    wire   [31:0]   reg_2_o;
    
    wire            id_reg_write;
    wire   [4:0]    id_wb_addr;
    
    wire   [4:0]    id_alu_op;
    wire   [31:0]   id_inst_o;
    wire   [31:0]   id_link_address;
    
    wire   [31:0]   ex_mem_addr;
    wire            this_inst_is_load;//    exģ      
    
    wire            stallask_from_id;//    stall_ctrlģ  
    
    wire   [4:0]   ex_wb_addr_o;
    wire   [31:0]  ex_wb_data_o;
    wire           ex_reg_write_o;

    wire            mem_reg_write_o;
    wire   [4:0]    mem_wb_addr_o;
    wire   [31:0]   mem_wb_data_o;

    
    id id_1(
        .rst               (rst),
        .id_pc             (id_pc),
        .id_inst           (if_id_inst_o),      
        .reg_1_data        (reg_1_data_o),
        .reg_2_data        (reg_2_data_o),
        .reg_1_addr        (reg_1_addr_i),
        .re_1              (re_1_i),
        .reg_2_addr        (reg_2_addr_i),
        .re_2              (re_2_i), 
        .alu_op            (id_alu_op),  
        .reg_1             (reg_1_o),
        .reg_2             (reg_2_o),
        .reg_write         (id_reg_write),
        .wb_addr           (id_wb_addr),
        .inst_o            (id_inst_o),   
        .branch            (branch),
        .branch_address_o  (branch_address),
        .link_address_o    (id_link_address),
        
        //    EX ׶ε   Ϣ     ڽ  д   ð  
        .ex_reg_write      (ex_reg_write_o),
        .ex_wb_addr        (ex_wb_addr_o),
        .ex_wb_data        (ex_wb_data_o), 
        
        //    EX ׶ε   Ϣ     ڽ  Load_Useð  
        .ex_mem_load_addr  (ex_mem_addr),
        .pre_inst_is_load  (this_inst_is_load),
        
        //    MEM ׶ε   Ϣ     ڽ  Load_Useð  
        .mem_reg_write      (mem_reg_write_o),
        .mem_wb_addr        (mem_wb_addr_o),
        .mem_wb_data        (mem_wb_data_o),
              
        .stallask          (stallask_from_id)
        
    );
    
    
    
    wire   [4:0]   ex_aluop;
    wire   [31:0]  ex_reg_1;
    wire   [31:0]  ex_reg_2;
    wire   [4:0]   ex_wb_addr;
    wire           ex_reg_write;
    wire   [31:0]  ex_inst;
    wire   [31:0]  ex_pc;
    wire   [31:0]  ex_link_address;
    
    
    id_ex id_ex_o(
        .rst            (rst),
        .clk            (clk),
        .id_aluop       (id_alu_op),
        .id_reg_1       (reg_1_o),
        .id_reg_2       (reg_2_o),
        .id_wb_addr     (id_wb_addr),
        .id_reg_write   (id_reg_write),
        .id_inst        (id_inst_o),
        .id_pc          (id_pc),
        .ex_aluop       (ex_aluop),
        .ex_reg_1       (ex_reg_1),
        .ex_reg_2       (ex_reg_2),
        .ex_wb_addr     (ex_wb_addr),
        .ex_reg_write   (ex_reg_write),
        .ex_inst        (ex_inst),
        .ex_pc          (ex_pc),
        .id_link_addr   (id_link_address),
        .ex_link_addr   (ex_link_address),
        .stall          (stall)
    );
    
    
    wire   [2:0]    mem_op;
    wire   [31:0]   mem_addr;
    wire   [31:0]   mem_data;
    


    wire   [31:0]  ex_mem_data;
    
    
    
    ex ex1(
        .rst                (rst),   
        .alu_op             (ex_aluop),    
        .reg_1              (ex_reg_1),     
        .reg_2              (ex_reg_2),     
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
        .reg_write_o        (ex_reg_write_o),                          
        .this_inst_is_load  (this_inst_is_load)         
        
    );
    
    
    wire   [31:0]   mem_pc;
    wire            mem_reg_write;
    wire   [4:0]    mem_wb_addr;
    wire   [31:0]   mem_wb_data;
    wire   [2:0]    mem_op_o;

    wire   [31:0]   last_store_addr;
    wire   [31:0]   last_store_data;
    
    
    ex_mem ex_mem_o(
        .clk              (clk),  
        .rst              (rst),  
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
        .last_store_addr  (last_store_addr),  
        .last_store_data  (last_store_data)    
        
    );
    
    //    WB ׶ε ͬʱ    idģ  

    
    wire   [31:0]   mem_addr_o;
    wire   [31:0]   mem_data_o;
    
    mem mem1(
        .rst            (rst),              
        .mem_pc         (mem_pc),   
        .mem_reg_write  (mem_reg_write),  
        .mem_wb_addr    (mem_wb_addr),     
        .mem_wb_data    (mem_wb_data),     
        .mem_op         (mem_op_o),     
        .mem_addr       (mem_addr),     
        .mem_data       (mem_data),                         
        .ram_data       (ext_ram_D_i),
        
        //    WB ׶ε   Ϣ  ͬʱҲ    ID ׶Σ                     
        .reg_write      (mem_reg_write_o),     
        .wb_addr        (mem_wb_addr_o),     
        .wb_data        (mem_wb_data_o),
                                
        .mem_addr_o     (ext_ram_A),    
        .mem_data_o     (ext_ram_D_o),    
        .mem_we_n       (ext_ram_WE),               
        .mem_sel_n      (ext_ram_BE),
        .mem_ce         (ext_ram_CE)
        
    );
    
    mem_wb mem_wb_o(
        .clk            (clk),
        .rst            (rst),
        .stall          (stall),
        .mem_wb_addr    (mem_wb_addr_o),
        .mem_wb_data    (mem_wb_data_o),
        .mem_reg_write  (mem_reg_write_o),
        .wb_wb_addr     (wb_addr),
        .wb_wb_data     (wb_data),
        .wb_reg_write   (wb_reg_write)
    
    );
    
    stall_ctrl stall_ctrl1(
 .rst (rst),
 .stallask_from_id (stallask_from_id),
 .stall (stall)
);
     

     
     
endmodule