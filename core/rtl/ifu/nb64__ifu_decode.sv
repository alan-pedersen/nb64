module nb64__ifu_decode #(
    parameter int XLEN = 64
)(
    input logic             clk,
    input logic             rst,
    input logic             id_valid_i,
    input logic             id_stall_i,
    input logic             id_flush_i,

    input logic [XLEN-1:0]  instr,
    input logic [XLEN-1:0]  pc_i,

    output logic [4:0]      rs1_,
    output logic [4:0]      rs2_,
    input  logic [XLEN-1:0] rs1_,
    input  logic [XLEN-1:0] rs2_,

    // CSR interface ??

    output logic [XLEN-1:0] pc_o,
    output logic [XLEN-1:0] imm,
    output logic [XLEN-1:0] rs1_,
    output logic [XLEN-1:0] rs2_
);
    opcode_t         opcode;
	logic [2:0]      funct3;
	logic [4:0]      funct5;
	logic [6:0]      funct7;
	logic [11:0]     funct12;

	logic [XLEN-1:0] imm_i;
	logic [XLEN-1:0] imm_s;
	logic [XLEN-1:0] imm_u;
	logic [XLEN-1:0] imm_b;
	logic [XLEN-1:0] imm_j;
	logic [XLEN-1:0] imm;

	assign opcode  = opcode_t'(instr[6:0]);
	assign funct3  = instr[14:12];
	assign funct5  = instr[31:27];
	assign funct7  = instr[31:25];
	assign funct12 = instr[31:20];

	assign imm_i   = { {(XLEN-12){instr[31]}}, instr[31:20] };
	assign imm_s   = { {(XLEN-12){instr[31]}}, instr[31:25], instr[11:7] };
	assign imm_u   = { {(XLEN-32){instr[31]}}, instr[31:12], 12'b0 };
	assign imm_b   = { {(XLEN-12){instr[31]}}, instr[7],     instr[30:25], instr[11:8],  1'b0 };
	assign imm_j   = { {(XLEN-20){instr[31]}}, instr[19:12], instr[20],    instr[30:21], 1'b0 };

    // assign imm here 
    always_comb begin
        unique case (opcode)
            OP_REG: begin
                
            end
            OP_IMM: begin
                
            end
            OP_REG_32: begin
                
            end
            OP_IMM_32: begin
                
            end
            OP_LUI: begin
                
            end
            OP_AUIPC: begin
                
            end
            OP_JAL: begin
                
            end
            OP_JALR: begin
                
            end
            OP_BRANCH: begin
                
            end
            OP_LOAD: begin
                
            end
            OP_STORE: begin
                
            end
            OP_AMO: begin
                
            end
            OP_MISC_MEM: begin
                
            end
            OP_SYSTEM: begin
                
            end
        endcase
    end
endmodule
