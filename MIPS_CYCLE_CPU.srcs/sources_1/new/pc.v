module pc(
    input  wire       clk,
    input  wire       rst,      // 低有效
    output reg [31:0] pc,
    output reg        ce,       // 低有效：0=取指有效
    input  wire       branch,
    input  wire[31:0] branch_address,
    input  wire[5:0]  stall
);
always @(posedge clk ) begin
    if(!rst) begin
        pc <= 32'h8000_0000;
        ce <= 1'b0;            // 复位后就让取指有效（低有效）
    end else begin
        ce <= 1'b0;            // 一直取指（如果你就是想一直有效）
        if(!stall[0]) begin
            pc <= branch ? branch_address : (pc + 32'd4);
        end
    end
end
endmodule