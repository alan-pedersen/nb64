module nb64__lsu import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            mem_stall_i,
    input  logic            mem_flush_i,
    input  logic            global_flush_i,
    output logic            lsu_stall_o,

    input  logic            ex_valid_i,
    input  trap_ctrl_t      ex_trap_i,

    input  logic            ex_is_load_i,
    input  logic            ex_is_store_i,
    input  logic            ex_is_lr_i,
    input  logic            ex_is_sc_i,
    input  logic            ex_is_amo_i,
    input  amo_op_t         ex_amo_op_i,
    input  logic [2:0]      ex_size_i,
    input  logic            ex_unsigned_i,

    input  logic [XLEN-1:0] ex_addr_i,
    input  logic [XLEN-1:0] ex_wdata_i,

    input  logic [4:0]      ex_gpr_waddr_i,
    input  logic            ex_gpr_we_i,

    output logic            dtcm_req_o,
    output logic            dtcm_we_o,
    output logic [7:0]      dtcm_be_o,
    output logic [63:0]     dtcm_addr_o,
    output logic [63:0]     dtcm_wdata_o,
    input  logic [63:0]     dtcm_rdata_i

    output logic            mem_valid_o,
    output logic [XLEN-1:0] mem_result_o,
    output logic [4:0]      mem_gpr_waddr_o,
    output logic            mem_gpr_we_o,
    output trap_ctrl_t      mem_trap_o
);
    // ================================================================
    // Exception Detection
    // ================================================================

    logic       addr_misaligned;
    logic       load_misaligned;
    logic       store_misaligned;
    trap_ctrl_t trap_ctrl;

    always_comb begin
        unique case (ex_size_i[1:0])
            2'b01:   addr_misaligned = ex_addr_i[0];
            2'b10:   addr_misaligned = |ex_addr_i[1:0];
            2'b11:   addr_misaligned = |ex_addr_i[2:0];
            default: addr_misaligned = 0;
        endcase

        load_misaligned  = addr_misaligned && (ex_is_load_i  || ex_is_lr_i);
        store_misaligned = addr_misaligned && (ex_is_store_i || ex_is_sc_i || ex_is_amo_i); // EXC_STORE_AMO_ADDR_MISALIGNED
    end

    always_comb begin
        trap_ctrl = '0;

        if (ex_valid_i) begin
            if (ex_trap_i.valid) begin
                trap_ctrl = ex_trap_i;
            end
            else if (load_misaligned || store_misaligned) begin
                trap_ctrl.valid = 1;
                trap_ctrl.cause = store_misaligned ? EXC_STORE_AMO_ADDR_MISALIGNED : EXC_LOAD_ADDR_MISALIGNED;
                trap_ctrl.tval  = ex_addr_i;
            end
        end
    end

    // ================================================================
    // LR/SC
    // ================================================================

    // Reserves 8-byte blocks

    logic [XLEN-1:0] res_addr_q;
    logic            res_valid_q;
    logic            sc_success;

    assign sc_success = res_valid_q && (res_addr_q == {ex_addr_i[XLEN-1:3], 3'b000});

    always_ff @(posedge clk) begin
        if (rst || global_flush_i) begin
            res_valid_q <= 0;
        end
        else if (ex_valid_i && !trap_ctrl.valid) begin
            if (ex_is_lr_i) begin
                res_valid_q <= 1;
                res_addr_q  <= {ex_addr_i[XLEN-1:3], 3'b000};
            end
            else if (ex_is_sc_i) begin
                res_valid_q <= 0;
            end
        end
    end

    // ================================================================
    // AMOs
    // ================================================================

    typedef enum logic [1:0] {
        ST_AMO_IDLE   = 2'b00,
        ST_AMO_MODIFY = 2'b01,
        ST_AMO_WRITE  = 2'b10
    } amo_state_t;

    amo_state_t      amo_state_q;
    amo_state_t      next_amo_state;
    logic            amo_is_word;
    logic [63:0]     amo_rdata_q;
    logic [XLEN-1:0] amo_src_a;
    logic [XLEN-1:0] amo_src_b;
    logic [XLEN-1:0] amo_base_result;
    logic [XLEN-1:0] amo_result;

    assign amo_is_word = amo_op_i[5];
    assign amo_src_a   = XLEN'(amo_rdata_q >> {ex_addr_i[2:0], 3'b000});
    assign amo_src_b   = ex_wdata_i;

    always_comb begin
        lsu_stall_o    = 0;
        next_amo_state = amo_state_q;

        unique case (amo_state_q)
            ST_AMO_IDLE: begin
                if (ex_valid_i && !trap_ctrl.valid && ex_is_amo_i) begin
                    lsu_stall_o    = 1;
                    next_amo_state = ST_AMO_MODIFY;
                end
            end
            ST_AMO_MODIFY: begin
                lsu_stall_o    = 1;
                next_amo_state = ST_AMO_WRITE;
            end
            ST_AMO_WRITE: begin
                lsu_stall_o    = 0;
                next_amo_state = ST_AMO_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst || global_flush_i) begin
            amo_state_q <= ST_AMO_IDLE;
        end
        else begin
            amo_state_q <= next_amo_state;

            if (amo_state_q == ST_AMO_MODIFY) begin
                amo_rdata_q <= dtcm_rdata_i;
            end
        end
    end

    always_comb begin
        unique case (amo_op_i)
            AMO_SWAP, AMO_SWAPW: amo_base_result = amo_src_b;
            AMO_ADD,  AMO_ADDW:  amo_base_result = amo_src_a + amo_src_b;
            AMO_XOR,  AMO_XORW:  amo_base_result = amo_src_a ^ amo_src_b;
            AMO_AND,  AMO_ANDW:  amo_base_result = amo_src_a & amo_src_b;
            AMO_OR,   AMO_ORW:   amo_base_result = amo_src_a | amo_src_b;

            AMO_MIN, AMO_MINW: begin
                if (amo_is_word) amo_base_result = ($signed(amo_src_a[31:0]) < $signed(amo_src_b[31:0])) ? amo_src_a : amo_src_b;
                else             amo_base_result = ($signed(amo_src_a)       < $signed(amo_src_b))       ? amo_src_a : amo_src_b;
            end
            AMO_MAX, AMO_MAXW: begin
                if (amo_is_word) amo_base_result = ($signed(amo_src_a[31:0]) > $signed(amo_src_b[31:0])) ? amo_src_a : amo_src_b;
                else             amo_base_result = ($signed(amo_src_a)       > $signed(amo_src_b))       ? amo_src_a : amo_src_b;
            end
            AMO_MINU, AMO_MINUW: begin
                if (amo_is_word) amo_base_result = (amo_src_a[31:0] < amo_src_b[31:0]) ? amo_src_a : amo_src_b;
                else             amo_base_result = (amo_src_a       < amo_src_b)       ? amo_src_a : amo_src_b;
            end
            AMO_MAXU, AMO_MAXUW: begin
                if (amo_is_word) amo_base_result = (amo_src_a[31:0] > amo_src_b[31:0]) ? amo_src_a : amo_src_b;
                else             amo_base_result = (amo_src_a       > amo_src_b)       ? amo_src_a : amo_src_b;
            end

            default: amo_base_result = amo_src_b;
        endcase

        if (amo_is_word) amo_result = {{(XLEN-32){amo_base_result[31]}}, amo_base_result[31:0]};
        else             amo_result = amo_base_result;
    end

    // ================================================================
    // DTCM Transactions
    // ================================================================

    logic [7:0] base_be;

    always_comb begin
        dtcm_req_o   = 0;
        dtcm_we_o    = 0;
        dtcm_be_o    = 0;
        dtcm_addr_o  = 64'(ex_addr_i);
        dtcm_wdata_o = 64'(ex_wdata_i) << {ex_addr_i[2:0], 3'b000};

        if (ex_valid_i && !trap_ctrl.valid) begin
            if (amo_state_q == ST_AMO_IDLE) begin
                if (ex_is_load_i || ex_is_lr_i) begin
                    dtcm_req_o = 1;
                    dtcm_we_o  = 0;
                end
                else if (ex_is_store_i) begin
                    dtcm_req_o = 1;
                    dtcm_we_o  = 1;
                end
                else if (ex_is_sc_i && sc_success) begin
                    dtcm_req_o = 1;
                    dtcm_we_o  = 1;
                end
                else if (ex_is_amo_i) begin // Initial AMO Read
                    dtcm_req_o = 1;
                    dtcm_we_o  = 0;
                end
            end
            else if (amo_state_q == ST_AMO_WRITE) begin
                dtcm_req_o   = 1;
                dtcm_we_o    = 1;
                dtcm_wdata_o = 64'(amo_result) << {ex_addr_i[2:0], 3'b000};
            end
        end

        unique case (ex_size_i[1:0])
            2'b00: base_be = 8'h01;
            2'b01: base_be = 8'h03;
            2'b10: base_be = 8'h0F;
            2'b11: base_be = 8'hFF;
        endcase
        dtcm_be_o = base_be << ex_addr_i[2:0];
    end

    // ================================================================
    // LSU and Pipeline Outputs
    // ================================================================

    logic [2:0]      mem_size_q;
    logic [2:0]      mem_offset_q;
    logic            mem_unsigned_q;
    logic            mem_is_amo_q;
    logic            mem_is_sc_q;
    logic            mem_sc_success_q;

    logic [XLEN-1:0] shifted_rdata;
    logic [XLEN-1:0] final_rdata;

    always_ff @(posedge clk) begin
        if (rst || mem_flush_i || global_flush_i) begin
            mem_valid_o  <= 0;
            mem_gpr_we_o <= 0;
            mem_trap_o   <= '0;
        end
        else if (!mem_stall_i) begin
            mem_size_q       <= ex_size_i;
            mem_offset_q     <= ex_addr_i[2:0];
            mem_unsigned_q   <= ex_unsigned_i;
            mem_is_amo_q     <= ex_is_amo_i;
            mem_is_sc_q      <= ex_is_sc_i;
            mem_sc_success_q <= sc_success;
            mem_valid_o      <= ex_valid_i;
            mem_gpr_waddr_o  <= ex_gpr_waddr_i;
            mem_gpr_we_o     <= ex_gpr_we_i && ex_valid_i;
            mem_trap_o       <= trap_ctrl;
        end
    end

    always_comb begin
        if (mem_is_amo_q) shifted_rdata = XLEN'(amo_rdata_q  >> {mem_offset_q, 3'b000});
        else              shifted_rdata = XLEN'(dtcm_rdata_i >> {mem_offset_q, 3'b000});

        unique case (mem_size_q[1:0])
            2'b00: final_rdata = mem_unsigned_q ? {{(XLEN-8){1'b0}},  shifted_rdata[7:0]}  : {{(XLEN-8){shifted_rdata[7]}},   shifted_rdata[7:0]};
            2'b01: final_rdata = mem_unsigned_q ? {{(XLEN-16){1'b0}}, shifted_rdata[15:0]} : {{(XLEN-16){shifted_rdata[15]}}, shifted_rdata[15:0]};
            2'b10: final_rdata = mem_unsigned_q ? {{(XLEN-32){1'b0}}, shifted_rdata[31:0]} : {{(XLEN-32){shifted_rdata[31]}}, shifted_rdata[31:0]};
            2'b11: final_rdata = shifted_rdata;
        endcase

        if (mem_is_sc_q) mem_result_o = mem_sc_success_q ? 0 : 1;
        else             mem_result_o = final_rdata;
    end
endmodule
// Revisit: Masking mem_gpr_we_o with ex_valid_i or trap_ctrl.valid ??
