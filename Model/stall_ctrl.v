`timescale 1ns / 1ps

module stall_ctrl(
    input wire        rst,          // 高有效复位（比赛标准）
    input wire        stallask_from_id,
    output reg [5:0]  stall
);

always@(*) begin
    // ====================== 关键修改：高有效复位 ======================
    if(rst == 1'b1) begin
        stall = 6'b000000;
    end 
    else if (stallask_from_id) begin
        stall = 6'b000011;
    end 
    else begin
        stall = 6'b000000;
    end
end

endmodule