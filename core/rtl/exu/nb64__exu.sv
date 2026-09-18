module nb64__exu import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            stall_i,
    input  logic            flush_i,
    input  logic            kill_i,   // Kills multi-cycle ops such as mul/div
    output logic            stall_o,  // EXU requesting upstream stall

    input  logic [1:0]      fwd_rs1_sel_i,
    input  logic [1:0]      fwd_rs2_sel_i,
    input  logic [XLEN-1:0] fwd_mem_data_i, // Data from EX/MEM register
    input  logic [XLEN-1:0] fwd_wb_data_i,  // Data from MEM/WB register

    input  logic            valid_i,
    input  trap_ctrl_t      trap_i,
    input  logic [XLEN-1:0] pc_i,

    input  logic [XLEN-1:0] rs1_i,
    input  logic [XLEN-1:0] rs2_i,
    input  logic [XLEN-1:0] imm_i,

    input  logic            is_auipc_i,
    input  logic            op2_is_imm_i,
    input  alu_op_t         alu_op_i,
    input  logic            mext_en_i,
    input  mext_op_t        mext_op_i,

    input  logic            is_branch_i,
    input  logic            is_jump_i,
    input  logic            is_jalr_i,
    input  logic [2:0]      br_type_i,

    input  logic            is_load_i,
    input  logic            is_store_i,
    input  logic            is_lr_i,
    input  logic            is_sc_i,
    input  logic            is_amo_i,
    input  amo_op_t         amo_op_i,
    input  logic [2:0]      size_i,
    input  logic            unsigned_i,

    input  logic            gpr_we_i,
    input  logic [4:0]      gpr_waddr_i,

    input  logic            is_csr_i,
    input  csr_op_t         csr_op_i,
    input  csr_addr_t       csr_addr_i,

    output logic            pc_redirect_o,
    output logic [XLEN-1:0] pc_target_o,

    output logic            is_load_o,
    output logic            is_store_o,
    output logic            is_lr_o,
    output logic            is_sc_o,
    output logic            is_amo_o,
    output amo_op_t         amo_op_o,
    output logic [2:0]      size_o,
    output logic            unsigned_o,
    output logic [XLEN-1:0] addr_o,
    output logic [XLEN-1:0] wdata_o,

    output logic            valid_o,
    output trap_ctrl_t      trap_o,
    output logic [XLEN-1:0] result_o,
    output logic            gpr_we_o,
    output logic [4:0]      gpr_waddr_o,
    output csr_req_t        csr_req_o
);
    // ================================================================
    // ALU
    // ================================================================

    logic [XLEN-1:0] rs1_resolved;
    logic [XLEN-1:0] rs2_resolved;
    logic [XLEN-1:0] src_a;
    logic [XLEN-1:0] src_b;
    logic [XLEN-1:0] alu_result;

    always_comb begin
        unique case (fwd_rs1_sel_i)
            2'b01:   rs1_resolved = fwd_mem_data_i;
            2'b10:   rs1_resolved = fwd_wb_data_i;
            default: rs1_resolved = rs1_i;
        endcase

        unique case (fwd_rs2_sel_i)
            2'b01:   rs2_resolved = fwd_mem_data_i;
            2'b10:   rs2_resolved = fwd_wb_data_i;
            default: rs2_resolved = rs2_i;
        endcase
    end

    assign src_a = rs1_resolved;
    assign src_b = op2_is_imm_i ? imm_i : rs2_resolved;

    nb64__exu_alu #(
        .XLEN (XLEN)
    ) u_alu (
        .alu_op (alu_op_i),
        .src_a  (src_a),
        .src_b  (src_b),
        .result (alu_result)
    );

    // ================================================================
    // MEXT
    // ================================================================

    logic            mext_start;
    logic            mext_ready;
    logic            mext_valid;
    logic [XLEN-1:0] mext_result;

    // A mask with !trap_ctrl.valid is unnecessary, since an instruction
    // cannot be both an arithmetic one and a branch one
    assign mext_start = valid_i && !trap_i.valid && mext_en_i && !kill_i;

    nb64__exu_mext #(
        .XLEN (XLEN)
    ) u_mext (
        .clk     (clk),
        .rst     (rst || kill_i),
        .start   (mext_start),
        .mext_op (mext_op_i),
        .src_a   (rs1_resolved),
        .src_b   (rs2_resolved),
        .ready   (mext_ready),
        .valid   (mext_valid),
        .result  (mext_result)
    );

    // ================================================================
    // Branch Unit
    // ================================================================

    logic            bu_redirect;
    logic [XLEN-1:0] bu_target;
    logic            bu_misaligned;

    nb64__exu_bu #(
        .XLEN (XLEN)
    ) u_bu (
        .br_type           (br_type_i),
        .is_branch         (is_branch_i),
        .is_jump           (is_jump_i),
        .is_jalr           (is_jalr_i),
        .rs1               (rs1_resolved),
        .rs2               (rs2_resolved),
        .imm               (imm_i),
        .pc                (pc_i),
        .pc_redirect       (bu_redirect),
        .pc_target         (bu_target),
        .target_misaligned (bu_misaligned)
    );

    // ================================================================
    // Exception Detection
    // ================================================================

    trap_ctrl_t trap_ctrl;

    always_comb begin
        trap_ctrl = trap_i;

        if (valid_i && !trap_i.valid) begin
            if (bu_misaligned) begin
                trap_ctrl.valid = 1;
                trap_ctrl.cause = EXC_INSTR_ADDR_MISALIGNED;
                trap_ctrl.tval  = bu_target;
            end
        end
    end

    // ================================================================
    // EXU and Pipeline Outputs
    // ================================================================

    assign stall_o       = valid_i && !trap_i.valid && mext_en_i && !mext_valid;
    assign pc_redirect_o = valid_i && !trap_ctrl.valid && !flush_i && bu_redirect;
    assign pc_target_o   = bu_target;

    // Strictly speaking, it is only necessary to clear mem_valid_o if the pipeline
    // properly checks the valid and trap.valid bits
    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o         <= 0;
            trap_o.valid    <= 0;
            gpr_we_o        <= 0;
            csr_req_o.valid <= 0;
        end
        else if (!stall_i) begin
            is_load_o   <= is_load_i;
            is_store_o  <= is_store_i;
            is_lr_o     <= is_lr_i;
            is_sc_o     <= is_sc_i;
            is_amo_o    <= is_amo_i;
            amo_op_o    <= amo_op_i;
            size_o      <= size_i;
            unsigned_o  <= unsigned_i;
            addr_o      <= rs1_resolved + imm_i;
            wdata_o     <= rs2_resolved;

            valid_o     <= valid_i;
            trap_o      <= trap_ctrl;
            gpr_we_o    <= gpr_we_i;
            gpr_waddr_o <= gpr_waddr_i;
            csr_req_o   <= 0; // Placeholder ??

            if      (is_auipc_i) result_o <= pc_i + imm_i;
            else if (mext_en_i)  result_o <= mext_result;
            else if (is_jump_i)  result_o <= pc_i + 4;
            else                 result_o <= alu_result;
        end
    end
endmodule
