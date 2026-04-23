`timescale 1ns / 1ps

module tb_core_wave;
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
    reg [31:0] virtual_led;
    reg [31:0] seg_data;
    reg [31:0] last_write_addr;
    reg [31:0] last_write_data;
    reg [3:0]  last_write_mask;
    reg [31:0] cycle_count;
    reg [1:0]  test_status;       // 0=running, 1=pass, 2=fail, 3=timeout

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
    wire bus_write = ~perip_wen;
    wire bus_read  = perip_wen;

    // Wave-friendly pipeline aliases. These are only for simulation viewing.
    wire [31:0] if_pc          = dut.u_myCPU.pc_to_if;
    wire [31:0] if_inst        = irom_data;
    wire [31:0] id_pc          = dut.u_myCPU.id_pc;
    wire [31:0] id_inst        = dut.u_myCPU.if_id_inst_o;
    wire [4:0]  id_rs1         = id_inst[19:15];
    wire [4:0]  id_rs2         = id_inst[24:20];
    wire [4:0]  id_rd          = id_inst[11:7];
    wire [31:0] id_reg1        = dut.u_myCPU.reg_1_o;
    wire [31:0] id_reg2        = dut.u_myCPU.reg_2_o;
    wire [31:0] id_store_data  = dut.u_myCPU.id_store_data;
    wire [4:0]  id_alu_op      = dut.u_myCPU.id_alu_op;
    wire [3:0]  id_mem_op      = dut.u_myCPU.id_mem_op;
    wire        id_reg_write   = dut.u_myCPU.id_reg_write;
    wire [4:0]  id_wb_addr     = dut.u_myCPU.id_wb_addr;
    wire        branch_taken   = dut.u_myCPU.branch;
    wire [31:0] branch_target  = dut.u_myCPU.branch_address;
    wire [5:0]  stall          = dut.u_myCPU.stall;
    wire        stall_any      = |stall;

    wire [31:0] ex_pc          = dut.u_myCPU.ex_pc;
    wire [31:0] ex_reg1        = dut.u_myCPU.ex_reg_1;
    wire [31:0] ex_reg2        = dut.u_myCPU.ex_reg_2;
    wire [31:0] ex_store_data  = dut.u_myCPU.ex_store_data;
    wire [4:0]  ex_alu_op      = dut.u_myCPU.ex_aluop;
    wire [3:0]  ex_mem_op      = dut.u_myCPU.ex_mem_op;
    wire [31:0] ex_mem_addr    = dut.u_myCPU.ex_mem_addr;
    wire [31:0] ex_mem_data    = dut.u_myCPU.ex_mem_data;
    wire [31:0] ex_wb_data     = dut.u_myCPU.ex_wb_data_o;
    wire [4:0]  ex_wb_addr     = dut.u_myCPU.ex_wb_addr_o;
    wire        ex_reg_write   = dut.u_myCPU.ex_reg_write_o;

    wire [31:0] mem_pc         = dut.u_myCPU.mem_pc;
    wire [3:0]  mem_op         = dut.u_myCPU.mem_op_o;
    wire [31:0] mem_addr       = dut.u_myCPU.mem_addr;
    wire [31:0] mem_data       = dut.u_myCPU.mem_data;
    wire [31:0] mem_wb_data    = dut.u_myCPU.mem_wb_data_o;
    wire [4:0]  mem_wb_addr    = dut.u_myCPU.mem_wb_addr_o;
    wire        mem_reg_write  = dut.u_myCPU.mem_reg_write_o;

    wire [31:0] wb_data        = dut.u_myCPU.wb_data;
    wire [4:0]  wb_addr        = dut.u_myCPU.wb_addr;
    wire        wb_reg_write   = dut.u_myCPU.wb_reg_write;

    wire [31:0] x00_zero = dut.u_myCPU.reg_file1.registers[0];
    wire [31:0] x01_ra   = dut.u_myCPU.reg_file1.registers[1];
    wire [31:0] x02_sp   = dut.u_myCPU.reg_file1.registers[2];
    wire [31:0] x03_gp   = dut.u_myCPU.reg_file1.registers[3];
    wire [31:0] x04_tp   = dut.u_myCPU.reg_file1.registers[4];
    wire [31:0] x05_t0   = dut.u_myCPU.reg_file1.registers[5];
    wire [31:0] x06_t1   = dut.u_myCPU.reg_file1.registers[6];
    wire [31:0] x07_t2   = dut.u_myCPU.reg_file1.registers[7];
    wire [31:0] x08_s0   = dut.u_myCPU.reg_file1.registers[8];
    wire [31:0] x09_s1   = dut.u_myCPU.reg_file1.registers[9];
    wire [31:0] x10_a0   = dut.u_myCPU.reg_file1.registers[10];
    wire [31:0] x11_a1   = dut.u_myCPU.reg_file1.registers[11];
    wire [31:0] x12_a2   = dut.u_myCPU.reg_file1.registers[12];
    wire [31:0] x13_a3   = dut.u_myCPU.reg_file1.registers[13];
    wire [31:0] x14_a4   = dut.u_myCPU.reg_file1.registers[14];
    wire [31:0] x15_a5   = dut.u_myCPU.reg_file1.registers[15];
    wire [31:0] x16_a6   = dut.u_myCPU.reg_file1.registers[16];
    wire [31:0] x17_a7   = dut.u_myCPU.reg_file1.registers[17];
    wire [31:0] x18_s2   = dut.u_myCPU.reg_file1.registers[18];
    wire [31:0] x19_s3   = dut.u_myCPU.reg_file1.registers[19];
    wire [31:0] x20_s4   = dut.u_myCPU.reg_file1.registers[20];
    wire [31:0] x21_s5   = dut.u_myCPU.reg_file1.registers[21];
    wire [31:0] x22_s6   = dut.u_myCPU.reg_file1.registers[22];
    wire [31:0] x23_s7   = dut.u_myCPU.reg_file1.registers[23];
    wire [31:0] x24_s8   = dut.u_myCPU.reg_file1.registers[24];
    wire [31:0] x25_s9   = dut.u_myCPU.reg_file1.registers[25];
    wire [31:0] x26_s10  = dut.u_myCPU.reg_file1.registers[26];
    wire [31:0] x27_s11  = dut.u_myCPU.reg_file1.registers[27];
    wire [31:0] x28_t3   = dut.u_myCPU.reg_file1.registers[28];
    wire [31:0] x29_t4   = dut.u_myCPU.reg_file1.registers[29];
    wire [31:0] x30_t5   = dut.u_myCPU.reg_file1.registers[30];
    wire [31:0] x31_t6   = dut.u_myCPU.reg_file1.registers[31];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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
                SEG_BASE:     perip_rdata = seg_data;
                LED_BASE:     perip_rdata = virtual_led;
                default:      perip_rdata = 32'h0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            virtual_led     <= 32'h0;
            seg_data        <= 32'h0;
            last_write_addr <= 32'h0;
            last_write_data <= 32'h0;
            last_write_mask <= 4'hf;
        end else if (bus_write) begin
            last_write_addr <= perip_addr;
            last_write_data <= perip_wdata;
            last_write_mask <= perip_mask;

            if (addr_is_dram) begin
                if (!perip_mask[0]) dram_mem[dram_word_addr][7:0]   <= perip_wdata[7:0];
                if (!perip_mask[1]) dram_mem[dram_word_addr][15:8]  <= perip_wdata[15:8];
                if (!perip_mask[2]) dram_mem[dram_word_addr][23:16] <= perip_wdata[23:16];
                if (!perip_mask[3]) dram_mem[dram_word_addr][31:24] <= perip_wdata[31:24];
            end else if (perip_mask == 4'b0000) begin
                if (perip_addr == SEG_BASE) begin
                    seg_data <= perip_wdata;
                end
                if (perip_addr == LED_BASE) begin
                    virtual_led <= perip_wdata;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst && stall != 6'b000000) begin
            $display("STALL: time=%0t if_pc=%h id_pc=%h id_inst=%h ex_pc=%h ex_mem_op=%0d ex_wb_addr=x%0d stall=%b",
                     $time, if_pc, id_pc, id_inst, ex_pc, ex_mem_op, ex_wb_addr, stall);
        end
    end

    initial begin
        rst = 1'b1;
        cycle_count = 32'd0;
        test_status = 2'd0;

        repeat (8) @(posedge clk);
        rst = 1'b0;

        while (cycle_count < 2000 && test_status == 2'd0) begin
            @(posedge clk);
            cycle_count = cycle_count + 32'd1;

            if (virtual_led == PASS_WORD && seg_data == PASS_WORD) begin
                test_status = 2'd1;
            end else if (virtual_led == FAIL_WORD || seg_data == FAIL_WORD) begin
                test_status = 2'd2;
            end
        end

        if (test_status == 2'd1) begin
            $display("PASS: waveform test reached LED/SEG = %h at cycle %0d", PASS_WORD, cycle_count);
        end else if (test_status == 2'd2) begin
            $display("FAIL: program reported failure led=%h seg=%h pc=%h cycle=%0d",
                     virtual_led, seg_data, if_pc, cycle_count);
        end else begin
            test_status = 2'd3;
            $display("FAIL: timeout led=%h seg=%h pc=%h cycle=%0d",
                     virtual_led, seg_data, if_pc, cycle_count);
        end

        repeat (20) @(posedge clk);
        $stop;
    end
endmodule
