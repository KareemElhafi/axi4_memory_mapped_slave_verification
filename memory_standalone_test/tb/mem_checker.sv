// =============================================================================
// Module      : mem_checker
// Description : Concurrent assertions for axi4_memory.
//               Replaces the trivially-true property 5 from the original
//               mem_assert.sv with a meaningful stable-address-during-write
//               check.
// =============================================================================

`timescale 1ns/1ps

module mem_checker (
    mem_if.monitor_mp mem
);

    // Property 1: mem_we can only be 1 when mem_en is 1
    property p_we_requires_en;
        @(posedge mem.ACLK) disable iff (!mem.ARESETn)
        mem.mem_we |-> mem.mem_en;
    endproperty
    A_WE_REQUIRES_EN: assert property (p_we_requires_en)
        else $error("[MEM] mem_we asserted without mem_en");
    C_WE_REQUIRES_EN: cover property (p_we_requires_en);

    // Property 2: After a read, mem_rdata must not be X
    property p_rdata_known_after_read;
        @(posedge mem.ACLK) disable iff (!mem.ARESETn)
        (mem.mem_en && !mem.mem_we) |=> !$isunknown(mem.mem_rdata);
    endproperty
    A_RDATA_KNOWN: assert property (p_rdata_known_after_read)
        else $error("[MEM] mem_rdata is X after a read");
    C_RDATA_KNOWN: cover property (p_rdata_known_after_read);

    // Property 3: mem_we must be 0 when mem_en is 0
    property p_we_low_when_disabled;
        @(posedge mem.ACLK) disable iff (!mem.ARESETn)
        !mem.mem_en |-> !mem.mem_we;
    endproperty
    A_WE_LOW_DISABLED: assert property (p_we_low_when_disabled)
        else $error("[MEM] mem_we high when mem_en low");
    C_WE_LOW_DISABLED: cover property (p_we_low_when_disabled);

    // Property 4: Reset clears mem_rdata
    property p_reset_rdata;
        @(posedge mem.ACLK)
        $fell(mem.ARESETn) |=> (mem.mem_rdata == '0);
    endproperty
    A_RESET_RDATA: assert property (p_reset_rdata)
        else $error("[MEM] mem_rdata not 0 after reset");
    C_RESET_RDATA: cover property (p_reset_rdata);

    // Property 5 (improved): Address must be within valid range when enabled
    property p_valid_address;
        @(posedge mem.ACLK) disable iff (!mem.ARESETn)
        mem.mem_en |-> (mem.mem_addr < 10'd1024);
    endproperty
    A_VALID_ADDRESS: assert property (p_valid_address)
        else $error("[MEM] mem_addr out of range: %0d", mem.mem_addr);
    C_VALID_ADDRESS: cover property (p_valid_address);

    // Property 6: Address must be stable from the write enable to the next cycle
    property p_addr_stable_during_write;
        @(posedge mem.ACLK) disable iff (!mem.ARESETn)
        (mem.mem_en && mem.mem_we) |=> $stable(mem.mem_addr) || !mem.mem_en;
    endproperty
    A_ADDR_STABLE_WRITE: assert property (p_addr_stable_during_write)
        else $error("[MEM] mem_addr changed during a write");
    C_ADDR_STABLE_WRITE: cover property (p_addr_stable_during_write);

endmodule
