`timescale 1ns / 1ps

// 流水线停顿控制模块
// RISC-V 完全兼容：Load-use 冒险、Cache Miss 停顿逻辑不变
module stall_ctrl(
    input   wire       rst,
    input   wire       stallask_from_id,   // ID 阶段请求停顿（Load-use）
    input   wire       stallask_from_if,   // IF 阶段请求停顿（ICache Miss）
    output  reg  [5:0] stall       
    );

    always@(*)begin
        if(rst == 1'b0) 
            stall = 6'b000000;         // 复位：不停顿
        else if (stallask_from_if) 
            stall = 6'b111111;         // ICache Miss：全部冻结
        else if (stallask_from_id) 
            stall = 6'b000011;         // Load-use 冒险：只冻结 PC、IF/ID
        else 
            stall = 6'b000000;         // 正常：不停顿
    end

endmodule