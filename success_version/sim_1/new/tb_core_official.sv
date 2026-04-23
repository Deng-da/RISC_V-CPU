`timescale 1ns / 1ps

module tb_core_official;
    localparam [31:0] DRAM_BASE    = 32'h8010_0000;
    localparam [31:0] DRAM_LAST    = 32'h8013_FFFF;
    localparam [31:0] SW_BASE      = 32'h8020_0000;
    localparam [31:0] KEY_BASE     = 32'h8020_0010;
    localparam [31:0] SEG_BASE     = 32'h8020_0020;
    localparam [31:0] LED_BASE     = 32'h8020_0040;
    localparam [31:0] COUNTER_BASE = 32'h8020_0050;

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

    wire [31:0] dram0 = dram_mem[0];
    wire [31:0] dram1 = dram_mem[1];
    wire [31:0] dram2 = dram_mem[2];
    wire [31:0] dram3 = dram_mem[3];
    wire [31:0] dram4 = dram_mem[4];
    wire [31:0] dram5 = dram_mem[5];
    wire [31:0] dram6 = dram_mem[6];
    wire [31:0] dram7 = dram_mem[7];

    reg [63:0] virtual_sw;
    reg [7:0]  virtual_key;
    reg [31:0] virtual_led;
    reg [31:0] seg_data;
    reg [31:0] counter_ms;
    reg [31:0] counter_ticks;
    reg        counter_running;
    integer    cycle_count;
    integer    done_seen;

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

    wire        perip_write    = ~perip_wen;
    wire        addr_is_dram   = (perip_addr >= DRAM_BASE) && (perip_addr <= DRAM_LAST);
    wire [15:0] dram_word_addr = perip_addr[17:2];
    wire        word_access    = (perip_addr[1:0] == 2'b00);
    wire        write_word     = perip_write && word_access && (perip_mask == 4'b0000);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $readmemh("../../../../coe/irom.mem", irom_mem);
        $readmemh("../../../../coe/dram.mem", dram_mem);
    end

    always @(*) begin
        perip_rdata = 32'h0;

        if (addr_is_dram) begin
            perip_rdata = dram_mem[dram_word_addr];
        end else begin
            case (perip_addr)
                SW_BASE:          perip_rdata = virtual_sw[31:0];
                SW_BASE + 32'h4:  perip_rdata = virtual_sw[63:32];
                KEY_BASE:         perip_rdata = {24'h0, virtual_key};
                SEG_BASE:         perip_rdata = seg_data;
                LED_BASE:         perip_rdata = 32'h0;
                COUNTER_BASE:     perip_rdata = counter_ms;
                default:          perip_rdata = 32'h0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            virtual_led     <= 32'h0;
            seg_data        <= 32'h0;
            counter_ms      <= 32'h0;
            counter_ticks   <= 32'h0;
            counter_running <= 1'b0;
        end else begin
            if (counter_running) begin
                if (counter_ticks == 32'd49_999) begin
                    counter_ticks <= 32'h0;
                    counter_ms    <= counter_ms + 32'd1;
                end else begin
                    counter_ticks <= counter_ticks + 32'd1;
                end
            end

            if (perip_write && addr_is_dram) begin
                if (!perip_mask[0]) dram_mem[dram_word_addr][7:0]   <= perip_wdata[7:0];
                if (!perip_mask[1]) dram_mem[dram_word_addr][15:8]  <= perip_wdata[15:8];
                if (!perip_mask[2]) dram_mem[dram_word_addr][23:16] <= perip_wdata[23:16];
                if (!perip_mask[3]) dram_mem[dram_word_addr][31:24] <= perip_wdata[31:24];
            end

            if (write_word && perip_addr == SEG_BASE) begin
                seg_data <= perip_wdata;
                $display("SEG_WRITE: time=%0t cycle=%0d data=%h", $time, cycle_count, perip_wdata);
            end

            if (write_word && perip_addr == LED_BASE) begin
                virtual_led <= perip_wdata;
                $display("LED_WRITE: time=%0t cycle=%0d data=%h", $time, cycle_count, perip_wdata);
            end

            if (write_word && perip_addr == COUNTER_BASE) begin
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

    initial begin
        rst         = 1'b1;
        virtual_sw  = 64'h0;
        virtual_key = 8'h0;
        cycle_count = 0;
        done_seen   = 0;

        repeat (8) @(posedge clk);
        rst = 1'b0;

        while (cycle_count < 200_000 && done_seen < 8) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if ((irom_addr == 32'h8000_000C) || ((dram_mem[0] + dram_mem[1]) >= 32'd37)) begin
                done_seen = done_seen + 1;
            end else begin
                done_seen = 0;
            end
        end

        $display("==== OFFICIAL TEST SUMMARY ====");
        $display("cycles      = %0d", cycle_count);
        $display("pc          = %h", irom_addr);
        $display("dram[0]     = %h  // likely pass count", dram_mem[0]);
        $display("dram[1]     = %h  // likely fail count", dram_mem[1]);
        $display("dram[2]     = %h", dram_mem[2]);
        $display("dram[3]     = %h", dram_mem[3]);
        $display("dram[4]     = %h", dram_mem[4]);
        $display("dram[5]     = %h", dram_mem[5]);
        $display("dram[6]     = %h", dram_mem[6]);
        $display("dram[7]     = %h", dram_mem[7]);
        $display("seg_data    = %h", seg_data);
        $display("virtual_led = %h", virtual_led);

        if (done_seen >= 8 && dram_mem[0] == 32'd37 && dram_mem[1] == 32'h0) begin
            $display("PASS: official ISA test reached 37 pass / 0 fail");
        end else if (done_seen >= 8) begin
            $display("FAIL: official ISA test stopped with unexpected pass/fail count");
        end else begin
            $display("FAIL: official ISA test timed out before reaching 37 total results");
        end

        $stop;
    end
endmodule
