module nb64__core #(
    parameter int XLEN = 64,
    parameter logic [63:0] RESET_VECTOR = 0
)(
    input  logic clk,
    input  logic rst,

    output logic cs_n,
    output logic sclk,
    output logic mosi,
    input  logic miso // Should be in SoC technically ??
);
    // ================================================================
    // General Purpose Registers
    // ================================================================

    nb64__rf_gpr #(
        .XLEN (XLEN)
    ) u_gpr (
        .clk    (clk),
        .raddr1 (),
        .raddr2 (),
        .rdata1 (),
        .rdata2 (),
        .we     (),
        .waddr  (),
        .wdata  ()
    );

    // ================================================================
    // Control and Status Registers
    // ================================================================

    nb64__rf_csr #(
        .XLEN (XLEN)
    ) u_csr (
        .clk          (clk),
        .rst          (),
        .raddr_i      (),
        .rdata_o      (),
        .we_i         (),
        .waddr_i      (),
        .wdata_i      (),
        .csr_op_i     (),
        .trap_valid_i (),
        .trap_cause_i (),
        .trap_tval_i  (),
        .trap_pc_i    ()
    );

    // ================================================================
    // Boot Manager and XIP Controller
    // ================================================================

    logic        xip_start;
    logic [23:0] xip_raddr;
    logic [31:0] xip_rdata;
    logic        xip_ready;
    logic        xip_valid;
    logic        boot_done;
    logic        core_rst;

    logic        boot_itcm_req;
    logic        boot_itcm_we;
    logic [63:0] boot_itcm_addr;
    logic [31:0] boot_itcm_wdata;

    logic        boot_dtcm_req;
    logic        boot_dtcm_we;
    logic [7:0]  boot_dtcm_be;
    logic [63:0] boot_dtcm_addr;
    logic [63:0] boot_dtcm_wdata;

    assign core_rst = rst | ~boot_done;

    nb64__sys_bootmgr u_bootmgr (
        .clk        (clk),
        .rst        (rst),
        .xip_start  (xip_start),
        .xip_raddr  (xip_raddr),
        .xip_rdata  (xip_rdata),
        .xip_ready  (xip_ready),
        .xip_valid  (xip_valid),
        .boot_done  (boot_done),
        .itcm_req   (boot_itcm_req),
        .itcm_we    (boot_itcm_we),
        .itcm_addr  (boot_itcm_addr),
        .itcm_wdata (boot_itcm_wdata),
        .dtcm_req   (boot_dtcm_req),
        .dtcm_we    (boot_dtcm_we),
        .dtcm_be    (boot_dtcm_be),
        .dtcm_addr  (boot_dtcm_addr),
        .dtcm_wdata (boot_dtcm_wdata)
    );

    nb64__sys_xip u_xip (
        .clk   (clk),
        .rst   (rst),
        .start (xip_start),
        .raddr (xip_raddr),
        .rdata (xip_rdata),
        .ready (xip_ready),
        .valid (xip_valid),
        .cs_n  (cs_n),
        .sclk  (sclk),
        .mosi  (mosi),
        .miso  (miso)
    );

    // ================================================================
    // Instruction TCM
    // ================================================================

    logic        itcm_req;
    logic        itcm_we;
    logic [63:0] itcm_addr;
    logic [31:0] itcm_wdata;
    logic [31:0] itcm_rdata;

    assign itcm_req   = boot_done ? core_itcm_req  : boot_itcm_req;
    assign itcm_we    = boot_done ? 0              : boot_itcm_we;
    assign itcm_addr  = boot_done ? core_itcm_addr : boot_itcm_addr;
    assign itcm_wdata = boot_done ? 0              : boot_itcm_wdata;

    nb64__mem_itcm u_itcm (
        .clk   (clk),
        .req   (itcm_req),
        .we    (itcm_we),
        .addr  (itcm_addr),
        .wdata (itcm_wdata),
        .rdata (itcm_rdata)
    );

    // ================================================================
    // Data TCM
    // ================================================================

    logic        dtcm_req;
    logic        dtcm_we;
    logic [7:0]  dtcm_be;
    logic [63:0] dtcm_addr; // technically only 12 ??
    logic [63:0] dtcm_wdata;
    logic [63:0] dtcm_rdata;

    assign dtcm_req   = boot_done ? core_dtcm_req   : boot_dtcm_req;
    assign dtcm_we    = boot_done ? core_dtcm_we    : boot_dtcm_we;
    assign dtcm_be    = boot_done ? core_dtcm_be    : boot_dtcm_be;
    assign dtcm_addr  = boot_done ? core_dtcm_addr  : boot_dtcm_addr;
    assign dtcm_wdata = boot_done ? core_dtcm_wdata : boot_dtcm_wdata;

    nb64__mem_dtcm u_dtcm (
        .clk   (clk),
        .req   (dtcm_req),
        .we    (dtcm_we),
        .be    (dtcm_be),
        .addr  (dtcm_addr),
        .wdata (dtcm_wdata),
        .rdata (dtcm_rdata)
    );

    // ================================================================
    // Forwarding Unit
    // ================================================================

    nb64__ctrl_fwd u_fwd (
        .ex_rs1_re_i     (), // driven by id/ex regs technically ??
        .ex_rs2_re_i     (),
        .ex_rs1_addr_i   (),
        .ex_rs2_addr_i   (),
        .mem_valid_i     (),
        .mem_gpr_we_i    (),
        .mem_gpr_waddr_i (),
        .wb_valid_i      (),
        .wb_gpr_we_i     (),
        .wb_gpr_waddr_i  (),
        .fwd_rs1_sel_o   (),
        .fwd_rs2_sel_o   ()
    );

    // ================================================================
    // Hazard Unit
    // ================================================================

    nb64__ctrl_hzd u_hzd (
        .id_valid_i       (),
        .id_rs1_re_i      (),
        .id_rs2_re_i      (),
        .id_rs1_addr_i    (),
        .id_rs2_addr_i    (),
        .ex_valid_i       (),
        .ex_ready_i       (),
        .ex_is_load_i     (),
        .ex_pc_redirect_i (),
        .ex_gpr_waddr_i   (),
        .lsu_stall_i      (),
        .trap_flush_i     (),
        .if_stall_o       (),
        .if_flush_o       (),   
        .id_stall_o       (),
        .id_flush_o       (),
        .ex_stall_o       (),
        .ex_flush_o       (),
        .mem_stall_o      (),
        .mem_flush_o      ()
    );

    // ================================================================
    // Instruction Fetch Unit
    // ================================================================

    logic        core_itcm_req;
    logic [63:0] core_itcm_addr;

    nb64__ifu #(
        .XLEN         (XLEN),
        .RESET_VECTOR (RESET_VECTOR) 
    ) u_ifu ( // technically for idu / decode ??
        .clk            (clk),
        .rst            (),
        .id_stall_i     (),
        .id_flush_i     (),
        .if_valid_i     (),
        .if_trap_i      (),
        .instr_i        (),
        .pc_i           (),
        .rs1_addr_o     (),
        .rs2_addr_o     (),
        .rs1_data_i     (),
        .rs2_data_i     (),
        .rs1_re_o       (),
        .rs2_re_o       (),
        .id_valid_o     (),
        .pc_o           (),
        .imm_o          (),
        .op1_is_pc_o    (),
        .op2_is_imm_o   (),
        .alu_op_o       (),
        .mext_en_o      (),
        .mext_op_o      (),
        .is_load_o      (),
        .is_store_o     (),
        .is_jump_o      (),
        .is_jalr_o      (),
        .is_branch_o    (),
        .br_type_o      (),
        .mem_size_o     (),
        .mem_unsigned_o (),
        .is_lr_o        (),
        .is_sc_o        (),
        .is_amo_o       (),
        .amo_op_o       (),
        .gpr_we_o       (),
        .gpr_waddr_o    (),
        .is_csr_o       (),
        .csr_op_o       (),
        .trap_o         ()
    );

    // ================================================================
    // Execution Unit
    // ================================================================

    nb64__exu #(
        .XLEN (XLEN)
    ) u_exu (
        .clk             (),
        .rst             (),
        .ex_stall_i      (),
        .ex_flush_i      (),
        .ex_kill_i       (),
        .exu_stall_o     (),
        .fwd_rs1_sel_i   (),
        .fwd_rs2_sel_i   (),
        .fwd_mem_data_i  (),
        .fwd_wb_data_i   (),
        .id_valid_i      (),
        .id_trap_i       (),
        .pc_i            (),
        .rs1_i           (),
        .rs2_i           (),
        .imm_i           (),
        .is_auipc_i      (),
        .op2_is_imm_i    (),
        .alu_op_i        (),
        .mext_en_i       (),
        .mext_op_i       (),
        .is_branch_i     (),
        .is_jump_i       (),
        .is_jalr_i       (),
        .br_type_i       (),
        .is_load_i       (),
        .is_store_i      (),
        .is_amo_i        (),
        .amo_op_i        (),
        .mem_size_i      (),
        .mem_unsigned_i  (),
        .gpr_we_i        (),
        .gpr_waddr_i     (),
        .is_csr_i        (),
        .csr_op_i        (),
        .csr_addr_i      (),
        .pc_redirect_o   (),
        .pc_target_o     (),
        .mem_is_load_o   (),
        .mem_is_store_o  (),
        .mem_is_amo_o    (),
        .mem_amo_op_o    (),
        .mem_size_o      (),
        .mem_unsigned_o  (),
        .mem_addr_o      (),
        .mem_wdata_o     (),
        .mem_valid_o     (),
        .mem_trap_o      (),
        .mem_result_o    (),
        .mem_gpr_we_o    (),
        .mem_gpr_waddr_o (),
        .mem_csr_req_o   ()
    );

    // ================================================================
    // Load-Store Unit
    // ================================================================

    logic        core_dtcm_req;
    logic        core_dtcm_we;
    logic [7:0]  core_dtcm_be;
    logic [63:0] core_dtcm_addr;
    logic [63:0] core_dtcm_wdata;

    nb64__lsu #(
        .XLEN (XLEN)
    ) u_lsu (
        .clk             (clk),
        .rst             (),
        .mem_stall_i     (),
        .mem_flush_i     (),
        .mem_kill_i      (),
        .lsu_stall_o     (),
        .ex_valid_i      (),
        .ex_trap_i       (),
        .ex_is_load_i    (),
        .ex_is_store_i   (),
        .ex_is_lr_i      (),
        .ex_is_sc_i      (),
        .ex_is_amo_i     (),
        .ex_amo_op_i     (),
        .ex_size_i       (),
        .ex_unsigned_i   (),
        .ex_addr_i       (),
        .ex_wdata_i      (),
        .ex_gpr_waddr_i  (),
        .ex_gpr_we_i     (),
        .dtcm_req_o      (core_dtcm_req),
        .dtcm_we_o       (core_dtcm_we),
        .dtcm_be_o       (core_dtcm_be),
        .dtcm_addr_o     (core_dtcm_addr),
        .dtcm_wdata_o    (core_dtcm_wdata),
        .dtcm_rdata_i    (),
        .mem_valid_o     (),
        .mem_result_o    (),
        .mem_gpr_waddr_o (),
        .mem_gpr_we_o    (),
        .mem_trap_o      ()
    );
endmodule
