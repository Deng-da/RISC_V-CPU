`timescale 1ns / 1ps

module mem(   
    input    wire            rst,
    
    //来自EX阶段的数据
    input    wire   [31:0]   mem_pc,      
    input    wire            mem_reg_write,        
    input    wire   [4:0]    mem_wb_addr,      
    input    wire   [31:0]   mem_wb_data,    
    input    wire   [2:0]    mem_op,      
    input    wire   [31:0]   mem_addr,      
    input    wire   [31:0]   mem_data, 
    
    //来自数据存储器读取的数据     
    input    wire   [31:0]   ram_data,      
    
    //送往WB阶段的信息（同时送往ID阶段用于解决Load_Use冒险）
    output   reg             reg_write, 
    output   reg    [4:0]    wb_addr,     
    output   reg    [31:0]   wb_data,
         
    //送往数据存储器的数据
    output   reg    [31:0]   mem_addr_o,    
    output   reg    [31:0]   mem_data_o,      
    output   reg             mem_we_n,
    //lb,sb     
    output   reg    [3:0]    mem_sel_n,//字节使能信号    
    output   reg             mem_ce   //片选使能
          
    //output   reg             stallreg    
  
    );
    
    reg   [7:0]   lb_byte;
    always @(*) begin
        if(rst == 1'b0) begin
            reg_write  = 1'b0;
            wb_addr    = 5'h0;
            wb_data    = 32'h0;
            mem_addr_o = 32'h0;
            mem_data_o = 32'h0;
            mem_we_n   = 1'b1; 
            mem_sel_n  = 4'b1111;
            mem_ce     = 1'b1; 
        end else begin
            reg_write  = mem_reg_write;
            wb_addr    = mem_wb_addr;
        end
        case(mem_op)
            3'b001:begin//lb
                mem_addr_o = mem_addr;
                mem_data_o = 32'h0;
                mem_we_n   = 1'b1;  
                mem_ce     = 1'b0; 
                case(mem_addr[1:0])
                    2'b00: begin
                        mem_sel_n = 4'b1110;
                        lb_byte   = ram_data[7:0];
                    end 
                    2'b01: begin
                        mem_sel_n = 4'b1101;
                        lb_byte   = ram_data[15:8];
                    end
                    2'b10: begin
                        mem_sel_n = 4'b1011;
                        lb_byte   = ram_data[23:16];
                    end
                    2'b11: begin
                        mem_sel_n = 4'b0111;
                        lb_byte   = ram_data[31:24];
                    end
                    default : begin
                        mem_sel_n = 4'b1111;
                    end
                endcase
                wb_data={{24{lb_byte[7]}}, lb_byte};
            end
            3'b010:begin//lw
                wb_data    = ram_data;
                mem_addr_o = mem_addr;
                mem_data_o = 32'h0;
                mem_we_n   = 1'b1;
                mem_ce     = 1'b0;
                mem_sel_n  = 4'b0000;
            end
            3'b011:begin//sb
                wb_data    = 32'h0;
                mem_addr_o = mem_addr;
                mem_data_o = {4{mem_data[7:0]}};    //低字节存储到指定位置
                mem_we_n   = 1'b0;
                mem_ce     = 1'b0;
                case(mem_addr[1:0])
                    2'b00: begin
                        mem_data_o={24'h0,mem_data[7:0]};
                        mem_sel_n = 4'b1110;
                    end 
                    2'b01: begin
                        mem_data_o={16'h0,mem_data[7:0],8'h0};
                        mem_sel_n = 4'b1101;
                    end
                    2'b10: begin
                        mem_data_o={8'h0,mem_data[7:0],16'h0};
                        mem_sel_n = 4'b1011;
                    end
                    2'b11: begin
                        mem_data_o = {mem_data[7:0], 24'h0};
                        mem_sel_n = 4'b0111;
                    end
                    default : begin
                        mem_sel_n = 4'b1111;
                    end
                endcase
            end
            3'b100:begin//sw
                wb_data    = 32'h0;
                mem_addr_o = mem_addr;
                mem_data_o = mem_data;
                mem_we_n   = 1'b0;
                mem_ce     = 1'b0;
                mem_sel_n  = 4'b0000;
            end
            default: begin
                wb_data    = mem_wb_data;
                mem_addr_o = 32'h0;
                mem_data_o = 32'h0;
                mem_we_n   = 1'b1;
                mem_ce     = 1'b1;
                mem_sel_n  = 4'b1111;
            end
        endcase
    end
endmodule
