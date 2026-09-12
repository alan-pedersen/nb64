module nb64__ctrl_fwd (
    input  logic       ex_rs1_re_i,
    input  logic       ex_rs2_re_i,
    input  logic [4:0] ex_rs1_addr_i,
    input  logic [4:0] ex_rs2_addr_i,

    input  logic       mem_valid_i,
    input  logic       mem_gpr_we_i,
    input  logic [4:0] mem_gpr_waddr_i,

    input  logic       wb_valid_i,
    input  logic       wb_gpr_we_i,
    input  logic [4:0] wb_gpr_waddr_i,

    output logic [1:0] fwd_rs1_sel_o,
    output logic [1:0] fwd_rs2_sel_o
);
    function automatic logic [1:0] fwd_sel (
        input logic       rs_re,
        input logic [4:0] rs_addr
    );
        fwd_sel = 2'b00;

        if (rs_re && (rs_addr != 0)) begin
            if (mem_valid_i && mem_gpr_we_i && (mem_gpr_waddr_i == rs_addr)) begin
                fwd_sel = 2'b01;
            end
            else if (wb_valid_i && wb_gpr_we_i && (wb_gpr_waddr_i == rs_addr)) begin
                fwd_sel = 2'b10;
            end
        end
    endfunction

    assign fwd_rs1_sel_o = fwd_sel(ex_rs1_re_i, ex_rs1_addr_i);
    assign fwd_rs2_sel_o = fwd_sel(ex_rs2_re_i, ex_rs2_addr_i);
endmodule
