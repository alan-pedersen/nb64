module nb64__exu_div #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,

    input  logic            start,
    input  logic            sign_mode,
    input  logic [XLEN-1:0] op_a,
    input  logic [XLEN-1:0] op_b,
    output logic            ready,
    output logic            valid,
    output logic [XLEN-1:0] result
);
endmodule
