`timescale 1ns / 1ps

module tb_core_regression;
    localparam [31:0] DRAM_BASE = 32'h8010_0000;
    localparam [31:0] DRAM_LAST = 32'h8013_FFFF;
    localparam [31:0] SW_BASE   = 32'h8020_0000;
    localparam [31:0] KEY_BASE  = 32'h8020_0010;
    localparam [31:0] SEG_BASE  = 32'h8020_0020;
    localparam [31:0] LED_BASE  = 32'h8020_0040;
    localparam [31:0] PASS_WORD = 32'h1234_5678;
    localparam [31:0] FAIL_WORD = 32'hDEAD_C0DE;

    reg         clk;
    reg         rst;
    wire [31:0] irom_addr;
    wire [31:0] irom_data;
    wire [31:0] perip_addr;
    wire        perip_wen;
    wire [3:0]  perip_mask;
    wire [31:0] perip_wdata;
    reg  [31:0] perip_rdata;

    reg [31:0] irom_mem [0:4095];
    reg [31:0] dram_mem [0:65535];
    reg [31:0] led_reg;
    reg [31:0] seg_reg;
    integer cycle;
    integer fd;
    string irom_mem_path;
    string dram_mem_path;

    Core_cpu dut (
        .cpu_clk     (clk),
        .cpu_rst     (rst),
        .irom_addr   (irom_addr),
        .irom_data   (irom_data),
        .perip_addr  (perip_addr),
        .perip_wen   (perip_wen),
        .perip_mask  (perip_mask),
        .perip_wdata (perip_wdata),
        .perip_rdata (perip_rdata)
    );

    assign irom_data = irom_mem[irom_addr[13:2]];

    wire addr_is_dram = (perip_addr >= DRAM_BASE) && (perip_addr <= DRAM_LAST);
    wire [15:0] dram_word_addr = perip_addr[17:2];
    wire perip_write = ~perip_wen;

    initial begin
        if (!$value$plusargs("IROM_MEM=%s", irom_mem_path)) begin
            irom_mem_path = "../../../../coe/rv32i_mini.mem";
            fd = $fopen(irom_mem_path, "r");
            if (fd == 0) begin
                irom_mem_path = "../coe/rv32i_mini.mem";
                fd = $fopen(irom_mem_path, "r");
                if (fd == 0) begin
                    irom_mem_path = "coe/rv32i_mini.mem";
                end else begin
                    $fclose(fd);
                end
            end else begin
                $fclose(fd);
            end
        end

        if (!$value$plusargs("DRAM_MEM=%s", dram_mem_path)) begin
            dram_mem_path = "../../../../coe/dram_zero.mem";
            fd = $fopen(dram_mem_path, "r");
            if (fd == 0) begin
                dram_mem_path = "../coe/dram_zero.mem";
                fd = $fopen(dram_mem_path, "r");
                if (fd == 0) begin
                    dram_mem_path = "coe/dram_zero.mem";
                end else begin
                    $fclose(fd);
                end
            end else begin
                $fclose(fd);
            end
        end

        $display("INFO: loading IROM from %s", irom_mem_path);
        $display("INFO: loading DRAM from %s", dram_mem_path);
        $readmemh(irom_mem_path, irom_mem);
        $readmemh(dram_mem_path, dram_mem);
    end

    always @(*) begin
        perip_rdata = 32'h0;

        if (addr_is_dram) begin
            perip_rdata = dram_mem[dram_word_addr];
        end else begin
            case (perip_addr)
                SW_BASE:      perip_rdata = 32'h0;
                SW_BASE + 4:  perip_rdata = 32'h0;
                KEY_BASE:     perip_rdata = 32'h0;
                SEG_BASE:     perip_rdata = seg_reg;
                LED_BASE:     perip_rdata = led_reg;
                default:      perip_rdata = 32'h0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            led_reg <= 32'h0;
            seg_reg <= 32'h0;
        end else if (perip_write) begin
            if (addr_is_dram) begin
                if (!perip_mask[0]) dram_mem[dram_word_addr][7:0]   <= perip_wdata[7:0];
                if (!perip_mask[1]) dram_mem[dram_word_addr][15:8]  <= perip_wdata[15:8];
                if (!perip_mask[2]) dram_mem[dram_word_addr][23:16] <= perip_wdata[23:16];
                if (!perip_mask[3]) dram_mem[dram_word_addr][31:24] <= perip_wdata[31:24];
            end else if (perip_mask == 4'b0000) begin
                if (perip_addr == SEG_BASE) begin
                    seg_reg <= perip_wdata;
                end
                if (perip_addr == LED_BASE) begin
                    led_reg <= perip_wdata;
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        cycle = 0;

        repeat (8) @(posedge clk);
        rst = 1'b0;

        while (cycle < 2000 && led_reg != PASS_WORD && led_reg != FAIL_WORD) begin
            @(posedge clk);
            cycle = cycle + 1;
        end

        if (led_reg == PASS_WORD && seg_reg == PASS_WORD) begin
            $display("PASS: RV32I mini regression completed in %0d cycles", cycle);
            $finish;
        end

        if (led_reg == FAIL_WORD || seg_reg == FAIL_WORD) begin
            $display("FAIL: regression program reported failure led=%h seg=%h cycle=%0d", led_reg, seg_reg, cycle);
            $finish;
        end

        $display("FAIL: timeout led=%h seg=%h pc=%h cycle=%0d", led_reg, seg_reg, irom_addr, cycle);
        $finish;
    end
endmodule
