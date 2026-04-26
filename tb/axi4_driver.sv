`timescale 1ns/1ps

class axi4_driver;
    
    virtual axi4_interface.tb vif;
    mailbox #(axi4_transaction) mbx;

    function new(virtual axi4_interface.tb vif, mailbox #(axi4_transaction) mbx);
        this.vif = vif;
        this.mbx = mbx;
    endfunction

    task run();
        forever begin
            axi4_transaction tr;
            mbx.get(tr);
            drive_transaction(tr);
        end
    endtask

    task drive_transaction(axi4_transaction tr);
        tr.display("Driver");
        case (tr.operation)
            1: drive_write(tr); // Write operation
            2: drive_read(tr);  // Read operation
            default: $error("[%0t] Driver: Invalid operation %0d", $time, tr.operation);
        endcase
    endtask

    task drive_write(axi4_transaction tr);
        // Apply delays before AWVALID
        repeat (tr.aw_valid_delay) @(vif.cb_tb);

        // Drive AW channel
        @(vif.cb_tb) begin
            vif.cb_tb.AWID    <= tr.id;
            vif.cb_tb.AWADDR  <= tr.addr;
            vif.cb_tb.AWLEN   <= tr.len;
            vif.cb_tb.AWSIZE  <= tr.size;
            vif.cb_tb.AWBURST <= tr.burst;
            vif.cb_tb.AWVALID <= 1;
        end

        // Wait for AWREADY
        @(vif.cb_tb) while (!vif.cb_tb.AWREADY) @(vif.cb_tb);
        @(vif.cb_tb) vif.cb_tb.AWVALID <= 0;

        // Drive W channel
        for (int i = 0; i <= tr.len; i++) begin
            // Apply delays before WVALID
            repeat (tr.w_valid_delay) @(vif.cb_tb);

            @(vif.cb_tb) begin
                vif.cb_tb.WDATA  <= tr.data;
                vif.cb_tb.WSTRB  <= tr.strb;
                vif.cb_tb.WVALID <= 1;
                vif.cb_tb.WLAST  <= (i == tr.len) ? 1 : 0;
            end
            @(vif.cb_tb) while (!vif.cb_tb.WREADY) @(vif.cb_tb);
            @(vif.cb_tb) vif.cb_tb.WVALID <= 0;
        end

        // Wait for B response
        // Apply delays before BREADY
        repeat (tr.b_ready_delay) @(vif.cb_tb);
        @(vif.cb_tb) vif.cb_tb.BREADY <= 1;
        @(vif.cb_tb) while (!vif.cb_tb.BVALID) @(vif.cb_tb);
        @(vif.cb_tb) vif.cb_tb.BREADY <= 0;
    endtask

    task drive_read(axi4_transaction tr);
        // Apply delays before ARVALID
        repeat (tr.ar_valid_delay) @(vif.cb_tb);

        // Drive AR channel
        @(vif.cb_tb) begin
            vif.cb_tb.ARID    <= tr.id;
            vif.cb_tb.ARADDR  <= tr.addr;
            vif.cb_tb.ARLEN   <= tr.len;
            vif.cb_tb.ARSIZE  <= tr.size;
            vif.cb_tb.ARBURST <= tr.burst;
            vif.cb_tb.ARVALID <= 1;
        end

        // Wait for ARREADY
        @(vif.cb_tb) while (!vif.cb_tb.ARREADY) @(vif.cb_tb);
        @(vif.cb_tb) vif.cb_tb.ARVALID <= 0;

        // Wait for R response
        for (int i = 0; i <= tr.len; i++) begin
            // Apply delays before RREADY
            repeat (tr.r_ready_delay) @(vif.cb_tb);

            @(vif.cb_tb) vif.cb_tb.RREADY <= 1;
            @(vif.cb_tb) while (!vif.cb_tb.RVALID) @(vif.cb_tb);
            @(vif.cb_tb) vif.cb_tb.RREADY <= 0;
        end
    endtask

endclass
