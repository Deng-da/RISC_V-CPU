`timescale 1ns / 1ps

module tb_cpu_smoke;
    reg         clk;
    reg         rst;
    reg  [7:0]  virtual_key;
    reg  [63:0] virtual_sw;
    wire [31:0] virtual_led;
    wire [39:0] virtual_seg;

    student_top dut (
        .w_clk_50Mhz (clk),
        .w_clk_rst   (rst),
        .virtual_key (virtual_key),
        .virtual_sw  (virtual_sw),
        .virtual_led (virtual_led),
        .virtual_seg (virtual_seg)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        virtual_key = 8'h00;
        virtual_sw = 64'h0;

        repeat (8) @(posedge clk);
        rst = 1'b0;

        repeat (100) @(posedge clk);

        if (virtual_led !== 32'h1234_5678) begin
            $display("FAIL: virtual_led = %h, expected 12345678", virtual_led);
            $finish;
        end

        if (dut.seg_data !== 32'h1234_5678) begin
            $display("FAIL: seg_data = %h, expected 12345678", dut.seg_data);
            $finish;
        end

        $display("PASS: CPU smoke test wrote LED and SEG = 0x12345678");
        $finish;
    end
endmodule
