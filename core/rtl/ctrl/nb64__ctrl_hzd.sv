module nb64__ctrl_hzd (
    input  logic       id_valid_i,
    input  logic       id_rs1_re_i,
    input  logic       id_rs2_re_i,
    input  logic [4:0] id_rs1_addr_i,
    input  logic [4:0] id_rs2_addr_i,

    input  logic       ex_valid_i,
    input  logic       ex_ready_i,
    input  logic       ex_is_load_i, 
    input  logic       ex_pc_redirect_i, 
    input  logic [4:0] ex_gpr_waddr_i,

    input  logic       lsu_stall_i,
    input  logic       trap_flush_i,

    output logic       if_stall_o,  // Controls IF/ID register
    output logic       if_flush_o,   
    output logic       id_stall_o,  // Controls ID/EX register
    output logic       id_flush_o,
    output logic       ex_stall_o,  // Controls EX/MEM register
    output logic       ex_flush_o,
    output logic       mem_stall_o, // Controls MEM/WB register
    output logic       mem_flush_o
);
    logic id_uses_ex_rd;
    logic load_use_hazard;

    assign id_uses_ex_rd = ((id_rs1_re_i && (id_rs1_addr_i == ex_gpr_waddr_i))   ||
                            (id_rs2_re_i && (id_rs2_addr_i == ex_gpr_waddr_i)))  &&
                           (ex_gpr_waddr_i != 5'd0);

    assign load_use_hazard = ex_valid_i && ex_is_load_i && id_valid_i && id_uses_ex_rd;

    always_comb begin
        if_stall_o  = 0;
        if_flush_o  = 0;
        id_stall_o  = 0;
        id_flush_o  = 0;
        ex_stall_o  = 0;
        ex_flush_o  = 0;
        mem_stall_o = 0;
        mem_flush_o = 0;

        if (trap_flush_i) begin
            if_flush_o  = 1;
            id_flush_o  = 1;
            ex_flush_o  = 1;
            mem_flush_o = 1;
        end
        else if (lsu_stall_i) begin
            if_stall_o  = 1;
            id_stall_o  = 1;
            ex_stall_o  = 1;
            mem_flush_o = 1; 
        end
        else if (!ex_ready_i) begin
            if_stall_o  = 1;
            id_stall_o  = 1;
            ex_flush_o  = 1; 
        end
        else if (ex_pc_redirect_i) begin
            if_flush_o = 1;
            id_flush_o = 1;
        end
        else if (load_use_hazard) begin
            if_stall_o = 1;
            id_flush_o = 1;
        end
    end
endmodule
