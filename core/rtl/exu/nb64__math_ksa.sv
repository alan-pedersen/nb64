module nb64__math_ksa #(
    parameter int WIDTH = 128
)(
    input  logic [WIDTH-1:0] a, // src vs op ??
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    localparam int STAGES = $clog2(WIDTH);

    logic [WIDTH-1:0] g [STAGES+1];
    logic [WIDTH-1:0] p [STAGES+1];
    logic [WIDTH:0]   c;

    assign g[0] = a & b;
    assign p[0] = a ^ b;
    assign c[0] = cin;

    generate
        for (genvar stage = 1; stage <= STAGES; stage = stage + 1) begin : prefix_stages
            localparam int STEP = 1 << (stage - 1);

            for (genvar bit_idx = 0; bit_idx < WIDTH; bit_idx = bit_idx + 1) begin : bit_nodes
                if (bit_idx < STEP) begin
                    assign g[stage][bit_idx] = g[stage-1][bit_idx];
                    assign p[stage][bit_idx] = p[stage-1][bit_idx];
                end
                else begin
                    assign g[stage][bit_idx] = g[stage-1][bit_idx] | (p[stage-1][bit_idx] & g[stage-1][bit_idx-STEP]);
                    assign p[stage][bit_idx] = p[stage-1][bit_idx] & p[stage-1][bit_idx-STEP];
                end
            end
        end
    endgenerate

    generate
        for (genvar i = 0; i < WIDTH; i = i + 1) begin
            assign c[i+1] = g[STAGES][i] | (p[STAGES][i] & cin);
            assign sum[i] = p[0][i] ^ c[i];
        end
    endgenerate

    assign cout = c[WIDTH];
endmodule
