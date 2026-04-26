// =============================================================================
// Module      : mem_tb_top
// Description : Standalone testbench for axi4_memory.
//               Exercises all address corners and data distributions with
//               a golden reference model and per-transaction checking.
// =============================================================================

`timescale 1ns/1ps

`include "mem_transaction.sv"

module mem_tb_top;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int CLK_PERIOD_NS = 10;
    localparam int MEM_DEPTH     = 1024;
    localparam int REPS_PER_PHASE = 10_000;

    // =========================================================================
    // Clock
    // =========================================================================
    logic ACLK = 1'b0;
    always #(CLK_PERIOD_NS / 2) ACLK = ~ACLK;

    // =========================================================================
    // Interface, DUT, checker
    // =========================================================================
    mem_if mem (.ACLK(ACLK));

    axi4_memory #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (10),
        .DEPTH      (MEM_DEPTH)
    ) u_dut (
        .clk      (mem.ACLK),
        .rst_n    (mem.ARESETn),
        .mem_en   (mem.mem_en),
        .mem_we   (mem.mem_we),
        .mem_addr (mem.mem_addr),
        .mem_wdata(mem.mem_wdata),
        .mem_rdata(mem.mem_rdata)
    );

    mem_checker u_checker (.mem(mem.monitor_mp));

    // =========================================================================
    // Verification objects
    // =========================================================================
    mem_transaction txn;

    logic [31:0] golden_mem [0:MEM_DEPTH-1];
    logic [31:0] actual_data;
    logic [31:0] expected_data;

    int tests_run  = 0;
    int tests_pass = 0;
    int tests_fail = 0;

    // =========================================================================
    // Tasks
    // =========================================================================

    task automatic apply_reset();
        mem.ARESETn  = 1'b0;
        mem.mem_en   = 1'b0;
        mem.mem_we   = 1'b0;
        mem.mem_addr = '0;
        mem.mem_wdata = '0;
        repeat (4) @(posedge ACLK);
        mem.ARESETn = 1'b1;
        repeat (2) @(posedge ACLK);
    endtask

    task automatic run_transaction();
        assert(txn.randomize()) else begin
            $error("[MEM_TB] randomize() failed at test %0d", tests_run);
            return;
        end

        // --- Drive ---
        mem.mem_en   = txn.mem_en;
        mem.mem_we   = txn.mem_we;
        mem.mem_addr = txn.mem_addr;
        mem.mem_wdata = txn.mem_wdata;
        txn.mem_cov.sample();
        @(posedge ACLK);

        // --- Golden model ---
        if (txn.mem_en) begin
            if (txn.mem_we) begin
                golden_mem[txn.mem_addr] = txn.mem_wdata;
                // No read check on write cycles
                mem.mem_en = 1'b0;
                mem.mem_we = 1'b0;
                return;
            end else begin
                expected_data = golden_mem[txn.mem_addr];
            end
        end else begin
            // Memory disabled: no check
            mem.mem_en = 1'b0;
            mem.mem_we = 1'b0;
            return;
        end

        // --- Collect read result (1-cycle latency) ---
        @(posedge ACLK);
        actual_data = mem.mem_rdata;
        mem.mem_en  = 1'b0;
        mem.mem_we  = 1'b0;

        // --- Check ---
        tests_run++;
        if (actual_data !== expected_data) begin
            tests_fail++;
            $error("[FAIL] #%04d addr=0x%03h exp=0x%08h got=0x%08h",
                   tests_run, txn.mem_addr, expected_data, actual_data);
        end else begin
            tests_pass++;
            $display("[PASS] #%04d addr=0x%03h data=0x%08h",
                     tests_run, txn.mem_addr, actual_data);
        end
    endtask

    // =========================================================================
    // Main
    // =========================================================================
    initial begin
        txn = new();
        for (int i = 0; i < MEM_DEPTH; i++) golden_mem[i] = 32'h0;

        apply_reset();

        // Phase 1: range addresses, data_lo
        txn.c_addr_range.constraint_mode(1);
        txn.c_addr_corners.constraint_mode(0);
        txn.c_data_lo.constraint_mode(1);
        txn.c_data_mid.constraint_mode(0);
        txn.c_data_hi.constraint_mode(0);
        txn.c_data_corners.constraint_mode(0);
        repeat (REPS_PER_PHASE) run_transaction();

        // Phase 2: range addresses, data_mid
        txn.c_data_lo.constraint_mode(0);
        txn.c_data_mid.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        // Phase 3: range addresses, data_hi
        txn.c_data_mid.constraint_mode(0);
        txn.c_data_hi.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        // Phase 4: range addresses, data corners
        txn.c_data_hi.constraint_mode(0);
        txn.c_data_corners.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        // Phase 5: corner addresses, all data distributions
        txn.c_addr_range.constraint_mode(0);
        txn.c_addr_corners.constraint_mode(1);
        txn.c_data_corners.constraint_mode(0);
        txn.c_data_lo.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        txn.c_data_lo.constraint_mode(0);
        txn.c_data_mid.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        txn.c_data_mid.constraint_mode(0);
        txn.c_data_hi.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        txn.c_data_hi.constraint_mode(0);
        txn.c_data_corners.constraint_mode(1);
        repeat (REPS_PER_PHASE) run_transaction();

        // Report
        $display("");
        $display("========================================");
        $display("  Memory TB Summary");
        $display("  Tests : %0d", tests_run);
        $display("  Pass  : %0d", tests_pass);
        $display("  Fail  : %0d", tests_fail);
        $display("  Coverage: %0.2f%%", txn.mem_cov.get_coverage());
        $display("========================================");

        #(CLK_PERIOD_NS * 10);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #(CLK_PERIOD_NS * 5_000_000);
        $fatal(0, "[MEM_TB] Simulation timeout");
    end

endmodule
