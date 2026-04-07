`timescale 1ns / 1ps

module reg_file(
    input    wire           clk,
    input    wire           rst,
    
//MEM阶段传来的信息
    input    wire           reg_write,
    input    wire   [4:0]   wb_addr,
    input    wire   [31:0]  wb_data,
    
    //ID阶段传递的信息及取得的数据
    input    wire   [4:0]   reg_1_addr,
    input    wire           re_1,
    output   reg    [31:0]  reg_1_data,
    input    wire   [4:0]   reg_2_addr,
    input    wire           re_2,
    output   reg    [31:0]  reg_2_data
    );  

    reg    [31:0] registers [31:0];
    integer i;   
    
//相当于WB阶段                            
    always @(posedge clk or negedge rst)begin
        if(!rst)begin
            for(i=0;i<32;i=i+1)begin
                registers[i]<=32'h0;
            end
        end
        else begin
            if(reg_write==1'b1 &&wb_addr!=5'b00000)begin
                registers[wb_addr]<=wb_data;
            end
        end
    end
    
//读端口1的数据
    always @(*)begin
        if(rst == 1'b0) begin
        reg_1_data = 32'h0;
        end
        else begin
            if(re_1 == 1'b1) begin
                if(reg_1_addr == 5'b00000) begin
                    reg_1_data = 32'h0;
                end else if(reg_1_addr == wb_addr && reg_write == 1'b1) begin
                    reg_1_data = wb_data;    //处理数据冒险
                end else begin
                    reg_1_data = registers[reg_1_addr];
                end
            end else begin
                reg_1_data = 32'h0;
            end
        end
    end
    
//读端口2的数据
    always @(*)begin
        if(rst == 1'b0) begin
        reg_2_data = 32'h0;
        end
        else begin
            if(re_2 == 1'b1) begin
                if(reg_2_addr == 5'b00000) begin
                    reg_2_data = 32'h0;
                end else if(reg_2_addr == wb_addr && reg_write == 1'b1) begin
                    reg_2_data = wb_data;    //处理数据冒险
                end else begin
                    reg_2_data = registers[reg_2_addr];
                end
            end else begin
                reg_2_data = 32'h0;
            end
        end
    end
    
endmodule
