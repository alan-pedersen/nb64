module nb64__exu_mext import nb64_pkg::*; #(
    parameter int XLEN = 64
)(
    input logic             clk,
    input logic             rst,

    input  logic            start,
    input  mext_op_t        mext_op,
    input  logic [XLEN-1:0] op_a,
    input  logic [XLEN-1:0] op_b,
    output logic            ready,
    output logic            valid,
    output logic [XLEN-1:0] result
);
    nb64__exu_mul #(
        .XLEN (XLEN)
    ) u_mul (
        .clk       (),
        .rst       (),
        .start     (),
        .sign_mode (),
        .op_a      (),
        .op_b      (),
        .ready     (),
        .valid     (),
        .result    ()
    );

    nb64__exu_div #(
        .XLEN (XLEN)
    ) u_div (
        .clk       (),
        .rst       (),
        .start     (),
        .sign_mode (),
        .op_a      (),
        .op_b      (),
        .ready     (),
        .valid     (),
        .result    ()
    )
endmodule
