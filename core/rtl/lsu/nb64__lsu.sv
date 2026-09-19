module nb64__lsu import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            stall_i,
    input  logic            flush_i,
    input  logic            kill_i,  // Kills multi-cycle AMOs
    output logic            stall_o, // LSU requesting upstream stall

    input  logic            valid_i,
    input  logic [XLEN-1:0] pc_i,

    input  lsu_ctrl_t       lsu_ctrl_i,
    input  gpr_ctrl_t       gpr_ctrl_i,
    input  csr_ctrl_t       csr_ctrl_i,
    input  exc_ctrl_t       exc_ctrl_i,

    input  logic [XLEN-1:0] ex_result_i,
    input  logic [XLEN-1:0] mem_addr_i,
    input  logic [XLEN-1:0] mem_wdata_i,
    input  logic [XLEN-1:0] csr_wdata_i,

    output logic            dtcm_req_o,
    output logic            dtcm_we_o,
    output logic [7:0]      dtcm_be_o,
    output logic [63:0]     dtcm_addr_o,
    output logic [63:0]     dtcm_wdata_o,
    input  logic [63:0]     dtcm_rdata_i,

    output logic            valid_o,
    output logic [XLEN-1:0] pc_o,

    output gpr_ctrl_t       gpr_ctrl_o,
    output csr_ctrl_t       csr_ctrl_o,
    output exc_ctrl_t       exc_ctrl_o,

    output logic [XLEN-1:0] result_o,
    output logic [XLEN-1:0] csr_wdata_o
);
    // ================================================================
    // Exception Detection
    // ================================================================

    logic       addr_misaligned;
    logic       load_misaligned;
    logic       store_misaligned;
    exc_ctrl_t  exc_ctrl;

    always_comb begin
        unique case (lsu_ctrl_i.size[1:0])
            2'b01:   addr_misaligned = mem_addr_i[0];
            2'b10:   addr_misaligned = |mem_addr_i[1:0];
            2'b11:   addr_misaligned = |mem_addr_i[2:0];
            default: addr_misaligned = 0;
        endcase

        // EXC_LOAD_ADDR_MISALIGNED and EXC_STORE_AMO_ADDR_MISALIGNED
        load_misaligned  = addr_misaligned && (lsu_ctrl_i.is_load  || lsu_ctrl_i.is_lr);
        store_misaligned = addr_misaligned && (lsu_ctrl_i.is_store || lsu_ctrl_i.is_sc || lsu_ctrl_i.is_amo);
    end

    always_comb begin
        exc_ctrl = exc_ctrl_i;

        if (valid_i && !exc_ctrl_i.valid) begin
            if (load_misaligned || store_misaligned) begin
                exc_ctrl.valid = 1;
                exc_ctrl.cause = store_misaligned ? EXC_STORE_AMO_ADDR_MISALIGNED : EXC_LOAD_ADDR_MISALIGNED;
                exc_ctrl.tval  = mem_addr_i;
            end
        end
    end

    // ================================================================
    // LR/SC
    // ================================================================

    // Reserves 8-byte blocks

    logic [XLEN-1:3] res_addr_q;
    logic            res_valid_q;
    logic            sc_success;

    assign sc_success = res_valid_q && (res_addr_q == mem_addr_i[XLEN-1:3]);

    always_ff @(posedge clk) begin
        if (rst || kill_i) begin
            res_valid_q <= 0;
        end
        else if (valid_i && !exc_ctrl.valid) begin
            if (lsu_ctrl_i.is_lr) begin
                res_valid_q <= 1;
                res_addr_q  <= mem_addr_i[XLEN-1:3];
            end
            else if (lsu_ctrl_i.is_sc) begin
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
    logic [XLEN-1:0] amo_rdata_q;

    logic [XLEN-1:0] amo_src_a;
    logic [XLEN-1:0] amo_src_b;
    logic [XLEN-1:0] cmp_src_a;
    logic [XLEN-1:0] cmp_src_b;
    logic [XLEN-1:0] amo_base_result;
    logic [XLEN-1:0] amo_result;

    assign amo_is_word = lsu_ctrl_i.amo_op[5];
    assign amo_src_a   = amo_rdata_q;
    assign amo_src_b   = mem_wdata_i;
    assign cmp_src_a   = amo_is_word ? {{(XLEN-32){amo_src_a[31]}}, amo_src_a[31:0]} : amo_src_a;
    assign cmp_src_b   = amo_is_word ? {{(XLEN-32){amo_src_b[31]}}, amo_src_b[31:0]} : amo_src_b;

    always_comb begin
        stall_o        = 1'b0;
        next_amo_state = amo_state_q;

        unique case (amo_state_q)
            ST_AMO_IDLE: begin
                if (valid_i && !exc_ctrl.valid && lsu_ctrl_i.is_amo) begin
                    stall_o        = 1'b1;
                    next_amo_state = ST_AMO_MODIFY;
                end
            end
            ST_AMO_MODIFY: begin
                stall_o        = 1'b1;
                next_amo_state = ST_AMO_WRITE;
            end
            ST_AMO_WRITE: begin
                stall_o        = 1'b0;
                next_amo_state = ST_AMO_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst || kill_i) begin
            amo_state_q <= ST_AMO_IDLE;
        end
        else begin
            amo_state_q <= next_amo_state;

            if (amo_state_q == ST_AMO_MODIFY) begin
                amo_rdata_q <= XLEN'(dtcm_rdata_i >> {mem_addr_i[2:0], 3'b000});
            end
        end
    end

    always_comb begin
        unique case (lsu_ctrl_i.amo_op)
            AMO_SWAP, AMO_SWAPW: amo_base_result = amo_src_b;
            AMO_ADD,  AMO_ADDW:  amo_base_result = amo_src_a + amo_src_b;
            AMO_XOR,  AMO_XORW:  amo_base_result = amo_src_a ^ amo_src_b;
            AMO_AND,  AMO_ANDW:  amo_base_result = amo_src_a & amo_src_b;
            AMO_OR,   AMO_ORW:   amo_base_result = amo_src_a | amo_src_b;
            AMO_MIN,  AMO_MINW:  amo_base_result = ($signed(cmp_src_a) < $signed(cmp_src_b)) ? amo_src_a : amo_src_b;
            AMO_MAX,  AMO_MAXW:  amo_base_result = ($signed(cmp_src_a) > $signed(cmp_src_b)) ? amo_src_a : amo_src_b;
            AMO_MINU, AMO_MINUW: amo_base_result = (cmp_src_a < cmp_src_b)                   ? amo_src_a : amo_src_b;
            AMO_MAXU, AMO_MAXUW: amo_base_result = (cmp_src_a > cmp_src_b)                   ? amo_src_a : amo_src_b;
            default:             amo_base_result = amo_src_b;
        endcase

        if (amo_is_word) amo_result = {{(XLEN-32){amo_base_result[31]}}, amo_base_result[31:0]};
        else             amo_result = amo_base_result;
    end

    // ================================================================
    // DTCM Transactions
    // ================================================================

    logic [7:0] base_be;

    always_comb begin
        dtcm_req_o   = 1'b0;
        dtcm_we_o    = 1'b0;
        dtcm_be_o    = '0;
        dtcm_addr_o  = 64'(mem_addr_i);
        dtcm_wdata_o = 64'(mem_wdata_i) << {mem_addr_i[2:0], 3'b000};

        if (valid_i && !exc_ctrl.valid) begin
            if (amo_state_q == ST_AMO_IDLE) begin
                if (lsu_ctrl_i.is_load || lsu_ctrl_i.is_lr) begin
                    dtcm_req_o = 1'b1;
                    dtcm_we_o  = 1'b0;
                end
                else if (lsu_ctrl_i.is_store) begin
                    dtcm_req_o = 1'b1;
                    dtcm_we_o  = 1'b1;
                end
                else if (lsu_ctrl_i.is_sc && sc_success) begin
                    dtcm_req_o = 1'b1;
                    dtcm_we_o  = 1'b1;
                end
                else if (lsu_ctrl_i.is_amo) begin // Initial AMO Read
                    dtcm_req_o = 1'b1;
                    dtcm_we_o  = 1'b0;
                end
            end
            else if (amo_state_q == ST_AMO_WRITE) begin
                dtcm_req_o   = 1'b1;
                dtcm_we_o    = 1'b1;
                dtcm_wdata_o = 64'(amo_result) << {mem_addr_i[2:0], 3'b000};
            end
        end

        unique case (lsu_ctrl_i.size[1:0])
            2'b00: base_be = 8'h01;
            2'b01: base_be = 8'h03;
            2'b10: base_be = 8'h0F;
            2'b11: base_be = 8'hFF;
        endcase
        dtcm_be_o = base_be << mem_addr_i[2:0];
    end

    // ================================================================
    // LSU and Pipeline Outputs
    // ================================================================

    logic            is_load_q;
    logic [2:0]      size_q;
    logic [2:0]      offset_q;
    logic            is_unsigned_q;
    logic            is_amo_q;
    logic            is_sc_q;
    logic            sc_success_q;
    logic [XLEN-1:0] ex_result_q;

    logic [XLEN-1:0] shifted_rdata;
    logic [XLEN-1:0] final_rdata;

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o <= 1'b0;
        end
        else if (!stall_i) begin
            is_load_q     <= lsu_ctrl_i.is_load;
            size_q        <= lsu_ctrl_i.size;
            offset_q      <= mem_addr_i[2:0];
            is_unsigned_q <= lsu_ctrl_i.is_unsigned;
            is_amo_q      <= lsu_ctrl_i.is_amo;
            is_sc_q       <= lsu_ctrl_i.is_sc;
            sc_success_q  <= sc_success;

            valid_o       <= valid_i;
            pc_o          <= pc_i;

            gpr_ctrl_o    <= gpr_ctrl_i;
            csr_ctrl_o    <= csr_ctrl_i;
            exc_ctrl_o    <= exc_ctrl;

            csr_wdata_o   <= csr_wdata_i;
            ex_result_q   <= ex_result_i;
        end
    end

    always_comb begin
        if (is_amo_q) shifted_rdata = XLEN'(amo_rdata_q);
        else          shifted_rdata = XLEN'(dtcm_rdata_i >> {offset_q, 3'b000});

        unique case (size_q[1:0])
            2'b00: final_rdata = is_unsigned_q ? {{(XLEN-8){1'b0}},  shifted_rdata[7:0]}  : {{(XLEN-8){shifted_rdata[7]}},   shifted_rdata[7:0]};
            2'b01: final_rdata = is_unsigned_q ? {{(XLEN-16){1'b0}}, shifted_rdata[15:0]} : {{(XLEN-16){shifted_rdata[15]}}, shifted_rdata[15:0]};
            2'b10: final_rdata = is_unsigned_q ? {{(XLEN-32){1'b0}}, shifted_rdata[31:0]} : {{(XLEN-32){shifted_rdata[31]}}, shifted_rdata[31:0]};
            2'b11: final_rdata = shifted_rdata;
        endcase

        if      (is_load_q || is_amo_q) result_o = final_rdata;
        else if (is_sc_q)               result_o = sc_success_q ? XLEN'(0) : XLEN'(1);
        else                            result_o = ex_result_q;
    end
endmodule
