module nb64__sys_xip (
    input  logic        clk,
    input  logic        rst,

    input  logic        start,
    input  logic [23:0] raddr,
    output logic [31:0] rdata,
    output logic        ready,
    output logic        valid,

    output logic        cs_n,
    output logic        sclk,
    output logic        mosi,
    input  logic        miso
);
    localparam logic [7:0] CMD_READ = 8'h03;

    typedef enum logic [1:0] {
        STATE_IDLE = 2'd0,
        STATE_CMD  = 2'd1,
        STATE_ADDR = 2'd2,
        STATE_DATA = 2'd3
    } state_t;

    state_t      state;

    logic        cpol;
    logic        cpha;
    logic [4:0]  bit_cnt;
    logic [7:0]  cmd_q;
    logic [23:0] raddr_q;

    logic        leading_edge;
    logic        trailing_edge;
    logic        shift_edge;
    logic        sample_edge;

    logic        tick;

    assign leading_edge  = (sclk == cpol);
    assign trailing_edge = (sclk != cpol);
    assign shift_edge    = (cpha) ? leading_edge  : trailing_edge;
    assign sample_edge   = (cpha) ? trailing_edge : leading_edge;

    // When the FSM is wrapped with a check on 'tick', it
    // effectively divides the system clock by 4. On a 100 MHz
    // system, this will produce an SCLK of 25 MHz

    always_ff @(posedge clk) begin
        if (rst || (state == STATE_IDLE)) begin
            tick <= 0;
        end
        else begin
            tick <= ~tick;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            cpol     <= 0;
            cpha     <= 0;
            bit_cnt  <= 0;
            cmd_q    <= 0;
            raddr_q  <= 0;
            rdata    <= 0;
            ready    <= 1;
            valid    <= 0;
            cs_n     <= 1;
            sclk     <= cpol;
            mosi     <= 0;
            state    <= STATE_IDLE;
        end
        else begin
            unique case (state)
                STATE_IDLE: begin
                    ready <= 1;
                    valid <= 0;
                    cs_n  <= 1;
                    sclk  <= cpol;

                    if (start && ready) begin
                        bit_cnt  <= 0;
                        raddr_q  <= raddr;
                        ready    <= 0;
                        cs_n     <= 0;
                        sclk     <= cpol;
                        state    <= STATE_CMD;
                        
                        if (cpha) begin
                            cmd_q <= CMD_READ;
                            mosi  <= 0;
                        end
                        else begin
                            cmd_q <= (CMD_READ << 1);
                            mosi  <= CMD_READ[7];
                        end

                    end
                end
                STATE_CMD: begin
                    if (tick) begin
                        sclk <= ~sclk;

                        if (shift_edge) begin
                            mosi    <= cmd_q[7];
                            cmd_q   <= (cmd_q << 1);
                        end
                        else begin
                            if (bit_cnt == 7) begin
                                bit_cnt <= 0;
                                state   <= STATE_ADDR;
                            end
                            else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                STATE_ADDR: begin
                    if (tick) begin
                        sclk <= ~sclk;

                        if (shift_edge) begin
                            mosi     <= raddr_q[23];
                            raddr_q  <= (raddr_q << 1);
                        end
                        else begin
                            if (bit_cnt == 23) begin
                                bit_cnt <= 0;
                                state   <= STATE_DATA;
                            end
                            else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                STATE_DATA: begin
                    if (tick) begin
                        sclk <= ~sclk;

                        if (shift_edge) begin
                            // Do nothing; RX only
                        end
                        else begin
                            rdata <= (rdata << 1) | {31'b0, miso};

                            if (bit_cnt == 31) begin
                                bit_cnt <= 0; // Technically redundant
                                valid   <= 1;
                                state   <= STATE_IDLE;
                            end
                            else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
