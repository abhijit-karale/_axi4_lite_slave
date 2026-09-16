  // -----------------------------------------------------------------------------
// Module      : axi4_lite_slave
// Description : AXI4-Lite slave with 8 memory-mapped 32-bit registers.
//               Implements independent write-address/write-data/write-response
//               and read-address/read-data channels per AXI4-Lite protocol.
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
module axi4_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 8
) (
    input  logic                    aclk,
    input  logic                    aresetn,

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]   awaddr,
    input  logic                    awvalid,
    output logic                    awready,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wvalid,
    output logic                    wready,

    // Write response channel
    output logic [1:0]              bresp,
    output logic                    bvalid,
    input  logic                    bready,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]   araddr,
    input  logic                    arvalid,
    output logic                    arready,

    // Read data channel
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [1:0]              rresp,
    output logic                    rvalid,
    input  logic                    rready
);

    localparam REG_ADDR_W = $clog2(NUM_REGS);
    logic [DATA_WIDTH-1:0] regfile [0:NUM_REGS-1];

    // -------------------- Write channel FSM --------------------
    logic [ADDR_WIDTH-1:0] awaddr_latched;

    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wr_state_t;
    wr_state_t wr_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state       <= W_IDLE;
            awready        <= 1'b0;
            wready         <= 1'b0;
            bvalid         <= 1'b0;
            bresp          <= 2'b00;
            awaddr_latched <= '0;
            for (int i = 0; i < NUM_REGS; i++) regfile[i] <= '0;
        end else begin
            case (wr_state)
                W_IDLE: begin
                    bvalid <= 1'b0;
                    if (awvalid) begin
                        awready        <= 1'b1;
                        awaddr_latched <= awaddr;
                        wr_state       <= W_DATA;
                    end
                end
                W_DATA: begin
                    awready <= 1'b0;
                    if (wvalid) begin
                        wready <= 1'b1;
                        if (awaddr_latched[ADDR_WIDTH-1:REG_ADDR_W+2] == '0) begin
                            for (int b = 0; b < DATA_WIDTH/8; b++) begin
                                if (wstrb[b])
                                    regfile[awaddr_latched[REG_ADDR_W+1:2]][b*8 +: 8] <= wdata[b*8 +: 8];
                            end
                            bresp <= 2'b00; // OKAY
                        end else begin
                            bresp <= 2'b10; // SLVERR - out of range
                        end
                        wr_state <= W_RESP;
                    end
                end
                W_RESP: begin
                    wready <= 1'b0;
                    bvalid <= 1'b1;
                    if (bvalid && bready) begin
                        bvalid   <= 1'b0;
                        wr_state <= W_IDLE;
                    end
                end
                default: wr_state <= W_IDLE;
            endcase
        end
    end

    // -------------------- Read channel FSM --------------------
    typedef enum logic [1:0] {R_IDLE, R_DATA} rd_state_t;
    rd_state_t rd_state;
    logic [ADDR_WIDTH-1:0] araddr_latched;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state       <= R_IDLE;
            arready        <= 1'b0;
            rvalid         <= 1'b0;
            rresp          <= 2'b00;
            rdata          <= '0;
            araddr_latched <= '0;
        end else begin
            case (rd_state)
                R_IDLE: begin
                    if (arvalid) begin
                        arready        <= 1'b1;
                        araddr_latched <= araddr;
                        rd_state       <= R_DATA;
                    end
                end
                R_DATA: begin
                    arready <= 1'b0;
                    if (!rvalid) begin
                        if (araddr_latched[ADDR_WIDTH-1:REG_ADDR_W+2] == '0) begin
                            rdata <= regfile[araddr_latched[REG_ADDR_W+1:2]];
                            rresp <= 2'b00;
                        end else begin
                            rdata <= 32'hDEAD_BEEF;
                            rresp <= 2'b10; // SLVERR
                        end
                        rvalid <= 1'b1;
                    end else if (rvalid && rready) begin
                        rvalid   <= 1'b0;
                        rd_state <= R_IDLE;
                    end
                end
                default: rd_state <= R_IDLE;
            endcase
        end
    end

endmodule
