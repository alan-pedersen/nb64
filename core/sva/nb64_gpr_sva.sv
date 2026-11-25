module nb64_gpr_sva import nb64_pkg::*; (
    input logic            clk_i,

    input logic [4:0]      rs1_addr_i,
    input logic [4:0]      rs2_addr_i,
    input logic [XLEN-1:0] rs1_data_o,
    input logic [XLEN-1:0] rs2_data_o,

    input logic            rd_we_i,
    input logic [4:0]      rd_addr_i,
    input logic [XLEN-1:0] rd_data_i,

    input logic [XLEN-1:0] regs [1:31]
);
    default clocking cb @(posedge clk_i);
    endclocking

    // ================================================================
    // Read properties
    // ================================================================

    property p_read_x0(logic [4:0] raddr, logic [XLEN-1:0] rdata);
        (raddr == 0) |-> (rdata == 0);
    endproperty
    a_rs1_x0: assert property (p_read_x0(rs1_addr_i, rs1_data_o));
    a_rs2_x0: assert property (p_read_x0(rs2_addr_i, rs2_data_o));

    property p_read_fwd(logic [4:0] raddr, logic [XLEN-1:0] rdata);
        (rd_we_i && (rd_addr_i == raddr) && (raddr != 0)) |-> (rdata == rd_data_i);
    endproperty
    a_rs1_rd: assert property (p_read_fwd(rs1_addr_i, rs1_data_o));
    a_rs2_rd: assert property (p_read_fwd(rs2_addr_i, rs2_data_o));

    property p_read_reg(logic [4:0] raddr, logic [XLEN-1:0] rdata);
        ((raddr != 0) && !(rd_we_i && (rd_addr_i == raddr))) |-> (rdata == regs[raddr]);
    endproperty
    a_rs1_reg: assert property (p_read_reg(rs1_addr_i, rs1_data_o));
    a_rs2_reg: assert property (p_read_reg(rs2_addr_i, rs2_data_o));

    // ================================================================
    // Write properties and register stability
    // ================================================================

    property p_reg_stable(logic [4:0] idx);
        (!rd_we_i || (rd_addr_i != idx)) |=> $stable(regs[idx]);
    endproperty

    property p_reg_write(logic [4:0] idx);
        (rd_we_i && (rd_addr_i == idx)) |=> (regs[idx] == $past(rd_data_i));
    endproperty

    generate
        for (genvar i = 1; i < 32; i++) begin : gen_reg
            a_reg_stable: assert property (p_reg_stable(5'(i)));
            a_write_reg:  assert property (p_reg_write(5'(i)));
        end
    endgenerate
endmodule
