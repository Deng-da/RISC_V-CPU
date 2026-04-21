`timescale 1ns / 1ps

module student_top #(
    parameter P_SW_CNT  = 64,
    parameter P_LED_CNT = 32,
    parameter P_SEG_CNT = 40,
    parameter P_KEY_CNT = 8
) (
    input                         w_clk_50Mhz,
    input                         w_clk_rst,
    input  [P_KEY_CNT - 1:0]      virtual_key,
    input  [P_SW_CNT  - 1:0]      virtual_sw,
    output [P_LED_CNT - 1:0]      virtual_led,
    output [P_SEG_CNT - 1:0]      virtual_seg
);

    wire [31:0] seg_data;

    core_soc #(
        .CLK_FREQ_HZ(50_000_000)
    ) core_soc_inst (
        .clk              (w_clk_50Mhz),
        .rst              (w_clk_rst),
        .virtual_key      (virtual_key),
        .virtual_sw       (virtual_sw),
        .virtual_led      (virtual_led),
        .virtual_seg_data (seg_data)
    );

    display_seg seg_driver (
        .clk  (w_clk_50Mhz),
        .rst  (w_clk_rst),
        .s    (seg_data),
        .seg1 (virtual_seg[6:0]),
        .seg2 (virtual_seg[16:10]),
        .seg3 (virtual_seg[26:20]),
        .seg4 (virtual_seg[36:30]),
        .ans  ({virtual_seg[39:38], virtual_seg[29:28], virtual_seg[19:18], virtual_seg[9:8]})
    );

    assign virtual_seg[7]  = 1'b0;
    assign virtual_seg[17] = 1'b0;
    assign virtual_seg[27] = 1'b0;
    assign virtual_seg[37] = 1'b0;

endmodule
