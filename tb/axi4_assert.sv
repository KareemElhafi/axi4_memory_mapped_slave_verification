`timescale 1ns/1ps

module axi4_assert (axi4_interface.dut inter);

    // Parameters (must match DUT)
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter MEMORY_DEPTH = 1024;
    parameter ID_WIDTH = 4;

    // --------------------------------------------------------------------------
    // Reset Assertions
    // --------------------------------------------------------------------------

    property reset_awready;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.AWREADY == 1'b1;
    endproperty
    A_RESET_AWREADY: assert property (reset_awready) else $error("AWREADY not initialized to 1 after reset");

    property reset_wready;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.WREADY == 1'b0;
    endproperty
    A_RESET_WREADY: assert property (reset_wready) else $error("WREADY not initialized to 0 after reset");

    property reset_bvalid;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.BVALID == 1'b0;
    endproperty
    A_RESET_BVALID: assert property (reset_bvalid) else $error("BVALID not initialized to 0 after reset");

    property reset_arready;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.ARREADY == 1'b1;
    endproperty
    A_RESET_ARREADY: assert property (reset_arready) else $error("ARREADY not initialized to 1 after reset");

    property reset_rvalid;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.RVALID == 1'b0;
    endproperty
    A_RESET_RVALID: assert property (reset_rvalid) else $error("RVALID not initialized to 0 after reset");

    property reset_rlast;
        @(posedge inter.ACLK) !inter.ARESETn |-> inter.RLAST == 1'b0;
    endproperty
    A_RESET_RLAST: assert property (reset_rlast) else $error("RLAST not initialized to 0 after reset");

    // --------------------------------------------------------------------------
    // Write Address Channel (AW) Assertions
    // --------------------------------------------------------------------------

    // AWREADY should deassert after accepting address
    property awready_deassert;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.AWVALID && inter.AWREADY) |=> !inter.AWREADY;
    endproperty
    A_AWREADY_DEASSERT: assert property (awready_deassert) else $error("AWREADY should deassert after address handshake");

    // AW signals must remain stable when AWVALID is high and AWREADY is low
    property aw_stable_when_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.AWVALID && !inter.AWREADY |=> $stable(inter.AWID) && $stable(inter.AWADDR) && $stable(inter.AWLEN) && $stable(inter.AWSIZE) && $stable(inter.AWBURST);
    endproperty
    A_AW_STABLE_WHEN_VALID: assert property (aw_stable_when_valid) else $error("AW signals must remain stable when AWVALID is high and AWREADY is low");

    // AWLEN must be 0-15
    property awlen_range;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.AWVALID |-> (inter.AWLEN >= 0 && inter.AWLEN <= 15);
    endproperty
    A_AWLEN_RANGE: assert property (awlen_range) else $error("AWLEN out of range (0-15)");

    // AWSIZE must be <= DATA_WIDTH
    property awsize_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.AWVALID |-> (inter.AWSIZE <= $clog2(DATA_WIDTH/8));
    endproperty
    A_AWSIZE_VALID: assert property (awsize_valid) else $error("AWSIZE is greater than DATA_WIDTH");

    // AWBURST must be 0 (FIXED), 1 (INCR), or 2 (WRAP)
    property awburst_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.AWVALID |-> (inter.AWBURST inside {2'b00, 2'b01, 2'b10});
    endproperty
    A_AWBURST_VALID: assert property (awburst_valid) else $error("AWBURST is an invalid value");

    // --------------------------------------------------------------------------
    // Write Data Channel (W) Assertions
    // --------------------------------------------------------------------------

    // WDATA and WSTRB must remain stable when WVALID is high and WREADY is low
    property wdata_stable_when_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.WVALID && !inter.WREADY |=> $stable(inter.WDATA) && $stable(inter.WSTRB);
    endproperty
    A_WDATA_STABLE_WHEN_VALID: assert property (wdata_stable_when_valid) else $error("WDATA/WSTRB must remain stable when WVALID is high and WREADY is low");

    // WLAST must be asserted on the last data beat
    property wlast_on_last_beat;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.WVALID && inter.WREADY && inter.WLAST) |=> !inter.WREADY;
    endproperty
    A_WLAST_LAST_BEAT: assert property (wlast_on_last_beat) else $error("WREADY should deassert after WLAST");

    // --------------------------------------------------------------------------
    // Write Response Channel (B) Assertions
    // --------------------------------------------------------------------------

    // BVALID must be asserted after write data completion
    property bvalid_after_wlast;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.WVALID && inter.WREADY && inter.WLAST) |-> ##[1:$] inter.BVALID;
    endproperty
    A_BVALID_AFTER_WLAST: assert property (bvalid_after_wlast) else $error("BVALID should be asserted after WLAST handshake");

    // BRESP and BID must remain stable when BVALID is high and BREADY is low
    property bresp_stable_when_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.BVALID && !inter.BREADY |=> $stable(inter.BRESP) && $stable(inter.BID);
    endproperty
    A_BRESP_STABLE_WHEN_VALID: assert property (bresp_stable_when_valid) else $error("BRESP/BID must remain stable when BVALID is high and BREADY is low");

    // BVALID should deassert after handshake
    property bvalid_deassert;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.BVALID && inter.BREADY) |=> !inter.BVALID;
    endproperty
    A_BVALID_DEASSERT: assert property (bvalid_deassert) else $error("BVALID should deassert after response handshake");

    // BRESP should be OKAY (00) or SLVERR (10)
    property bresp_valid_values;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.BVALID |-> (inter.BRESP == 2'b00 || inter.BRESP == 2'b10);
    endproperty
    A_BRESP_VALID_VALUES: assert property (bresp_valid_values) else $error("Invalid BRESP value: %b", inter.BRESP);

    // --------------------------------------------------------------------------
    // Read Address Channel (AR) Assertions
    // --------------------------------------------------------------------------

    // ARREADY should deassert after accepting address
    property arready_deassert;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.ARVALID && inter.ARREADY) |=> !inter.ARREADY;
    endproperty
    A_ARREADY_DEASSERT: assert property (arready_deassert) else $error("ARREADY should deassert after address handshake");

    // AR signals must remain stable when ARVALID is high and ARREADY is low
    property ar_stable_when_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.ARVALID && !inter.ARREADY |=> $stable(inter.ARID) && $stable(inter.ARADDR) && $stable(inter.ARLEN) && $stable(inter.ARSIZE) && $stable(inter.ARBURST);
    endproperty
    A_AR_STABLE_WHEN_VALID: assert property (ar_stable_when_valid) else $error("AR signals must remain stable when ARVALID is high and ARREADY is low");

    // ARLEN must be 0-15
    property arlen_range;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.ARVALID |-> (inter.ARLEN >= 0 && inter.ARLEN <= 15);
    endproperty
    A_ARLEN_RANGE: assert property (arlen_range) else $error("ARLEN out of range (0-15)");

    // ARSIZE must be <= DATA_WIDTH
    property arsize_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.ARVALID |-> (inter.ARSIZE <= $clog2(DATA_WIDTH/8));
    endproperty
    A_ARSIZE_VALID: assert property (arsize_valid) else $error("ARSIZE is greater than DATA_WIDTH");

    // ARBURST must be 0 (FIXED), 1 (INCR), or 2 (WRAP)
    property arburst_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.ARVALID |-> (inter.ARBURST inside {2'b00, 2'b01, 2'b10});
    endproperty
    A_ARBURST_VALID: assert property (arburst_valid) else $error("ARBURST is an invalid value");

    // --------------------------------------------------------------------------
    // Read Data Channel (R) Assertions
    // --------------------------------------------------------------------------

    // RVALID should be asserted after read address
    property rvalid_after_araddr;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.ARVALID && inter.ARREADY) |-> ##[1:3] inter.RVALID;
    endproperty
    A_RVALID_AFTER_ARADDR: assert property (rvalid_after_araddr) else $error("RVALID should be asserted within 1-3 cycles after read address handshake");

    // RDATA, RRESP, RID, RLAST must remain stable when RVALID is high and RREADY is low
    property rdata_stable_when_valid;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.RVALID && !inter.RREADY |=> $stable(inter.RDATA) && $stable(inter.RRESP) && $stable(inter.RID) && $stable(inter.RLAST);
    endproperty
    A_RDATA_STABLE_WHEN_VALID: assert property (rdata_stable_when_valid) else $error("RDATA/RRESP/RID/RLAST must remain stable when RVALID is high and RREADY is low");

    // RVALID should deassert after handshake
    property rvalid_deassert;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.RVALID && inter.RREADY) |=> !inter.RVALID;
    endproperty
    A_RVALID_DEASSERT: assert property (rvalid_deassert) else $error("RVALID should deassert after data handshake");

    // RRESP should be OKAY (00) or SLVERR (10)
    property rresp_valid_values;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        inter.RVALID |-> (inter.RRESP == 2'b00 || inter.RRESP == 2'b10);
    endproperty
    A_RRESP_VALID_VALUES: assert property (rresp_valid_values) else $error("Invalid RRESP value: %b", inter.RRESP);

    // --------------------------------------------------------------------------
    // AXI Protocol Specific Assertions (e.g., 4KB boundary, unaligned access)
    // --------------------------------------------------------------------------

    // 4KB boundary crossing for INCR/FIXED write bursts should result in SLVERR
    property write_4k_boundary_error;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.AWVALID && inter.AWREADY && (inter.AWBURST != 2'b10) && // Not WRAP
         (((inter.AWADDR & 12'hFFF) + ((inter.AWLEN + 1) * (1 << inter.AWSIZE))) > 12'h1000))
        |-> ##[1:$] (inter.BVALID && inter.BRESP == 2'b10);
    endproperty
    A_WRITE_4K_BOUNDARY_ERROR: assert property (write_4k_boundary_error) else $error("INCR/FIXED write burst crossing 4KB boundary should result in SLVERR");

    // WRAP write bursts must not cross 4KB boundary (master responsibility, but DUT should respond SLVERR if it does)
    property write_wrap_4k_boundary_violation;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.AWVALID && inter.AWREADY && (inter.AWBURST == 2'b10) &&
         (((inter.AWADDR & 12'hFFF) + ((inter.AWLEN + 1) * (1 << inter.AWSIZE))) > 12'h1000))
        |-> ##[1:$] (inter.BVALID && inter.BRESP == 2'b10);
    endproperty
    A_WRITE_WRAP_4K_BOUNDARY_VIOLATION: assert property (write_wrap_4k_boundary_violation) else $error("WRAP write burst crossing 4KB boundary should result in SLVERR");

    // Out of memory range for write should result in SLVERR
    property write_range_error;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.AWVALID && inter.AWREADY &&
         ((inter.AWADDR >> $clog2(DATA_WIDTH/8)) + inter.AWLEN >= MEMORY_DEPTH))
        |-> ##[1:$] (inter.BVALID && inter.BRESP == 2'b10);
    endproperty
    A_WRITE_RANGE_ERROR: assert property (write_range_error) else $error("Out of range write should result in SLVERR");

    // 4KB boundary crossing for INCR/FIXED read bursts should result in SLVERR
    property read_4k_boundary_error;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.ARVALID && inter.ARREADY && (inter.ARBURST != 2'b10) && // Not WRAP
         (((inter.ARADDR & 12'hFFF) + ((inter.ARLEN + 1) * (1 << inter.ARSIZE))) > 12'h1000))
        |-> ##[1:$] (inter.RVALID && inter.RRESP == 2'b10);
    endproperty
    A_READ_4K_BOUNDARY_ERROR: assert property (read_4k_boundary_error) else $error("INCR/FIXED read burst crossing 4KB boundary should result in SLVERR");

    // WRAP read bursts must not cross 4KB boundary (master responsibility, but DUT should respond SLVERR if it does)
    property read_wrap_4k_boundary_violation;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.ARVALID && inter.ARREADY && (inter.ARBURST == 2'b10) &&
         (((inter.ARADDR & 12'hFFF) + ((inter.ARLEN + 1) * (1 << inter.ARSIZE))) > 12'h1000))
        |-> ##[1:$] (inter.RVALID && inter.RRESP == 2'b10);
    endproperty
    A_READ_WRAP_4K_BOUNDARY_VIOLATION: assert property (read_wrap_4k_boundary_violation) else $error("WRAP read burst crossing 4KB boundary should result in SLVERR");

    // Out of memory range for read should result in SLVERR
    property read_range_error;
        @(posedge inter.ACLK) disable iff (!inter.ARESETn)
        (inter.ARVALID && inter.ARREADY &&
         ((inter.ARADDR >> $clog2(DATA_WIDTH/8)) + inter.ARLEN >= MEMORY_DEPTH))
        |-> ##[1:$] (inter.RVALID && inter.RRESP == 2'b10);
    endproperty
    A_READ_RANGE_ERROR: assert property (read_range_error) else $error("Out of range read should result in SLVERR");

endmodule
