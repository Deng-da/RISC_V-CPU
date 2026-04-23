`timescale 1ns / 1ps

module core_soc #(
    parameter integer CLK_FREQ_HZ = 50_000_000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  virtual_key,
    input  wire [63:0] virtual_sw,
    output reg  [31:0] virtual_led,
    output reg  [31:0] virtual_seg_data
);

    localparam [31:0] DRAM_BASE    = 32'h8010_0000;
    localparam [31:0] DRAM_LAST    = 32'h8013_FFFF;
    localparam [31:0] SW_BASE      = 32'h8020_0000;
    localparam [31:0] KEY_BASE     = 32'h8020_0010;
    localparam [31:0] SEG_BASE     = 32'h8020_0020;
    localparam [31:0] LED_BASE     = 32'h8020_0040;
    localparam [31:0] COUNTER_BASE = 32'h8020_0050;

    wire [31:0] irom_addr;
    wire [31:0] irom_data;
    wire [31:0] perip_addr;
    wire        perip_we_n;
    wire [3:0]  perip_mask_n;
    wire [31:0] perip_wdata;
    reg  [31:0] perip_rdata;

    Core_cpu Core_cpu_inst (
        .cpu_clk     (clk),
        .cpu_rst     (rst),
        .irom_addr   (irom_addr),
        .irom_data   (irom_data),
        .perip_addr  (perip_addr),
        .perip_wen   (perip_we_n),
        .perip_mask  (perip_mask_n),
        .perip_wdata (perip_wdata),
        .perip_rdata (perip_rdata)
    );

    // Expected Vivado IP: Distributed Memory Generator, ROM, 4096 x 32, async read.
    irom irom_inst (
        .a   (irom_addr[13:2]),
        .spo (irom_data)
    );

    wire        perip_write = ~perip_we_n;
    wire        addr_is_dram = (perip_addr >= DRAM_BASE) && (perip_addr <= DRAM_LAST);
    wire [15:0] dram_word_addr = perip_addr[17:2];
    wire [3:0]  dram_byte_we = addr_is_dram && perip_write ? ~perip_mask_n : 4'b0000;
    wire [31:0] dram_rdata;
    wire [31:0] dram_byte_mask = {
        {8{dram_byte_we[3]}},
        {8{dram_byte_we[2]}},
        {8{dram_byte_we[1]}},
        {8{dram_byte_we[0]}}
    };
    wire [31:0] dram_wdata = (dram_rdata & ~dram_byte_mask) | (perip_wdata & dram_byte_mask);

    // Expected Vivado IP: Distributed Memory Generator, single-port RAM,
    // 65536 x 32, async read, sync write, one-bit write enable.
    dram dram_inst (
        .a   (dram_word_addr),
        .d   (dram_wdata),
        .clk (clk),
        .we  (|dram_byte_we),
        .spo (dram_rdata)
    );

    localparam integer MS_TICKS = (CLK_FREQ_HZ / 1000);

    reg [31:0] counter_ms;
    reg [31:0] counter_ticks;
    reg        counter_running;

    wire word_access = (perip_addr[1:0] == 2'b00);
    wire write_word  = perip_write && word_access && (perip_mask_n == 4'b0000);

    always @(posedge clk) begin
        if (rst) begin
            virtual_led      <= 32'h0;
            virtual_seg_data <= 32'h0;
            counter_ms       <= 32'h0;
            counter_ticks    <= 32'h0;
            counter_running  <= 1'b0;
        end else begin
            if (counter_running) begin
                if (counter_ticks == MS_TICKS - 1) begin
                    counter_ticks <= 32'h0;
                    counter_ms    <= counter_ms + 32'd1;
                end else begin
                    counter_ticks <= counter_ticks + 32'd1;
                end
            end

            if (write_word && (perip_addr == SEG_BASE)) begin
                virtual_seg_data <= perip_wdata;
            end

            if (write_word && (perip_addr == LED_BASE)) begin
                virtual_led <= perip_wdata;
            end

            if (write_word && (perip_addr == COUNTER_BASE)) begin
                if (perip_wdata == 32'h8000_0000) begin
                    counter_ms      <= 32'h0;
                    counter_ticks   <= 32'h0;
                    counter_running <= 1'b1;
                end else if (perip_wdata == 32'hFFFF_FFFF) begin
                    counter_running <= 1'b0;
                end
            end
        end
    end

    always @(*) begin
        perip_rdata = 32'h0;

        if (addr_is_dram) begin
            perip_rdata = dram_rdata;
        end else begin
            case (perip_addr)
                SW_BASE:          perip_rdata = virtual_sw[31:0];
                SW_BASE + 32'h4:  perip_rdata = virtual_sw[63:32];
                KEY_BASE:         perip_rdata = {24'h0, virtual_key};
                SEG_BASE:         perip_rdata = virtual_seg_data;
                LED_BASE:         perip_rdata = 32'h0;
                COUNTER_BASE:     perip_rdata = counter_ms;
                default:          perip_rdata = 32'h0;
            endcase
        end
    end

endmodule
