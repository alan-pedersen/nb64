module nb64__sys_bootmgr (
    input  logic        clk,
    input  logic        rst,

    output logic        xip_start_o,
    output logic [23:0] xip_raddr_o,
    input  logic [31:0] xip_rdata_i,
    input  logic        xip_ready_i,
    input  logic        xip_valid_i,

    output logic        itcm_req_o,
    output logic        itcm_we_o,
    output logic [63:0] itcm_addr_o,
    output logic [31:0] itcm_wdata_o,

    output logic        dtcm_req_o,
    output logic        dtcm_we_o,
    output logic [7:0]  dtcm_be_o,
    output logic [63:0] dtcm_addr_o,
    output logic [63:0] dtcm_wdata_o,

    output logic        boot_done_o
);
    // Bootmgr assumes the flash image is of the following format:
    // uint32_t idata_size
    // uint32_t ddata_size
    // uint32_t idata[]
    // uint32_t ddata[]
    typedef enum logic [2:0] {
        ST_INIT         = 3'd0,
        ST_READ_ITCM_SZ = 3'd1,
        ST_READ_DTCM_SZ = 3'd2,
        ST_COPY_ITCM    = 3'd3,
        ST_COPY_DTCM    = 3'd4,
        ST_DONE         = 3'd5
    } state_t;

    state_t      state;

    logic        req_pending;
    logic [23:0] itcm_size;
    logic [23:0] dtcm_size;
    logic [23:0] word_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            xip_start_o <= 0;
            xip_raddr_o <= 0;
            itcm_req_o  <= 0;
            itcm_we_o   <= 0;
            dtcm_req_o  <= 0;
            dtcm_we_o   <= 0;
            boot_done_o <= 0;
            state       <= ST_INIT;
        end
        else begin
            unique case (state)
                ST_INIT: begin
                    req_pending <= 0;
                    word_cnt    <= 0;
                    state       <= ST_READ_ITCM_SZ;
                end
                ST_READ_ITCM_SZ: begin
                    xip_start_o <= 0;

                    if (xip_ready_i && !req_pending) begin
                        xip_start_o <= 1;
                        xip_raddr_o <= 24'h000000;
                        req_pending <= 1;
                    end
                    else if (xip_valid_i && req_pending) begin
                        itcm_size   <= xip_rdata_i[23:0];
                        req_pending <= 0;
                        state       <= ST_READ_DTCM_SZ;
                    end
                end
                ST_READ_DTCM_SZ: begin
                    xip_start_o <= 0;

                    if (xip_ready_i && !req_pending) begin
                        xip_start_o <= 1;
                        xip_raddr_o <= 24'h000004;
                        req_pending <= 1;
                    end
                    else if (xip_valid_i && req_pending) begin
                        dtcm_size   <= xip_rdata_i[23:0];
                        req_pending <= 0;

                        if (itcm_size == 0) begin
                            if (xip_rdata_i[23:0] == 0) begin
                                state <= ST_DONE;
                            end
                            else begin
                                state <= ST_COPY_DTCM;
                            end
                        end
                        else begin
                            state <= ST_COPY_ITCM;
                        end
                    end
                end
                ST_COPY_ITCM: begin
                    xip_start_o <= 0;
                    itcm_req_o  <= 0;
                    itcm_we_o   <= 0;

                    if (xip_ready_i && !req_pending) begin
                        xip_start_o <= 1;
                        xip_raddr_o <= xip_raddr_o + 4;
                        req_pending <= 1;
                    end
                    else if (xip_valid_i && req_pending) begin
                        itcm_req_o   <= 1;
                        itcm_we_o    <= 1;
                        itcm_addr_o  <= 64'(word_cnt) << 2; 
                        itcm_wdata_o <= xip_rdata_i;
                        word_cnt     <= word_cnt + 1;

                        if (word_cnt == itcm_size - 1) begin
                            req_pending  <= 0;

                            if (dtcm_size != 0) begin
                                word_cnt <= 0;
                                state    <= ST_COPY_DTCM;
                            end
                            else begin
                                state <= ST_DONE;
                            end
                        end
                        else begin
                            if (xip_ready_i) begin
                                xip_start_o <= 1;
                                xip_raddr_o <= xip_raddr_o + 4;
                                req_pending <= 1;
                            end
                            else begin
                                req_pending <= 0;
                            end
                        end
                    end
                end
                ST_COPY_DTCM: begin
                    xip_start_o <= 0;
                    dtcm_req_o  <= 0;
                    dtcm_we_o   <= 0;

                    if (xip_ready_i && !req_pending) begin
                        xip_start_o <= 1;
                        xip_raddr_o <= xip_raddr_o + 4;
                        req_pending <= 1;
                    end
                    else if (xip_valid_i && req_pending) begin
                        dtcm_req_o   <= 1;
                        dtcm_we_o    <= 1;
                        dtcm_be_o    <= word_cnt[0] ? 8'hF0 : 8'h0F;
                        dtcm_addr_o  <= 64'(word_cnt[23:1]) << 3; // word_cnt[23:1] is the 64-bit word index
                        dtcm_wdata_o <= {xip_rdata_i, xip_rdata_i};
                        word_cnt     <= word_cnt + 1;

                        if (word_cnt == dtcm_size - 1) begin
                            req_pending <= 0;
                            state       <= ST_DONE;
                        end
                        else begin
                            if (xip_ready_i) begin
                                xip_start_o <= 1;
                                xip_raddr_o <= xip_raddr_o + 4;
                                req_pending <= 1;
                            end
                            else begin
                                req_pending <= 0;
                            end
                        end
                    end
                end
                ST_DONE: begin
                    boot_done_o <= 1;
                end
            endcase
        end
    end
endmodule
