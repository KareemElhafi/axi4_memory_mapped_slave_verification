// =============================================================================
// File        : axi4_sequencer.sv
// =============================================================================

class axi4_sequencer;

    // Mailbox for communication with the driver
    mailbox #(axi4_transaction) mbx_sequencer_to_driver;

    // Configuration parameters
    int num_transactions = 100;    // Total number of transactions to generate
    int read_weight      = 50;     // Percentage weight for read transactions (0-100)
    int write_weight     = 50;     // Percentage weight for write transactions (0-100)
    int inter_transaction_delay = 0; // Cycles delay between transactions

    // Directed scenario control
    int wr_rd_pair_interval = 10;  // Generate a WR-RD pair every N random transactions
    int boundary_case_interval = 20; // Generate a boundary case every N random transactions
    int error_case_interval = 30;  // Generate an error case every N random transactions

    // Internal state for directed scenarios
    int transaction_count = 0;

    // =========================================================================
    // Constructor
    // =========================================================================
    function new(mailbox #(axi4_transaction) mbx_sequencer_to_driver);
        this.mbx_sequencer_to_driver = mbx_sequencer_to_driver;

        // Basic validation for weights
        if (read_weight + write_weight != 100) begin
            $error("[%0t] Sequencer: Read and Write weights must sum to 100!", $time);
            read_weight = 50; write_weight = 50; // Default to 50/50
        end
    endfunction

    // =========================================================================
    // Main run task: Generates and sends transactions
    // =========================================================================
    task run();
        axi4_transaction tr;

        $display("[%0t] Sequencer: Starting to generate %0d transactions...", $time, num_transactions);

        for (int i = 0; i < num_transactions; i++) begin
            transaction_count++;
            $display("[%0t] Sequencer: Generating transaction %0d/%0d", $time, i+1, num_transactions);

            // Prioritize directed scenarios
            if (wr_rd_pair_interval > 0 && (transaction_count % wr_rd_pair_interval == 0)) begin
                generate_directed_wr_rd_pair();
            end else if (boundary_case_interval > 0 && (transaction_count % boundary_case_interval == 0)) begin
                tr = generate_boundary_transaction();
                if (tr != null) send_transaction(tr);
            end else if (error_case_interval > 0 && (transaction_count % error_case_interval == 0)) begin
                tr = generate_error_transaction();
                if (tr != null) send_transaction(tr);
            end else begin
                // Generate a random transaction
                tr = generate_random_transaction();
                if (tr != null) send_transaction(tr);
            end

            // Optional delay between transactions
            if (inter_transaction_delay > 0) begin
                #inter_transaction_delay;
            end
        end

        $display("[%0t] Sequencer: Finished generating %0d transactions.", $time, num_transactions);
    endtask

    // =========================================================================
    // Helper task: Sends a transaction to the driver
    // =========================================================================
    task send_transaction(axi4_transaction tr);
        if (tr == null) begin
            $error("[%0t] Sequencer: Attempted to send a null transaction.", $time);
            return;
        end
        mbx_sequencer_to_driver.put(tr);
        tr.display("Sequencer Sent");
    endtask

    // =========================================================================
    // Helper task: Generates a single random AXI4 transaction
    // =========================================================================
    function axi4_transaction generate_random_transaction();
        axi4_transaction tr = new();

        // Randomize operation based on weights
        if ($urandom_range(1, 100) <= read_weight) begin
            tr.operation = tr.AXI_READ;
        end else begin
            tr.operation = tr.AXI_WRITE;
        end

        // Randomize all other fields according to constraints
        if (!tr.randomize()) begin
            $fatal(1, "[%0t] Sequencer: Randomization failed for transaction!", $time);
            return null;
        end
        return tr;
    endfunction

    // =========================================================================
    // Helper task: Generates a directed Write-then-Read pair
    // =========================================================================
    task generate_directed_wr_rd_pair();
        axi4_transaction wr_tr = new();
        axi4_transaction rd_tr = new();
        logic [wr_tr.DATA_WIDTH-1:0] test_data;

        // --- Generate Write Transaction ---
        wr_tr.operation = wr_tr.AXI_WRITE;
        // Ensure it's a valid, in-range transaction for data integrity check
        if (!wr_tr.randomize() with {
            wr_tr.addr + ((wr_tr.len + 1) * (1 << wr_tr.size)) <= (wr_tr.MEMORY_DEPTH * (wr_tr.DATA_WIDTH/8));
            (wr_tr.burst == wr_tr.AXI_WRAP) -> ((wr_tr.addr & 12'hFFF) + ((wr_tr.len + 1) * (1 << wr_tr.size)) <= 12'h1000);
        }) begin
            $fatal(1, "[%0t] Sequencer: Randomization failed for directed WR transaction!", $time);
            return;
        end

        // Use a specific data pattern for easy verification
        test_data = $urandom();
        wr_tr.data = test_data;
        // For simplicity, we'll assume a single beat write for this directed test
        // In a real scenario, you'd fill write_data_q for burst writes
        wr_tr.write_data_q.delete();
        wr_tr.write_data_q.push_back(test_data);

        $display("[%0t] Sequencer: Directed WR-RD Pair - Sending WRITE transaction...", $time);
        send_transaction(wr_tr);

        // Optional delay between write and read
        if (inter_transaction_delay > 0) #inter_transaction_delay;

        // --- Generate Read Transaction ---
        rd_tr.operation = rd_tr.AXI_READ;
        // Match address, length, size, burst from the write transaction
        rd_tr.addr  = wr_tr.addr;
        rd_tr.len   = wr_tr.len;
        rd_tr.size  = wr_tr.size;
        rd_tr.burst = wr_tr.burst;

        // Randomize only delays for the read transaction
        if (!rd_tr.randomize() with {
            aw_valid_delay == $urandom_range(0,5);
            w_valid_delay == $urandom_range(0,5);
            b_ready_delay == $urandom_range(0,5);
            ar_valid_delay == $urandom_range(0,5);
            r_ready_delay == $urandom_range(0,5);
        }) begin
            $fatal(1, "[%0t] Sequencer: Randomization failed for directed RD transaction delays!", $time);
            return;
        end

        $display("[%0t] Sequencer: Directed WR-RD Pair - Sending READ transaction...", $time);
        send_transaction(rd_tr);
    endtask

    // =========================================================================
    // Helper function: Generates a transaction targeting boundary conditions
    // =========================================================================
    function axi4_transaction generate_boundary_transaction();
        axi4_transaction tr = new();
        int boundary_type = $urandom_range(0, 3); // 0: start, 1: end, 2: 4KB cross, 3: 4KB align

        tr.operation = ($urandom_range(0,1) == 0) ? tr.AXI_READ : tr.AXI_WRITE;

        case (boundary_type)
            0: begin // Start of memory
                if (!tr.randomize() with { tr.addr == 0; tr.len == 0; }) begin
                    $error("[%0t] Sequencer: Failed to randomize start-of-memory transaction.", $time);
                    return null;
                end
                $display("[%0t] Sequencer: Generating boundary transaction: Start of memory.", $time);
            end
            1: begin // End of memory
                if (!tr.randomize() with { tr.addr + ((tr.len + 1) * (1 << tr.size)) == (tr.MEMORY_DEPTH * (tr.DATA_WIDTH/8)); }) begin
                    $error("[%0t] Sequencer: Failed to randomize end-of-memory transaction.", $time);
                    return null;
                end
                $display("[%0t] Sequencer: Generating boundary transaction: End of memory.", $time);
            end
            2: begin // 4KB boundary crossing (for INCR/FIXED bursts)
                // Force an address that crosses a 4KB boundary
                if (!tr.randomize() with {
                    tr.burst != tr.AXI_WRAP; // WRAP bursts cannot cross
                    tr.addr inside { [16'h0FF0 : 16'h0FFF] }; // Address near 4KB boundary
                    tr.addr + ((tr.len + 1) * (1 << tr.size)) > 16'h1000; // Ensure it crosses
                }) begin
                    $error("[%0t] Sequencer: Failed to randomize 4KB crossing transaction.", $time);
                    return null;
                end
                $display("[%0t] Sequencer: Generating boundary transaction: 4KB crossing.", $time);
            end
            3: begin // 4KB boundary aligned (for WRAP bursts)
                if (!tr.randomize() with {
                    tr.burst == tr.AXI_WRAP;
                    tr.addr == 16'h1000; // Aligned to 4KB boundary
                    tr.len == 15; // Max length
                }) begin
                    $error("[%0t] Sequencer: Failed to randomize 4KB aligned WRAP transaction.", $time);
                    return null;
                end
                $display("[%0t] Sequencer: Generating boundary transaction: 4KB aligned WRAP.", $time);
            end
        endcase
        return tr;
    endfunction

    // =========================================================================
    // Helper function: Generates a transaction that should result in an error
    // =========================================================================
    function axi4_transaction generate_error_transaction();
        axi4_transaction tr = new();
        int error_type = $urandom_range(0, 1); // 0: out-of-range, 1: WRAP crossing 4KB

        tr.operation = ($urandom_range(0,1) == 0) ? tr.AXI_READ : tr.AXI_WRITE;

        case (error_type)
            0: begin // Out-of-range address
                if (!tr.randomize() with {
                    tr.addr + ((tr.len + 1) * (1 << tr.size)) > (tr.MEMORY_DEPTH * (tr.DATA_WIDTH/8));
                }) begin
                    $error("[%0t] Sequencer: Failed to randomize out-of-range error transaction.", $time);
                    return null;
                }
                $display("[%0t] Sequencer: Generating error transaction: Out-of-range address.", $time);
            end
            1: begin // WRAP burst crossing 4KB boundary
                if (!tr.randomize() with {
                    tr.burst == tr.AXI_WRAP;
                    tr.addr inside { [16'h0FF0 : 16'h0FFF] }; // Address near 4KB boundary
                    tr.addr + ((tr.len + 1) * (1 << tr.size)) > 16'h1000; // Ensure it crosses
                }) begin
                    $error("[%0t] Sequencer: Failed to randomize WRAP 4KB crossing error transaction.", $time);
                    return null;
                }
                $display("[%0t] Sequencer: Generating error transaction: WRAP crossing 4KB boundary.", $time);
            end
        endcase
        return tr;
    endfunction

endclass
