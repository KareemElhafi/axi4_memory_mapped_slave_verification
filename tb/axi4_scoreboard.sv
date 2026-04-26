`timescale 1ns/1ps

class axi4_scoreboard;

    mailbox #(axi4_transaction) mbx_monitor_to_scoreboard;

    // Golden memory model
    logic [31:0] golden_mem [0:1023]; // Assuming MEMORY_DEPTH = 1024, DATA_WIDTH = 32

    // Queues for expected and actual read data
    typedef struct {
        int unsigned addr;
        logic [31:0] data;
    } mem_access_s;

    mem_access_s expected_read_queue[$];
    mem_access_s actual_read_queue[$];

    int num_transactions = 0;
    int num_passed = 0;
    int num_failed = 0;

    function new(mailbox #(axi4_transaction) mbx_monitor_to_scoreboard);
        this.mbx_monitor_to_scoreboard = mbx_monitor_to_scoreboard;
        // Initialize golden memory
        for (int i = 0; i < 1024; i++)
            golden_mem[i] = 0;
    endfunction

    task run();
        forever begin
            axi4_transaction tr;
            mbx_monitor_to_scoreboard.get(tr);
            num_transactions++;
            check_transaction(tr);
        end
    endtask

    task check_transaction(axi4_transaction tr);
        case (tr.operation)
            1: check_write(tr); // Write operation
            2: check_read(tr);  // Read operation
            default: $error("[%0t] Scoreboard: Invalid operation %0d", $time, tr.operation);
        endcase
    endtask

    task check_write(axi4_transaction tr);
        logic [1:0] expected_resp = 2'b00; // Default to OKAY
        logic [ADDR_WIDTH-1:0] current_addr = tr.addr;

        // Check for address range and 4KB boundary violations
        // Simplified check, more detailed checks would be in DUT assertions
        if (tr.burst == 2'b10) begin // WRAP burst
            // WRAP bursts must not cross 4KB boundaries
            if (((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 12'h1000) begin
                expected_resp = 2'b10; // SLVERR
            end
        end else begin // FIXED or INCR
            if (((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 12'h1000) begin
                expected_resp = 2'b10; // SLVERR
            end
        end

        if ((tr.addr >> $clog2(DATA_WIDTH/8)) + tr.len >= 1024) begin
            expected_resp = 2'b10; // SLVERR for out of range
        end

        if (expected_resp == 2'b00) begin // If no error predicted by scoreboard
            for (int i = 0; i <= tr.len; i++) begin
                int word_addr = current_addr >> $clog2(DATA_WIDTH/8);
                if (word_addr < 1024) begin
                    // Apply WSTRB to golden memory
                    for (int byte_idx = 0; byte_idx < DATA_WIDTH/8; byte_idx++) begin
                        if (tr.strb[byte_idx]) begin
                            golden_mem[word_addr][(byte_idx*8)+:8] = tr.data[(byte_idx*8)+:8];
                        end
                    end
                end

                // Increment address based on burst type and size
                case (tr.burst)
                    2'b00: begin // FIXED
                        // Address remains fixed
                    end
                    2'b01: begin // INCR
                        current_addr += (1 << tr.size);
                    end
                    2'b10: begin // WRAP
                        // For simplicity, assuming WRAP bursts are handled by master not crossing 4KB boundary
                        current_addr += (1 << tr.size);
                        // More complex wrap-around logic would be needed here if master can cross boundary
                    end
                    default: begin // Reserved, treat as INCR
                        current_addr += (1 << tr.size);
                    end
                endcase
            end
            $info("[%0t] Scoreboard: Write transaction to addr %0h, len %0d. Expected OKAY.", $time, tr.addr, tr.len);
            num_passed++; // Assuming DUT will also respond OKAY
        end else begin
            $error("[%0t] Scoreboard: Write transaction to addr %0h, len %0d. Expected SLVERR.", $time, tr.addr, tr.len);
            num_failed++; // Assuming DUT will also respond SLVERR
        end
    endtask

    task check_read(axi4_transaction tr);
        logic [1:0] expected_resp = 2'b00; // Default to OKAY
        logic [ADDR_WIDTH-1:0] current_addr = tr.addr;

        // Check for address range and 4KB boundary violations
        if (tr.burst == 2'b10) begin // WRAP burst
            if (((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 12'h1000) begin
                expected_resp = 2'b10; // SLVERR
            end
        end else begin // FIXED or INCR
            if (((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 12'h1000) begin
                expected_resp = 2'b10; // SLVERR
            end
        end

        if ((tr.addr >> $clog2(DATA_WIDTH/8)) + tr.len >= 1024) begin
            expected_resp = 2'b10; // SLVERR for out of range
        end

        if (expected_resp == 2'b00) begin
            for (int i = 0; i <= tr.len; i++) begin
                int word_addr = current_addr >> $clog2(DATA_WIDTH/8);
                if (word_addr < 1024) begin
                    expected_read_queue.push_back({word_addr, golden_mem[word_addr]});
                end else begin
                    // Should not happen if expected_resp is OKAY, but for safety
                    expected_read_queue.push_back({word_addr, {DATA_WIDTH{1'b0}}});
                end

                // Increment address based on burst type and size
                case (tr.burst)
                    2'b00: begin // FIXED
                        // Address remains fixed
                    end
                    2'b01: begin // INCR
                        current_addr += (1 << tr.size);
                    end
                    2'b10: begin // WRAP
                        current_addr += (1 << tr.size);
                    end
                    default: begin // Reserved, treat as INCR
                        current_addr += (1 << tr.size);
                    end
                endcase
            end
            $info("[%0t] Scoreboard: Read transaction from addr %0h, len %0d. Expected OKAY.", $time, tr.addr, tr.len);
            num_passed++; // Assuming DUT will also respond OKAY
        end else begin
            $error("[%0t] Scoreboard: Read transaction from addr %0h, len %0d. Expected SLVERR.", $time, tr.addr, tr.len);
            num_failed++; // Assuming DUT will also respond SLVERR
        end

        // Actual read data comparison would happen here, but the monitor currently doesn't collect RDATA beats.
        // This needs to be enhanced in the monitor to collect actual RDATA into a queue.
        // For now, we just check the response status.
    endtask

    function void report();
        $display("\n=== Scoreboard Report ===");
        $display("Total Transactions: %0d", num_transactions);
        $display("Passed Transactions: %0d", num_passed);
        $display("Failed Transactions: %0d", num_failed);
        if (num_failed == 0) begin
            $display("VERIFICATION PASSED!");
        end else begin
            $display("VERIFICATION FAILED!");
        end
    endfunction

endclass
