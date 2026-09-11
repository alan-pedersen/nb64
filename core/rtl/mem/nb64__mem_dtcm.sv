module nb64__mem_dtcm (
    input  logic        clk,
    input  logic        req,
    input  logic        we,
    input  logic [7:0]  be,
    input  logic [63:0] addr,
    input  logic [63:0] wdata,
    output logic [63:0] rdata
);
    // Expand 4-bit byte enables to 32-bit bit enables for the macro
    function automatic logic [31:0] expand_be(input logic [3:0] be);
        expand_be = { {8{be[3]}}, {8{be[2]}}, {8{be[1]}}, {8{be[0]}} };
    endfunction

    logic [13:0] sram_addr;
    logic [31:0] ben_low;
    logic [31:0] ben_high;

    assign sram_addr = {1'b0, addr[15:3]}; // MSB tied to 0 to restrict to 64KiB
    assign ben_low   = expand_be(be[3:0]);
    assign ben_high  = expand_be(be[7:4]);

`ifndef HARDEN
    logic [63:0] mem [0:8191];

    always_ff @(posedge clk) begin
        if (req) begin
            if (we) begin
                if (be[0]) mem[sram_addr[12:0]][7:0]   <= wdata[7:0];
                if (be[1]) mem[sram_addr[12:0]][15:8]  <= wdata[15:8];
                if (be[2]) mem[sram_addr[12:0]][23:16] <= wdata[23:16];
                if (be[3]) mem[sram_addr[12:0]][31:24] <= wdata[31:24];
                if (be[4]) mem[sram_addr[12:0]][39:32] <= wdata[39:32];
                if (be[5]) mem[sram_addr[12:0]][47:40] <= wdata[47:40];
                if (be[6]) mem[sram_addr[12:0]][55:48] <= wdata[55:48];
                if (be[7]) mem[sram_addr[12:0]][63:56] <= wdata[63:56];
            end
            else begin
                rdata <= mem[sram_addr[12:0]];
            end
        end
    end
`else
    // Lower 32 bits
    CF_SRAM_16384x32_core u_dtcm_sram_low (
        .DO        (rdata[31:0]),
        .DI        (wdata[31:0]),
        .BEN       (ben_low),
        .AD        (sram_addr),
        .EN        (req),
        .R_WB      (~we), // W=0, R=1
        .CLKin     (clk),
        
        .ScanOutCC (),
        .ScanInCC  (1'b0),
        .ScanInDL  (1'b0),
        .ScanInDR  (1'b0),
        .SM        (1'b0),
        .TM        (1'b0),
        .WLBI      (1'b0),
        .WLOFF     (1'b0),
        .vpwrpc    (1'b1),
        .vpwrac    (1'b1)
        
    `ifdef USE_POWER_PINS
        ,.vgnd     (1'b0),
        .vnb       (1'b0),
        .vpb       (1'b1),
        .vpwra     (1'b1),
        .vpwrm     (1'b1),
        .vpwrp     (1'b1)
    `endif
    );

    // Upper 32 bits
    CF_SRAM_16384x32_core u_dtcm_sram_high (
        .DO        (rdata[63:32]),
        .DI        (wdata[63:32]),
        .BEN       (ben_high),
        .AD        (sram_addr),
        .EN        (req),
        .R_WB      (~we),
        .CLKin     (clk),
        
        .ScanOutCC (),
        .ScanInCC  (1'b0),
        .ScanInDL  (1'b0),
        .ScanInDR  (1'b0),
        .SM        (1'b0),
        .TM        (1'b0),
        .WLBI      (1'b0),
        .WLOFF     (1'b0),
        .vpwrpc    (1'b1),
        .vpwrac    (1'b1)
        
    `ifdef USE_POWER_PINS
        ,.vgnd     (1'b0),
        .vnb       (1'b0),
        .vpb       (1'b1),
        .vpwra     (1'b1),
        .vpwrm     (1'b1),
        .vpwrp     (1'b1)
    `endif
    );
`endif
endmodule
