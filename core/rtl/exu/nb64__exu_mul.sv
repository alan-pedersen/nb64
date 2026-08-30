module nb64__exu_mul #(
    parameter int XLEN = 64
)(
    input  logic              clk,
    input  logic              rst,
    
    input  logic              start,
    input  logic [1:0]        sign_mode,
    input  logic [XLEN-1:0]   op_a,
    input  logic [XLEN-1:0]   op_b,
    output logic              ready,
    output logic              valid,
    output logic [2*XLEN-1:0] result
);
    function automatic void csa (
        input  logic [2*XLEN-1:0] a,
        input  logic [2*XLEN-1:0] b,
        input  logic [2*XLEN-1:0] c,
        output logic [2*XLEN-1:0] sum,
        output logic [2*XLEN-1:0] cout,
    );
        sum  = a ^ b ^ c;
        cout = ((a & b) | (b & c) | (a & c)) << 1;
    endfunction

    function automatic logic [2*XLEN-1:0] booth (
        input  logic [2*XLEN-1:0] a,
        input  logic [2:0]        bits
    );
        unique case (bits)
            3'b000, 3'b111: booth = 0;
            3'b001, 3'b010: booth = +a;
            3'b011:         booth = +(a << 1);
            3'b100:         booth = -(a << 1);
            3'b101, 3'b110: booth = -a;
        endcase
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            
        end
        else begin
            
        end
    end
endmodule
