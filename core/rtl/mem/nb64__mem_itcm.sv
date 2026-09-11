module nb64__mem_itcm (
    input  logic        clk,
    input  logic        req,
    input  logic        we,
    input  logic [63:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);
`ifndef HARDEN
    logic [31:0] mem [0:16383];

    always_ff @(posedge clk) begin
        if (req) begin
            if (we) begin
                mem[addr[15:2]] <= wdata;
            end
            else begin
                rdata <= mem[addr[15:2]];
            end
        end
    end
`else
    CF_SRAM_16384x32_core u_itcm_sram (
        .DO         (rdata),
        .DI         (32'h00000000),
        .BEN        (32'hFFFFFFFF),
        .AD         (addr[15:2]),
        .EN         (req),
        .R_WB       (~we),
        .CLKin      (clk),
        
        .ScanOutCC  (),
        .ScanInCC   (1'b0),
        .ScanInDL   (1'b0),
        .ScanInDR   (1'b0),
        .SM         (1'b0),
        .TM         (1'b0),
        .WLBI       (1'b0),
        .WLOFF      (1'b0),
        .vpwrpc     (1'b1),
        .vpwrac     (1'b1)
        
    `ifdef USE_POWER_PINS
        ,.vgnd      (1'b0),
        .vnb        (1'b0),
        .vpb        (1'b1),
        .vpwra      (1'b1),
        .vpwrm      (1'b1),
        .vpwrp      (1'b1)
    `endif
    );
`endif
endmodule
