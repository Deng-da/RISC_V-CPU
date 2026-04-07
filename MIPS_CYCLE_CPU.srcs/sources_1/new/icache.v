`timescale 1ns / 1ps
    module icache(
    input    wire          clk,
    input    wire          rst,        // 低有效复位
    input    wire  [31:0]  cpu_addr,
    input    wire          cpu_req,    // 低有效：0=请求有效（接pc.ce）
    output   reg   [31:0]  cpu_rdata,
    output   reg           cpu_stall,

    output   reg  [19:0]   sram_addr,
    output   reg           sram_ce_n,
    output   reg           sram_oe_n,
    input    wire [31:0]   sram_rdata
);

    parameter INDEX_WIDTH  = 8;
    parameter TAG_WIDTH    = 20;

    localparam IDLE      = 3'd0;
    localparam COMPARE   = 3'd1;
    localparam ALLOCATE  = 3'd2;

    reg [2:0] state, next_state;

    // 硬件友好：valid 单独寄存器复位；tag/data 不要求复位
    reg  [TAG_WIDTH-1:0]  tag_mem  [0:255];
    reg  [127:0]          data_mem [0:255];
    reg  [255:0]          valid;

    // 低有效请求 -> 高有效请求
    wire cpu_req_hi = ~cpu_req;

    wire [INDEX_WIDTH-1:0] index  = cpu_addr[11:4];
    wire [TAG_WIDTH-1:0]   tag    = cpu_addr[31:12];
    wire [1:0]             offset = cpu_addr[3:2];

    wire hit = valid[index] && (tag_mem[index] == tag);

    // miss 锁存
    reg [INDEX_WIDTH-1:0] miss_index;
    reg [TAG_WIDTH-1:0]   miss_tag;
    reg [17:0]            miss_block;   // cpu_addr[21:4]

    // refill
    reg [1:0]   refill_count;
    reg [127:0] refill_buffer;

    // ---------------- next_state ----------------
    // 核心思想：IDLE 只在"无请求"时停留；
    // 一旦 cpu_req_hi=1，就立即按 hit/miss 决定 COMPARE/ALLOCATE（不再慢一拍）
    always @(*) begin
        next_state = state;
        case(state)
            ALLOCATE: begin
                if (refill_count == 2'd3)
                    next_state = cpu_req_hi ? COMPARE : IDLE;
                else
                    next_state = ALLOCATE;
            end

            // IDLE 和 COMPARE 在有请求时同样做 compare
            IDLE, COMPARE: begin
                if (!cpu_req_hi) begin
                    next_state = IDLE;
                end else if (!hit) begin
                    next_state = ALLOCATE;
                end else begin
                    next_state = COMPARE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // ---------------- 组合输出 ----------------
    always @(*) begin
        cpu_stall = 1'b0;
        cpu_rdata = 32'h0;

        sram_ce_n = 1'b1;
        sram_oe_n = 1'b1;
        sram_addr = 20'd0;

        case(state)
            // ★关键改动：IDLE 也参与握手
            // 有请求就立即 compare：hit 出指令，miss 立刻 stall（避免慢一拍）
            IDLE, COMPARE: begin
                if (cpu_req_hi) begin
                    if (hit) begin
                        cpu_stall = 1'b0;
                        case(offset)
                            2'b00: cpu_rdata = data_mem[index][31:0];
                            2'b01: cpu_rdata = data_mem[index][63:32];
                            2'b10: cpu_rdata = data_mem[index][95:64];
                            2'b11: cpu_rdata = data_mem[index][127:96];
                        endcase
                    end else begin
                        cpu_stall = 1'b1; // miss 当周期就 stall
                    end
                end
            end

            ALLOCATE: begin
                cpu_stall = 1'b1;
                sram_ce_n = 1'b0;
                sram_oe_n = 1'b0;
                sram_addr = {miss_block, refill_count};
            end
        endcase
    end

    // ---------------- 时序逻辑 ----------------
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            state         <= IDLE;      // 保留 IDLE：未来你可以真的"无请求"
            valid         <= 256'b0;

            miss_index    <= 0;
            miss_tag      <= 0;
            miss_block    <= 0;

            refill_count  <= 2'd0;
            refill_buffer <= 128'd0;
        end else begin
            state <= next_state;

            // ★关键改动：在 IDLE 或 COMPARE 看到 miss，都要锁存现场
            if ((state == IDLE || state == COMPARE) && cpu_req_hi && !hit) begin
                miss_index    <= index;
                miss_tag      <= tag;
                miss_block    <= cpu_addr[21:4];
                refill_count  <= 2'd0;
                refill_buffer <= 128'd0;
            end

            if (state == ALLOCATE) begin
                case(refill_count)
                    2'd0: refill_buffer[31:0]   <= sram_rdata;
                    2'd1: refill_buffer[63:32]  <= sram_rdata;
                    2'd2: refill_buffer[95:64]  <= sram_rdata;
                    2'd3: begin
                        refill_buffer[127:96] <= sram_rdata;

                        tag_mem[miss_index]  <= miss_tag;
                        data_mem[miss_index] <= {sram_rdata, refill_buffer[95:0]};
                        valid[miss_index]    <= 1'b1;
                    end
                endcase

                if (refill_count != 2'd3)
                    refill_count <= refill_count + 2'd1;
            end
        end
    end

endmodule