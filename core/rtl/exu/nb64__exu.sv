module nb64__exu import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            ex_valid_i, // Include stall signal ??
    input  logic            ex_flush_i,
    output logic            ex_ready_o,

    input  logic [XLEN-1:0] rs1_i,
    input  logic [XLEN-1:0] rs2_i,
    input  logic [XLEN-1:0] imm_i,
    input  logic [XLEN-1:0] pc_i,

    input  alu_op_t         alu_op_i,
    input  logic            alu_en_i,

    input  logic            mext_en_i,
    input  mext_op_t        mext_op_i,
    input  logic            mext_is_word_i, // Combine into mext_op_t ??

    input  logic [2:0]      br_type_i,
    input  logic            is_branch_i,
    input  logic            is_jump_i,
    input  logic            is_jalr_i,

    input  logic            is_load_i,
    input  logic            is_store_i,
    input  logic [2:0]      mem_size_i,
    input  logic            mem_unsigned_i,
    input  logic [4:0]      rd_addr_i,
    input  logic            wb_en_i, // Prefix with 'rf' or 'gpr' ??

    output logic            pc_redirect_o,
    output logic [XLEN-1:0] pc_target_o,

    output logic [XLEN-1:0] lsu_addr_o,
    output logic [XLEN-1:0] lsu_wdata_o,
    output logic            lsu_load_o,
    output logic            lsu_store_o,
    output logic [2:0]      lsu_size_o,
    output logic            lsu_unsigned_o,

    output logic [XLEN-1:0] ex_result_o,
    output logic [4:0]      ex_rd_addr_o,
    output logic            ex_wb_en_o // Prefix with 'rf' or 'gpr' ??
);
    nb64__exu_alu #(
        .XLEN (XLEN)
    ) u_alu (
        .alu_op (),
        .src_a  (),
        .src_b  (),
        .result ()
    );

    nb64__exu_mext #( // op_x vs src_x ??
        .XLEN (XLEN)
    ) u_mext (
        .clk     (),
        .rst     (),
        .start   (),
        .mext_op (),
        .op_a    (),
        .op_b    (),
        .ready   (),
        .valid   (),
        .result  ()
    );

    nb64__exu_bu #(
        .XLEN (XLEN)
    ) u_bu (
        .br_type     (),
        .is_branch   (),
        .is_jump     (),
        .is_jalr     (),
        .rs1         (),
        .rs2         (),
        .pc          (),
        .imm         (),
        .pc_redirect (),
        .pc_target   ()
    );
endmodule
// Assumed that nb64__ctrl_forward inputs the correct rs1 and rs2 values
// Wire or register ALU output to lsu_addr ??
// How to handle LOAD and STORE forwarding / hazards ??
