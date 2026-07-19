// -----------------------------------------------------------------------------
// Testbench   : tb_axi4_lite_slave
// Description : Self-checking directed + constrained-random testbench for
//               the AXI4-Lite slave. Drives independent write and read
//               channel handshakes, checks read-after-write data integrity
//               and SLVERR generation on out-of-range addresses.
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_axi4_lite_slave;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam NUM_REGS   = 8;

    logic aclk, aresetn;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic awvalid, awready;
    logic [DATA_WIDTH-1:0] wdata;
    logic [3:0] wstrb;
    logic wvalid, wready;
    logic [1:0] bresp;
    logic bvalid, bready;
    logic [ADDR_WIDTH-1:0] araddr;
    logic arvalid, arready;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rvalid, rready;

    int pass_count = 0;
    int fail_count = 0;
    logic [31:0] shadow_reg [0:NUM_REGS-1];

    axi4_lite_slave #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .NUM_REGS(NUM_REGS)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    initial aclk = 0;
    always #5 aclk = ~aclk;

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        @(posedge aclk);
        awaddr = addr; awvalid = 1;
        wdata  = data; wstrb = 4'hF; wvalid = 1;
        bready = 1;
        @(posedge aclk);
        while (!awready) @(posedge aclk);
        awvalid = 0;
        while (!wready) @(posedge aclk);
        wvalid = 0;
        while (!bvalid) @(posedge aclk);
        if (bresp == 2'b00 && addr[31:5] == 0)
            shadow_reg[addr[4:2]] = data;
        @(posedge aclk);
        bready = 0;
    endtask

    task automatic axi_read(input [31:0] addr, input bit expect_error = 0);
        @(posedge aclk);
        araddr = addr; arvalid = 1;
        rready = 1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        arvalid = 0;
        while (!rvalid) @(posedge aclk);
        #1;
        if (expect_error) begin
            if (rresp == 2'b10) begin
                $display("[PASS] SLVERR correctly returned for addr=%0h", addr);
                pass_count++;
            end else begin
                $error("[FAIL] Expected SLVERR for addr=%0h, got rresp=%0b", addr, rresp);
                fail_count++;
            end
        end else begin
            if (rdata === shadow_reg[addr[4:2]] && rresp == 2'b00) begin
                $display("[PASS] Read addr=%0h data=%0h matches shadow model", addr, rdata);
                pass_count++;
            end else begin
                $error("[FAIL] Read mismatch addr=%0h: expected=%0h got=%0h rresp=%0b",
                       addr, shadow_reg[addr[4:2]], rdata, rresp);
                fail_count++;
            end
        end
        @(posedge aclk);
        rready = 0;
    endtask

    initial begin
        $dumpfile("waveform/axi4_lite_slave.vcd");
        $dumpvars(0, tb_axi4_lite_slave);

        $display("=========================================================");
        $display(" AXI4-Lite Slave Controller Testbench");
        $display("=========================================================");

        aresetn = 0; awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
        awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (3) @(posedge aclk);

        $display("[TEST] Directed: write then read-back all 8 registers");
        for (int i = 0; i < NUM_REGS; i++) begin
            axi_write(i*4, 32'hA000_0000 + i);
        end
        for (int i = 0; i < NUM_REGS; i++) begin
            axi_read(i*4);
        end

        $display("[TEST] Directed: out-of-range read returns SLVERR");
        axi_read(32'h0000_1000, 1);

        $display("[TEST] Constrained-random write/read regression (100 transactions)");
        for (int i = 0; i < 100; i++) begin
            int reg_sel;
            logic [31:0] rand_data;
            reg_sel   = $urandom_range(0, NUM_REGS-1);
            rand_data = $urandom;
            axi_write(reg_sel*4, rand_data);
            axi_read(reg_sel*4);
        end

        $display("=========================================================");
        $display(" REGRESSION SUMMARY: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("=========================================================");

        #20 $finish;
    end

endmodule
