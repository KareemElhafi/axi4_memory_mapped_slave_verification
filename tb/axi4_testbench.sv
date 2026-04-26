`timescale 1ns/1ps
`include "axi4_transaction.sv"
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_scoreboard.sv"
`include "axi4_sequencer.sv"

module axi4_testbench;

    // Parameters (must match DUT and transaction class)
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter MEMORY_DEPTH = 1024;
    parameter ID_WIDTH = 4;

    // Clock and Reset generation
    bit ACLK;
    bit ARESETn;

    initial begin
        ACLK = 0;
        forever #5ns ACLK = ~ACLK; // 10ns clock period
    end

    // Instantiate AXI4 Interface
    axi4_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .ID_WIDTH(ID_WIDTH)
    ) axi_vif (ACLK, ARESETn);

    // Instantiate DUT
    axi4 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEMORY_DEPTH(MEMORY_DEPTH),
        .ID_WIDTH(ID_WIDTH)
    ) dut_inst (
        .ACLK(axi_vif.ACLK),
        .ARESETn(axi_vif.ARESETn),

        .AWID(axi_vif.AWID),
        .AWADDR(axi_vif.AWADDR),
        .AWLEN(axi_vif.AWLEN),
        .AWSIZE(axi_vif.AWSIZE),
        .AWBURST(axi_vif.AWBURST),
        .AWVALID(axi_vif.AWVALID),
        .AWREADY(axi_vif.AWREADY),

        .WDATA(axi_vif.WDATA),
        .WSTRB(axi_vif.WSTRB),
        .WVALID(axi_vif.WVALID),
        .WLAST(axi_vif.WLAST),
        .WREADY(axi_vif.WREADY),

        .BID(axi_vif.BID),
        .BRESP(axi_vif.BRESP),
        .BVALID(axi_vif.BVALID),
        .BREADY(axi_vif.BREADY),

        .ARID(axi_vif.ARID),
        .ARADDR(axi_vif.ARADDR),
        .ARLEN(axi_vif.ARLEN),
        .ARSIZE(axi_vif.ARSIZE),
        .ARBURST(axi_vif.ARBURST),
        .ARVALID(axi_vif.ARVALID),
        .ARREADY(axi_vif.ARREADY),

        .RID(axi_vif.RID),
        .RDATA(axi_vif.RDATA),
        .RRESP(axi_vif.RRESP),
        .RVALID(axi_vif.RVALID),
        .RLAST(axi_vif.RLAST),
        .RREADY(axi_vif.RREADY)
    );

    // Mailboxes for communication
    mailbox #(axi4_transaction) mbx_driver;
    mailbox #(axi4_transaction) mbx_monitor;

    // Instantiate components
    axi4_driver    driver;
    axi4_monitor   monitor;
    axi4_scoreboard scoreboard;
    axi4_sequencer sequencer;

    initial begin
        mbx_driver  = new();
        mbx_monitor = new();

        driver     = new(axi_vif.tb, mbx_driver);
        monitor    = new(axi_vif.dut, mbx_monitor);
        scoreboard = new(mbx_monitor);
        sequencer  = new(mbx_driver);

        // Reset sequence
        ARESETn = 1'b0;
        repeat (5) @(posedge ACLK);
        ARESETn = 1'b1;
        repeat (5) @(posedge ACLK);

        // Start component tasks
        fork
            driver.run();
            monitor.run();
            scoreboard.run();
            run_test();
        join

        // End simulation
        #1000ns;
        $finish;
    end

    task run_test();
        axi4_transaction tr;
        repeat (100) begin // Generate 100 random transactions
            tr = new();
            assert(tr.randomize()) else $fatal(1, "Transaction randomization failed");
            tr.axi4_cov.sample(); // Sample coverage
            sequencer.mbx_sequencer_to_driver.put(tr);
        end
    endtask

    final begin
        scoreboard.report();
        $display("Total coverage: %0.2f%%", axi4_transaction::axi4_cov.get_coverage());
    end

endmodule
