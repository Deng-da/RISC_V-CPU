`timescale 1ns / 1ps

module stall_ctrl(
    input   wire       rst,
    input   wire       stallask_from_id,
    input   wire       stallask_from_if,
    output  reg  [5:0] stall       
    );

    
    always@(*)begin
        if(rst==1'b0) stall =6'b000000;
        else if (stallask_from_if) begin
            // 【情况1：Cache Miss】
            // 必须冻结整个流水线，所有阶段保持原值
            stall = 6'b111111; 
        end else if (stallask_from_id) begin
            // 【情况2：Load-Use 冒险】
            // 冻结 PC 和 IF/ID，保持取指状态
            // ID/EX 不冻结(为0)，以便我们在 ID_EX 模块里插入气泡
            stall = 6'b000011; 
        end else begin
            stall = 6'b000000;
        end
    end
endmodule
