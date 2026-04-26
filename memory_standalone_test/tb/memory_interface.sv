// =============================================================================
// Interface   : mem_if
// Description : Simple bus interface for the standalone axi4_memory testbench.
// =============================================================================

interface mem_if (input logic ACLK);

    logic        ARESETn;
    logic        mem_en;
    logic        mem_we;
    logic [9:0]  mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;

    modport dut_mp (
        input  ACLK, ARESETn,
        input  mem_en, mem_we, mem_addr, mem_wdata,
        output mem_rdata
    );

    modport tb_mp (
        input  ACLK,
        output ARESETn,
        output mem_en, mem_we, mem_addr, mem_wdata,
        input  mem_rdata
    );

    modport monitor_mp (
        input ACLK, ARESETn,
        input mem_en, mem_we, mem_addr, mem_wdata, mem_rdata
    );

endinterface
