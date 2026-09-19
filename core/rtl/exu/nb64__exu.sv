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
    input  logic [XLEN-1:0] pc_i,

    input  exu_ctrl_t       exu_ctrl_i,
    input  lsu_ctrl_t       lsu_ctrl_i,
    input  gpr_ctrl_t       gpr_ctrl_i,
    input  csr_ctrl_t       csr_ctrl_i,
    input  exc_ctrl_t       exc_ctrl_i,

    input  logic [XLEN-1:0] rs1_i,
    input  logic [XLEN-1:0] rs2_i,
    input  logic [XLEN-1:0] imm_i,

    output logic            pc_redirect_o,
    output logic [XLEN-1:0] pc_target_o,

    output logic            valid_o,
    output logic [XLEN-1:0] pc_o,
    
    output lsu_ctrl_t       lsu_ctrl_o,
    output gpr_ctrl_t       gpr_ctrl_o,
    output csr_ctrl_t       csr_ctrl_o,
    output exc_ctrl_t       exc_ctrl_o,

    output logic [XLEN-1:0] result_o,
    output logic [XLEN-1:0] mem_addr_o,
    output logic [XLEN-1:0] mem_wdata_o,
    output logic [XLEN-1:0] csr_wdata_o
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
    assign src_b = exu_ctrl_i.op2_is_imm ? imm_i : rs2_resolved;

    nb64__exu_alu #(
        .XLEN (XLEN)
    ) u_alu (
        .alu_op (exu_ctrl_i.alu_op),
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

    // A mask with !exc_ctrl.valid is unnecessary, since an instruction
    // cannot be both an arithmetic one and a branch one
    assign mext_start = valid_i && !exc_ctrl_i.valid && exu_ctrl_i.mext_en && !kill_i;

    nb64__exu_mext #(
        .XLEN (XLEN)
    ) u_mext (
        .clk     (clk),
        .rst     (rst || kill_i),
        .start   (mext_start),
        .mext_op (exu_ctrl_i.mext_op),
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
        .br_type           (exu_ctrl_i.br_type),
        .is_branch         (exu_ctrl_i.is_branch),
        .is_jump           (exu_ctrl_i.is_jump),
        .is_jalr           (exu_ctrl_i.is_jalr),
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

    exc_ctrl_t exc_ctrl;

    always_comb begin
        exc_ctrl = exc_ctrl_i;

        if (valid_i && !exc_ctrl_i.valid) begin
            if (bu_misaligned) begin
                exc_ctrl.valid = 1;
                exc_ctrl.cause = EXC_INSTR_ADDR_MISALIGNED;
                exc_ctrl.tval  = bu_target;
            end
        end
    end

    // ================================================================
    // EXU and Pipeline Outputs
    // ================================================================

    assign stall_o       = valid_i && !exc_ctrl_i.valid && exu_ctrl_i.mext_en && !mext_valid;
    assign pc_redirect_o = valid_i && !exc_ctrl.valid && !flush_i && bu_redirect;
    assign pc_target_o   = bu_target;

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o <= 1'b0;
        end
        else if (!stall_i) begin
            valid_o     <= valid_i;
            pc_o        <= pc_i;

            lsu_ctrl_o  <= lsu_ctrl_i;
            gpr_ctrl_o  <= gpr_ctrl_i;
            csr_ctrl_o  <= csr_ctrl_i;
            exc_ctrl_o  <= exc_ctrl;

            mem_addr_o  <= rs1_resolved + imm_i;
            mem_wdata_o <= rs2_resolved;
            csr_wdata_o <= rs1_resolved; // ?? Placeholder

            if      (exu_ctrl_i.is_auipc) result_o <= pc_i + imm_i;
            else if (exu_ctrl_i.mext_en)  result_o <= mext_result;
            else if (exu_ctrl_i.is_jump)  result_o <= pc_i + XLEN'(4);
            else                          result_o <= alu_result;
        end
    end
endmodule
