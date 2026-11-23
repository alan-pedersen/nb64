package nb64_pkg;
    localparam int XLEN = 64;

    // ================================================================
    // Instruction Opcodes
    // ================================================================

    typedef enum logic [6:0] {
        OP_LOAD     = 7'b0000011,
        OP_STORE    = 7'b0100011,
        OP_MADD     = 7'b1000011,
        OP_BRANCH   = 7'b1100011,
        OP_LOAD_FP  = 7'b0000111,
        OP_STORE_FP = 7'b0100111,
        OP_MSUB     = 7'b1000111,
        OP_JALR     = 7'b1100111,
        OP_CUSTOM0  = 7'b0001011,
        OP_CUSTOM1  = 7'b0101011,
        OP_NMSUB    = 7'b1001011,
        OP_RESERVED = 7'b1101011,
        OP_MISC_MEM = 7'b0001111,
        OP_AMO      = 7'b0101111,
        OP_NMADD    = 7'b1001111,
        OP_JAL      = 7'b1101111,
        OP_IMM      = 7'b0010011,
        OP_REG      = 7'b0110011,
        OP_FP       = 7'b1010011,
        OP_SYSTEM   = 7'b1110011,
        OP_AUIPC    = 7'b0010111,
        OP_LUI      = 7'b0110111,
        OP_V        = 7'b1010111,
        OP_VE       = 7'b1110111,
        OP_IMM_32   = 7'b0011011,
        OP_REG_32   = 7'b0111011,
        OP_CUSTOM2  = 7'b1011011,
        OP_CUSTOM3  = 7'b1111011
    } opcode_e;
endpackage
