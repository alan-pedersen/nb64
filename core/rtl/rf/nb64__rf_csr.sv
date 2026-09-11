module nb64__rf_csr #(
    parameter int XLEN = 64
)(
    input logic clk,
    input logic rst
);
    // ================================================================
    // RV64 and RV32 Registers
    // ================================================================

    logic [31:0]     mvendorid;
    logic [XLEN-1:0] marchid;
    logic [XLEN-1:0] mimpid;
    logic [XLEN-1:0] mhartid;
    logic [XLEN-1:0] mconfigptr;
    logic [XLEN-1:0] mstatus;
    logic [XLEN-1:0] misa;
    logic [63:0]     medeleg;
    logic [XLEN-1:0] mideleg;
    logic [XLEN-1:0] mie;
    logic [XLEN-1:0] mtvec;
    logic [31:0]     mcounteren;
    logic [XLEN-1:0] mscratch;
    logic [XLEN-1:0] mepc;
    logic [XLEN-1:0] mcause;
    logic [XLEN-1:0] mtval;
    logic [XLEN-1:0] mip;
    logic [XLEN-1:0] mtinst;
    logic [XLEN-1:0] mtval2;
    logic [XLEN-1:0] miselect;
    logic [XLEN-1:0] mireg;
    logic [XLEN-1:0] mireg2;
    logic [XLEN-1:0] mireg3;
    logic [XLEN-1:0] mireg4;
    logic [XLEN-1:0] mireg5;
    logic [XLEN-1:0] mireg6;
    logic [63:0]     menvcfg;
    logic [63:0]     mseccfg;
    logic [63:0]     mstateen0;
    logic [63:0]     mstateen1;
    logic [63:0]     mstateen2;
    logic [63:0]     mstateen3;
    logic [XLEN-1:0] mnscratch;
    logic [XLEN-1:0] mnepc;
    logic [XLEN-1:0] mncause;
    logic [XLEN-1:0] mnstatus;
    logic [63:0]     mcycle;
    logic [63:0]     minstret;
    logic [31:0]     mcountinhibit;
    logic [63:0]     mcyclecfg;
    logic [63:0]     minstretcfg;
    logic [31:0]     mcyclecfgh;
    logic [31:0]     minstretcfgh;
    logic [63:0]     mctrctl;
endmodule
