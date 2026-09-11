module nb64__exu import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            ex_valid_i,
    input  logic            ex_stall_i,
    input  logic            ex_flush_i,
    output logic            ex_ready_o,

    input  logic [1:0]      fwd_rs1_sel_i,
    input  logic [1:0]      fwd_rs2_sel_i,
    input  logic [XLEN-1:0] mem_fwd_data_i,
    input  logic [XLEN-1:0] wb_fwd_data_i,

    input  logic [XLEN-1:0] rs1_i,
    input  logic [XLEN-1:0] rs2_i,
    input  logic [XLEN-1:0] imm_i,
    input  logic [XLEN-1:0] pc_i,

    input  logic            op1_is_pc_i,
    input  logic            op2_is_imm_i,
    input  alu_op_t         alu_op_i,
    input  logic            mext_en_i,
    input  mext_op_t        mext_op_i,
    input  logic [2:0]      br_type_i,
    input  logic            is_branch_i,
    input  logic            is_jump_i,
    input  logic            is_jalr_i,
    input  logic            is_load_i,
    input  logic            is_store_i,
    input  logic [2:0]      mem_size_i,
    input  logic            mem_unsigned_i,
    input  logic [4:0]      gpr_waddr_i,
    input  logic            gpr_we_i,

    output logic            pc_redirect_o,
    output logic [XLEN-1:0] pc_target_o,

    output logic            mem_valid_o,
    output logic [XLEN-1:0] mem_lsu_addr_o,
    output logic [XLEN-1:0] mem_lsu_wdata_o,
    output logic            mem_lsu_load_o,
    output logic            mem_lsu_store_o,
    output logic [2:0]      mem_lsu_size_o,
    output logic            mem_lsu_unsigned_o,
    output logic [XLEN-1:0] mem_ex_result_o,
    output logic [4:0]      mem_gpr_waddr_o,
    output logic            mem_gpr_we_o
);
    logic [XLEN-1:0] rs1_resolved;
    logic [XLEN-1:0] rs2_resolved;
    logic [XLEN-1:0] src_a;
    logic [XLEN-1:0] src_b;
    logic [XLEN-1:0] alu_result;

    always_comb begin
        unique case (fwd_rs1_sel_i)
            2'b01:   rs1_resolved = mem_fwd_data_i;
            2'b10:   rs1_resolved = wb_fwd_data_i;
            default: rs1_resolved = rs1_i;
        endcase

        unique case (fwd_rs2_sel_i)
            2'b01:   rs2_resolved = mem_fwd_data_i;
            2'b10:   rs2_resolved = wb_fwd_data_i;
            default: rs2_resolved = rs2_i;
        endcase
    end

    assign src_a = op1_is_pc_i  ? pc_i  : rs1_resolved;
    assign src_b = op2_is_imm_i ? imm_i : rs2_resolved;

    nb64__exu_alu #(
        .XLEN (XLEN)
    ) u_alu (
        .alu_op (alu_op_i),
        .src_a  (src_a),
        .src_b  (src_b),
        .result (alu_result)
    );

    logic            mext_start;
    logic            mext_ready;
    logic            mext_valid;
    logic [XLEN-1:0] mext_result;

    assign mext_start = mext_en_i && ex_valid_i && !(ex_stall_i || ex_flush_i);

    nb64__exu_mext #(
        .XLEN (XLEN)
    ) u_mext (
        .clk     (clk),
        .rst     (rst),
        .start   (mext_start),
        .mext_op (mext_op_i),
        .src_a   (rs1_resolved),
        .src_b   (rs2_resolved),
        .ready   (mext_ready),
        .valid   (mext_valid),
        .result  (mext_result)
    );

    logic            bu_redirect;
    logic [XLEN-1:0] bu_target;

    nb64__exu_bu #(
        .XLEN (XLEN)
    ) u_bu (
        .br_type     (br_type_i),
        .is_branch   (is_branch_i),
        .is_jump     (is_jump_i),
        .is_jalr     (is_jalr_i),
        .rs1         (rs1_resolved),
        .rs2         (rs2_resolved),
        .imm         (imm_i),
        .pc          (pc_i),
        .pc_redirect (bu_redirect),
        .pc_target   (bu_target)
    );

    assign ex_ready_o    = ex_valid_i && mext_en_i ? mext_valid : 1;
    assign pc_redirect_o = ex_valid_i && !ex_flush_i && bu_redirect;
    assign pc_target_o   = bu_target;

    always_ff @(posedge clk) begin
        if (rst || ex_flush_i) begin
            mem_valid_o     <= 0;
            mem_lsu_load_o  <= 0;
            mem_lsu_store_o <= 0;
            mem_gpr_we_o    <= 0;
        end
        else if (ex_ready_o && !ex_stall_i) begin
            mem_valid_o        <= ex_valid_i;
            mem_lsu_addr_o     <= rs1_resolved + imm_i; // imm_i = 0 on AMOs
            mem_lsu_wdata_o    <= rs2_resolved;
            mem_lsu_load_o     <= is_load_i && ex_valid_i;
            mem_lsu_store_o    <= is_store_i && ex_valid_i;
            mem_lsu_size_o     <= mem_size_i;
            mem_lsu_unsigned_o <= mem_unsigned_i;
            mem_gpr_waddr_o    <= gpr_waddr_i;
            mem_gpr_we_o       <= gpr_we_i && ex_valid_i;

            if (mext_en_i) begin
                mem_ex_result_o <= mext_result;
            end
            else if (is_jump_i || is_jalr_i) begin
                mem_ex_result_o <= pc_i + 4;
            end
            else begin
                mem_ex_result_o <= alu_result;
            end
        end
    end
endmodule
