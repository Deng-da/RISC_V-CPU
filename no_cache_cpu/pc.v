`timescale 1ns / 1ps
module pc(
    input  wire        clk,
    input  wire        rst,      // 已改为：高有效复位（比赛标准）
    output reg [31:0]  pc,
    output reg         ce,       // 低有效：0=取指有效（不变）
    input  wire        branch,
    input  wire [31:0] branch_address,
    input  wire [5:0]  stall
);

always @(posedge clk ) begin
    if(rst) begin             // ########## 改为 高有效复位 ##########
        pc <= 32'h8000_0000;  // 符合比赛 IROM 起始地址 ✅
        ce <= 1'b0;           // 复位后立即允许取指 ✅
    end else begin
        ce <= 1'b0;           // 始终取指（无 ICache 正确）✅
        
        if(!stall[0]) begin   // 流水线暂停逻辑保持不变
            pc <= branch ? branch_address : (pc + 32'd4);
        end
    end
end

endmodule