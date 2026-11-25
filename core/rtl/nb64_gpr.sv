module nb64_gpr import nb64_pkg::*; (
    input  logic            clk_i,

    input  logic [4:0]      rs1_addr_i,
    input  logic [4:0]      rs2_addr_i,
    output logic [XLEN-1:0] rs1_data_o,
    output logic [XLEN-1:0] rs2_data_o,

    input  logic            rd_we_i,
    input  logic [4:0]      rd_addr_i,
    input  logic [XLEN-1:0] rd_data_i
);
    logic [XLEN-1:0] regs [1:31];

    logic fwd_rs1;
    logic fwd_rs2;

    assign fwd_rs1 = rd_we_i && (rd_addr_i == rs1_addr_i);
    assign fwd_rs2 = rd_we_i && (rd_addr_i == rs2_addr_i);

    always_comb begin
        if      (rs1_addr_i == 0) rs1_data_o = 0;
        else if (fwd_rs1)         rs1_data_o = rd_data_i;
        else                      rs1_data_o = regs[rs1_addr_i];

        if      (rs2_addr_i == 0) rs2_data_o = 0;
        else if (fwd_rs2)         rs2_data_o = rd_data_i;
        else                      rs2_data_o = regs[rs2_addr_i];
    end

    always_ff @(posedge clk_i) begin
        if (rd_we_i && (rd_addr_i != 0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end
endmodule
