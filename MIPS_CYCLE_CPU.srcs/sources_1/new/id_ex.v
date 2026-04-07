`timescale 1ns / 1ps


module id_ex (
    input    wire        rst,       
    input    wire        clk,        

    //id阶段获得的信息
    input    wire[4:0]   id_aluop,
    input    wire[31:0]  id_reg_1,
    input    wire[31:0]  id_reg_2,
    input    wire[4:0]   id_wb_addr,
    input    wire        id_reg_write,
    input    wire[31:0]  id_inst,
	input    wire[31:0]  id_pc,

    //送往ex阶段的信息
    output   reg [4:0]   ex_aluop,
    output   reg [31:0]  ex_reg_1,
    output   reg [31:0]  ex_reg_2,
    output   reg [4:0]   ex_wb_addr,
    output   reg         ex_reg_write,
    output   reg [31:0]  ex_inst,
	output   reg [31:0]  ex_pc,

    //分支跳转存储
    input    wire[31:0]  id_link_addr,
    output   reg [31:0]  ex_link_addr,

    input    wire[5:0]   stall
);

    always @ (posedge clk) begin
		if (rst == 1'b0) begin
			ex_aluop     <= 5'h0;
			ex_reg_1     <= 32'h0;
			ex_reg_2     <= 32'h0;
			ex_wb_addr   <= 5'h0;
			ex_reg_write <= 1'b0;
			ex_inst      <= 32'h0;
			ex_pc        <= 32'h0;
			ex_link_addr <= 32'h0;
		end 
		else if(stall[2] == 1'b1) begin //保持   
		    ex_aluop     <= ex_aluop;        
            ex_reg_1     <= ex_reg_1;    
            ex_reg_2     <= ex_reg_2;    
            ex_wb_addr   <= ex_wb_addr;  
            ex_reg_write <= ex_reg_write;
            ex_inst      <= ex_inst;     
            ex_pc        <= ex_pc;       
            ex_link_addr <= ex_link_addr;
		end
		else if(stall[2] == 1'b0 && stall[1] == 1'b1) begin //EX不暂停而ID暂停则插入气泡0指令防止重复执行旧指令
			ex_aluop     <= 5'h0;
			ex_reg_1     <= 32'h0;
			ex_reg_2     <= 32'h0;
			ex_wb_addr   <= 5'h0;
			ex_reg_write <= 1'b0;
			ex_inst      <= 32'h0;
			ex_pc        <= 32'h0;
			ex_link_addr <= 32'h0;

		end else begin	
			ex_aluop     <= id_aluop;
			ex_reg_1     <= id_reg_1;
			ex_reg_2     <= id_reg_2;
			ex_wb_addr   <= id_wb_addr;
			ex_reg_write <= id_reg_write;		
			ex_inst      <= id_inst;
			ex_pc        <= id_pc;
			ex_link_addr <= id_link_addr;
		end
        
	end
 
endmodule //id_ex
