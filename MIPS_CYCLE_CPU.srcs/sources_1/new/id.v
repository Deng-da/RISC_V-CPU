`timescale 1ns / 1ps

module id(
    input   wire           rst,
    
    input   wire   [31:0]  id_pc,
    input   wire   [31:0]  id_inst,

//从reg_file获取的信息
    input   wire   [31:0]  reg_1_data,// 读寄存器1获取的数据
    input   wire   [31:0]  reg_2_data,// 读寄存器2获取的数据
    
//传往reg_file的信息
    output  reg    [4:0]   reg_1_addr,
    output  reg            re_1,
    output  reg    [4:0]   reg_2_addr,
    output  reg            re_2,
  
//传往EX阶段的信息
    output  reg    [4:0]   alu_op,
    
    output  reg    [31:0]  reg_1,//源操作数1
    output  reg    [31:0]  reg_2,//源操作数2
    
    output  reg            reg_write,//寄存器写使能
    output  reg    [4:0]   wb_addr,//要写回的的寄存器的地址
    output  wire   [31:0]  inst_o,
    
//分支跳转，解决控制冒险
    output  reg            branch,//跳转使能
    output  reg    [31:0]  branch_address_o,//跳转地址
    output  reg    [31:0]  link_address_o,//连接地址
    
//EX阶段传来的信息
    //解决load_use冒险
    input   wire            pre_inst_is_load,
    input   wire   [31:0]   ex_mem_load_addr, 
    //解决写后读冒险
    input   wire            ex_reg_write,
    input   wire   [4:0]    ex_wb_addr,
    input   wire   [31:0]   ex_wb_data,
    
//MEM阶段传来的信息
    ///解决load_use冒险的信息
    input   wire            mem_reg_write,  
    input   wire   [4:0]    mem_wb_addr,  
    input   wire   [31:0]   mem_wb_data,  


//传往stall_ctrl模块的
    output  wire            stallask//流水线暂停请求
/*
    output  reg            reg_dst,
    output  reg            alu_src,
    output  reg            mem_read,
    output  reg            mem_write,
    output  reg            mem_to_reg,
    output  reg    [1:0]   branch,
    output  reg    [2:0]   branch_type,
    output  reg    [2:0]   ext_type,
    output  reg            byte_en,      // 数据存储器字节使能（控制字/字节访问）
    output  reg            jr_en,        // 寄存器跳转使能
    output  reg            al_en,      // 把返回地址写回使能
    output  reg            jump
*/

    );
//============================================================
// ID阶段功能：
// 1) 指令译码并生成EX控制信号
// 2) 读取/选择源操作数（含前递）
// 3) 进行分支跳转判断
// 4) 检测load-use相关冒险并请求暂停
//============================================================

// 分解提取指令各个字段
    // R型指令
    wire   [5:0]  opcode        = id_inst[31:26];
    wire   [4:0]  rs            = id_inst[25:21];
    wire   [4:0]  rt            = id_inst[20:16];
    wire   [4:0]  rd            = id_inst[15:11];
    wire   [4:0]  shamt         = id_inst[10:6];
    wire   [5:0]  func          = id_inst[5:0];

    // I型指令
    wire   [15:0] imm           = id_inst[15:0];

    // J型指令
    wire   [25:0] inst_index    = id_inst[25:0];

// 立即数扩展（根据指令类型选择零扩展或符号扩展）
    wire   [31:0] imm_u = {{16{1'b0}}, imm};       // 无符号扩展
    wire   [31:0] imm_s = {{16{imm[15]}}, imm};    // 有符号扩展

// 跳转/分支目标地址计算
    wire   [31:0] next_pc     = id_pc + 4'h4;
    wire   [31:0] jump_addr   = {next_pc[31:28], inst_index, 2'b00};
    wire   [31:0] branch_addr = next_pc + {imm_s[29:0], 2'b00};

// 用于承接最终送入操作数通路的立即数
    reg    [31:0] imm_o;
    
    assign inst_o  = id_inst;
    
//============================================================
// 译码主逻辑：为不同指令设置
// - alu_op
// - 源寄存器读使能/地址
// - 写回使能和写回目标寄存器
// - 立即数选择
//============================================================
always @(*)begin
    if(rst==1'b0)begin
        alu_op      = 5'h0;
        reg_1_addr  = 5'h0;
        re_1        = 1'b0;
        reg_2_addr  = 5'h0;
        re_2        = 1'b0;
        reg_write   = 1'b0;
        wb_addr     = 5'h0;
        imm_o       = 32'h0;
    end
    else begin
        alu_op      = 5'h0;
        reg_1_addr  = rs;
        re_1        = 1'b1;
        reg_2_addr  = rt;
        re_2        = 1'b1;
        reg_write   = 1'b0;
        wb_addr     = rd;
        imm_o       = 32'h0;
    end
    
    case(opcode)
//R型指令（里面又分为两大类）
        6'h0:begin
            if(shamt == 5'h0)begin
                case(func)
                    6'h20,6'h21:begin//add,addu
                        alu_op     = 5'b00001;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h22:begin//sub
                        alu_op     = 5'b00010;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h2A:begin//slt
                        alu_op     = 5'b00011;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h24:begin//and
                        alu_op     = 5'b00101;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h25:begin//or
                        alu_op     = 5'b00110;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h26:begin//xor
                        alu_op     = 5'b00111;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h04:begin//sllv
                        alu_op     = 5'b01000;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h06:begin//srlv
                        alu_op     = 5'b01010;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h07:begin//srav
                        alu_op     = 5'b01100;
                        re_1       = 1'b1;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                    end
                    6'h08:begin//jr
                        re_1       = 1'b1;
                        re_2       = 1'b0;
                        reg_write  = 1'b0;
                    end
                    6'h09:begin//jalr
                        alu_op     = 5'b01111;
                        re_1       = 1'b1;
                        re_2       = 1'b0;
                        reg_write  = 1'b1;
                        wb_addr    = rd;
                    end
                    default:begin
                    end
                endcase   
            end
            else if(rs == 5'h0)begin
                case(func)
                    6'h00:begin//sll
                        alu_op     = 5'b01000;
                        re_1       = 1'b0;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                        wb_addr    = rd;
                        imm_o[4:0] = shamt;
                    end
                    6'h02:begin//srl
                        alu_op     = 5'b01010;
                        re_1       = 1'b0;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                        wb_addr    = rd;
                        imm_o[4:0] = shamt;
                    end
                    6'h03:begin//sra
                        alu_op     = 5'b01100;
                        re_1       = 1'b0;
                        re_2       = 1'b1;
                        reg_write  = 1'b1;
                        wb_addr    = rd;
                        imm_o[4:0] = shamt;
                    end
                    default:begin
                    end
                endcase  
            end
            else begin
            end
        end
        6'h1C:begin//mul
            alu_op    = 5'b00100;
            re_1      = 1'b1;
            re_2      = 1'b1;
            reg_write = 1'b1;
        end
//I型指令
        6'h08,6'h09:begin//addi,addiu
            alu_op    = 5'b00001;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_s;
        end
        6'h0C:begin//andi
            alu_op    = 5'b00101;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_u;
        end
        6'h0D:begin//ori
            alu_op    = 5'b00110;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_u;
        end
        6'h0E:begin//xori
            alu_op    = 5'b00111;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_u;
        end
        6'h0F:begin//lui
            alu_op    = 5'b00110;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = {imm,16'h0};
        end
        6'h04: begin//beq
            re_1      = 1'b1;
            re_2      = 1'b1;
            reg_write = 1'b0;
            end
        6'h05: begin//bne
            re_1      = 1'b1;
            re_2      = 1'b1;
            reg_write = 1'b0;
            end
        6'h07: begin//bgtz
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b0;
            end   
        6'h06: begin//blez
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b0;
            end  
        6'h20:begin//lb
            alu_op    = 5'b01011;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_s;            
        end    
        6'h23:begin//lw
            alu_op    = 5'b01110;
            re_1      = 1'b1;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = rt;
            imm_o     = imm_s;            
        end
        6'h28:begin//sb
            alu_op    = 5'b01101;
            re_1      = 1'b1;
            re_2      = 1'b1;
            reg_write = 1'b0;           
        end
        6'h2B:begin//sw
            alu_op    = 5'b01001;
            re_1      = 1'b1;
            re_2      = 1'b1;
            reg_write = 1'b0;            
        end       
        6'h01:begin//bgez,bltz
            re_1       = 1'b1;
            re_2       = 1'b0;
            reg_write  = 1'b0;
        end                    
//J型指令
        6'h02:begin//j
            re_1      = 1'b0;
            re_2      = 1'b0;
            reg_write = 1'b0;
        end
        6'h03:begin//jal
            alu_op    = 5'b01111;
            re_1      = 1'b0;
            re_2      = 1'b0;
            reg_write = 1'b1;
            wb_addr   = 5'b11111;
        end       
        default:begin
        end
    endcase
end


//============================================================
// 分支/跳转判定逻辑
// branch=1 表示本条指令改变PC
// branch_address_o 为目标PC，link_address_o用于jal/jalr回写返回地址
//============================================================
always @(*)begin
    if(rst == 1'b0) begin
            branch           = 1'b0;
            branch_address_o = 32'h0;
            link_address_o   = 32'h0;
        end else begin
            branch           = 1'b0; 
            branch_address_o = 32'h0;
            link_address_o   = 32'h0;
        end
    case(opcode)
        6'h04:begin//beq
            if(reg_1==reg_2)begin
                branch           = 1'b1;
                branch_address_o = branch_addr;
            end
            else begin
            end
        end
        6'h05:begin//bne
            if(reg_1!=reg_2)begin
                branch           = 1'b1;
                branch_address_o = branch_addr;  
            end
            else begin
            end         
        end
        6'h07:begin//bgtz
            if(reg_1[31]==1'b0 && reg_1!=32'h0)begin
                branch           = 1'b1;
                branch_address_o = branch_addr;
            end
            else begin
            end           
        end
        6'h06:begin//blez
            if(reg_1[31]==1'b1 || reg_1==32'h0)begin
                branch           = 1'b1;
                branch_address_o = branch_addr;
            end
            else begin
            end
        end
        //bgez和bltz的区分
        6'h01:begin
            case(rt)
                5'b00001:begin//bgez
                    if(reg_1[31]==1'b0 || reg_1==32'h0)begin
                        branch           = 1'b1;
                        branch_address_o = branch_addr;
                    end
                    else begin
                    end
                end
                5'b00000:begin//bltz
                    if(reg_1[31]==1'b1 && reg_1!=32'h0)begin
                        branch           = 1'b1;
                        branch_address_o = branch_addr;
                    end
                    else begin
                    end
                end
                default:begin
                end
            endcase
        end
        6'h02:begin//j
            branch           = 1'b1;
            branch_address_o = jump_addr;
        end
        6'h03:begin//jal
            branch           = 1'b1; 
            branch_address_o = jump_addr;
            link_address_o   = next_pc+4'h4;
        end
        //R型里面的jr和jalr指令
        6'h00:begin
           case(func)
                6'h08:begin//jr
                    branch           = 1'b1; 
                    branch_address_o = reg_1;
                end
                6'h09:begin//jalr
                    branch           = 1'b1; 
                    branch_address_o = reg_1;
                    link_address_o   = next_pc+4'h4;
                end
                default:begin
                end
           endcase
           
        end
        default:begin
            branch           = 1'b0;
            branch_address_o = 32'h0;
            link_address_o   = 32'h0;
        end
    endcase

end

    reg    stallask_from_reg1;
    reg    stallask_from_reg2;
 
//============================================================
// 源操作数1选择优先级：
// 1) load-use命中 -> 请求暂停
// 2) EX前递
// 3) MEM前递
// 4) 寄存器堆读数
// 5) 立即数（当re_1=0）
//============================================================
always @(*)begin
    reg_1     = 32'h0;
    stallask_from_reg1 = 1'b0;
    if(rst==1'b0)begin
        reg_1 = 32'h0;
        stallask_from_reg1 = 1'b0;
    end
    else if(pre_inst_is_load==1'b1&&reg_1_addr==ex_wb_addr&&re_1==1'b1)begin
        stallask_from_reg1 = 1'b1;
    end
    else if(re_1==1'b1&&ex_reg_write==1'b1&&reg_1_addr==ex_wb_addr)begin
        reg_1 = ex_wb_data;
    end
    else if(mem_reg_write==1'b1&&reg_1_addr==mem_wb_addr)begin
        reg_1 = mem_wb_data;
    end
    else if(re_1==1'b1)begin
        reg_1 = reg_1_data;
    end
    else if(re_1==1'b0)begin
        reg_1 = imm_o;
    end
    else begin
        reg_1 =32'h0;
    end
end   
    
//============================================================
// 源操作数2选择优先级同上（对应rt通路）
//============================================================
always @(*)begin
    reg_2     = 32'h0;
    stallask_from_reg2 = 1'b0;  
    if(rst==1'b0)begin
        reg_2 = 32'h0;
        stallask_from_reg2 = 1'b0;
    end
    else if(pre_inst_is_load==1'b1&&reg_2_addr==ex_wb_addr&&re_2==1'b1)begin
        stallask_from_reg2 = 1'b1;
    end
    else if(re_2==1'b1&&ex_reg_write==1'b1&&ex_wb_addr==reg_2_addr)begin
        reg_2 = ex_wb_data;
    end
    else if(mem_reg_write==1'b1&&reg_2_addr==mem_wb_addr)begin
        reg_2 = mem_wb_data;
    end
    else if(re_2==1'b1)begin
        reg_2 = reg_2_data;
    end
    else if(re_2==1'b0)begin
        reg_2 = imm_o;
    end
    else begin
        reg_2 =32'h0;
    end
end  
    // 任一源操作数检测到load-use相关冒险时，请求暂停流水线
    assign stallask = rst? (stallask_from_reg1 | stallask_from_reg2) : 1'b0;
//流水线暂停语句待写(已写)


/*always @(*)begin
    rs_addr    =  5'd0;
    rt_addr    =  5'd0;
    rd_addr    =  5'd0;
    shamt      =  5'd0;
    imm        =  32'd0;
    alu_op     =  4'b0000;
    reg_dst    =  1'b0;
    reg_write  =  1'b0;
    alu_src    =  1'b0;
    mem_read   =  1'b0;
    mem_write  =  1'b0;
    mem_to_reg =  1'b0;
    branch     =  1'b0;
    branch_type=  3'b000;
    ext_type   =  3'b000;
    byte_en    =  1'b0;
    jr_en      =  1'b0;
    al_en      =  1'b0;
    jump       =  1'b0;
    
    case(opcode)
    
        6'h00:begin   //R型指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        rd_addr   = inst_i[15:11];
        shamt     = inst_i[10:6];
        reg_write = 1'b1;
        reg_dst   = 1'b1;
        alu_op    = 4'b0000;
        if(funct == 6'h08) begin    //jr指令
            jr_en      = 1'b1;      // R型跳转使能有效
            reg_write  = 1'b0;      //不写回寄存器返回地址
        end
        else if(funct==6'h09)begin  //jalr指令
            jr_en      = 1'b1;      //R型跳转使能有效    
            al_en      = 1'b1;      //把返回地址写回使能有效
            reg_write  = 1'b1;      //需要把地址写回寄存器
            reg_dst    = 1'b1;      //目标寄存器是rd
        end
        end
        
        6'h1C:begin   //mul指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        rd_addr   = inst_i[15:11];
        reg_write = 1'b1;
        reg_dst   = 1'b1;
        alu_op    = 4'b1000;
        end
        
        6'h09:begin  //addiu指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b010;
        alu_src   = 1'b1;
        reg_write = 1'b1;
        alu_op    = 4'b0001;
        end
        
        6'h0C:begin  //andi指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b001;
        alu_src   = 1'b1;
        reg_write = 1'b1;
        alu_op    = 4'b0010;
        end
        
        6'h0D:begin  //ori指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b001;
        alu_src   = 1'b1;
        reg_write = 1'b1;
        alu_op    = 4'b0011;
        end
        
        6'h0E:begin  //xori指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b001;
        alu_src   = 1'b1;
        reg_write = 1'b1;
        alu_op    = 4'b0100;
        end
        
        6'h0F:begin  //lui指令
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b011;
        reg_dst   = 1'b0;
        reg_write = 1'b1;
        alu_src   = 1'b1;
        alu_op    = 4'b0101;
        end
        
        6'h20:begin  //lb指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b010;
        mem_read  = 1'b1;
        mem_to_reg= 1'b1;
        reg_write = 1'b1;
        alu_src   = 1'b1;
        byte_en   = 1'b1;
        alu_op    = 4'b0001;
        end
        
        6'h23:begin  //lw指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b010;
        mem_read  = 1'b1;
        mem_to_reg= 1'b1;
        alu_src   = 1'b1;
        reg_write = 1'b1;
        alu_op    = 4'b0001;
        end
        
        6'h28:begin  //sb指令
        rs_addr   = inst_i[25:21];
        rt_addr   = inst_i[20:16];
        imm       = {16'h0,inst_i[15:0]};
        ext_type  = 3'b010;
        mem_write = 1'b1;
        alu_src   = 1'b1;
        byte_en   = 1'b1;
        alu_op    = 4'b0001;
        end
        
        6'h2B:begin  //sw指令
        rs_addr    = inst_i[25:21];
        rt_addr    = inst_i[20:16];
        imm        = {16'h0,inst_i[15:0]};
        alu_src    = 1'b1;
        mem_write  = 1'b1;
        alu_op     = 3'b001;
        end
        
        6'h05:begin  //bne指令
        rs_addr    = inst_i[25:21];
        rt_addr    = inst_i[20:16];
        imm        = {16'h0,inst_i[15:0]};
        ext_type   = 3'b100;
        branch_type= 3'b010;
        branch     = 2'b10;//传给pc计算器的信号
        alu_op     = 4'b1001;
        end
        
        6'h04:begin  //beq指令
        rs_addr    = inst_i[25:21];
        rt_addr    = inst_i[20:16];
        imm        = {16'h0,inst_i[15:0]};
        ext_type   = 3'b100;
        branch_type= 3'b001;
        branch     =2'b01;//传给pc计算器的信号
        alu_op     = 4'b1001;
        end
        
        6'h01:begin  
        case(inst_i[20:16])
            5'b00001:begin   //bgez指令
            rs_addr    = inst_i[25:21];
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b100;
            branch_type= 3'b011;
            branch     =2'b01;//传给pc计算器的信号
            alu_op     = 4'b0110; 
            end
            5'b00000:begin   //bltz指令
            rs_addr    = inst_i[25:21];
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b100;
            branch_type= 3'b110;
            branch     =2'b01;//传给pc计算器的信号
            alu_op     = 4'b1011; 
            end
        endcase
        end
        
        6'h07:begin   //bgtz指令
            rs_addr    = inst_i[25:21];
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b100;
            branch_type= 3'b100;
            branch     =2'b01;//传给pc计算器的信号
            alu_op     = 4'b0111;
        end
        
        6'h06:begin   //blez指令
            rs_addr    = inst_i[25:21];
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b100;
            branch_type= 3'b101;
            branch     =2'b01;//传给pc计算器的信号
            alu_op     = 4'b1010;
        end
        
        6'h02:begin   //j指令
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b101;
            jump       = 1'b1;
        end
        
        6'h03:begin   //jal指令
            rd_addr    = 5'd31;
            imm        = {16'h0,inst_i[15:0]};
            ext_type   = 3'b101;
            jump       = 1'b1;
            al_en     = 1'b1;//传给寄存堆的信号，把返回地址写回使能有效
            reg_write  = 1'b1;
            reg_dst    = 1'b1;
        end
    endcase
end

*/
endmodule
