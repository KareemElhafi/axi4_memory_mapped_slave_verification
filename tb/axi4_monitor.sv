`timescale 1ns/1ps

class axi4_monitor;

    virtual axi4_interface.dut vif;
    mailbox #(axi4_transaction) mbx_monitor_to_scoreboard;

    function new(virtual axi4_interface.dut vif, mailbox #(axi4_transaction) mbx_monitor_to_scoreboard);
        this.vif = vif;
        this.mbx_monitor_to_scoreboard = mbx_monitor_to_scoreboard;
    endfunction

    task run();
        fork
            monitor_write_channel();
            monitor_read_channel();
        join
    endtask

    task monitor_write_channel();
        axi4_transaction tr;
        forever begin
            // Wait for AWVALID and AWREADY handshake
            @(vif.cb_dut) while (!(vif.cb_dut.AWVALID && vif.cb_dut.AWREADY)) @(vif.cb_dut);

            tr = new();
            tr.id    = vif.cb_dut.AWID;
            tr.addr  = vif.cb_dut.AWADDR;
            tr.len   = vif.cb_dut.AWLEN;
            tr.size  = vif.cb_dut.AWSIZE;
            tr.burst = vif.cb_dut.AWBURST;
            tr.operation = 1; // Write operation

            // Collect WDATA beats
            for (int i = 0; i <= tr.len; i++) begin
                @(vif.cb_dut) while (!(vif.cb_dut.WVALID && vif.cb_dut.WREADY)) @(vif.cb_dut);
                // For monitor, we capture the data as it appears on the bus
                // The actual data written to memory depends on WSTRB, which the scoreboard will handle
                tr.data = vif.cb_dut.WDATA; // This is simplified; in a real monitor, you'd collect all beats
                tr.strb = vif.cb_dut.WSTRB;
                if (vif.cb_dut.WLAST) break; // Break if WLAST is asserted
            end

            // Wait for BVALID and BREADY handshake
            @(vif.cb_dut) while (!(vif.cb_dut.BVALID && vif.cb_dut.BREADY)) @(vif.cb_dut);
            // Monitor captures BRESP, Scoreboard compares
            // tr.bresp = vif.cb_dut.BRESP; // Add bresp to transaction if needed for scoreboard

            tr.display("Monitor (Write)");
            mbx_monitor_to_scoreboard.put(tr);
        end
    endtask

    task monitor_read_channel();
        axi4_transaction tr;
        forever begin
            // Wait for ARVALID and ARREADY handshake
            @(vif.cb_dut) while (!(vif.cb_dut.ARVALID && vif.cb_dut.ARREADY)) @(vif.cb_dut);

            tr = new();
            tr.id    = vif.cb_dut.ARID;
            tr.addr  = vif.cb_dut.ARADDR;
            tr.len   = vif.cb_dut.ARLEN;
            tr.size  = vif.cb_dut.ARSIZE;
            tr.burst = vif.cb_dut.ARBURST;
            tr.operation = 2; // Read operation

            // Collect RDATA beats
            for (int i = 0; i <= tr.len; i++) begin
                @(vif.cb_dut) while (!(vif.cb_dut.RVALID && vif.cb_dut.RREADY)) @(vif.cb_dut);
                // For monitor, we capture the data as it appears on the bus
                // tr.rdata_queue.push_back(vif.cb_dut.RDATA); // In a real monitor, you'd collect all beats into a queue
                if (vif.cb_dut.RLAST) break; // Break if RLAST is asserted
            end

            tr.display("Monitor (Read)");
            mbx_monitor_to_scoreboard.put(tr);
        end
    endtask

endclass
