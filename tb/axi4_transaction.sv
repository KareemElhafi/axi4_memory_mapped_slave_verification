class axi4_transaction;

    // Parameters (matching DUT)
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter MEMORY_DEPTH = 1024;
    parameter ID_WIDTH = 4;

    // AXI signals (driver outputs)
    randc bit [ID_WIDTH-1:0]      id;
    randc bit [ADDR_WIDTH-1:0]    addr;
    randc bit [7:0]               len;    // Burst length (beats - 1)
    randc bit [2:0]               size;   // Size of each transfer
    randc bit [1:0]               burst;  // Burst type (FIXED, INCR, WRAP)
    randc bit [DATA_WIDTH-1:0]    data;
    randc bit [DATA_WIDTH/8-1:0]  strb;   // Byte strobes
    randc bit [1:0]               operation; // 0: NOP, 1: WRITE, 2: READ

    // Delay injection for realism
    randc int aw_valid_delay;
    randc int w_valid_delay;
    randc int b_ready_delay;
    randc int ar_valid_delay;
    randc int r_ready_delay;

    // Constraints
    constraint c_len { len inside {[0:15]}; } // AXI4 max burst length is 16 (len=15)
    constraint c_size { size inside {[0:$clog2(DATA_WIDTH/8)]}; } // Size must be <= DATA_WIDTH
    constraint c_burst { burst inside {[0:2]}; } // 0: FIXED, 1: INCR, 2: WRAP

    // Address constraints
    constraint c_addr_aligned {
        (size == 0) -> (addr % 1 == 0); // Byte access, any address
        (size == 1) -> (addr % 2 == 0); // Half-word access, 2-byte aligned
        (size == 2) -> (addr % 4 == 0); // Word access, 4-byte aligned
        (size == 3) -> (addr % 8 == 0); // Double-word access, 8-byte aligned
        // Add more for larger DATA_WIDTH if needed
    }

    // Constraint for valid address range within memory depth
    constraint c_valid_addr_range {
        addr + ((len + 1) * (1 << size)) <= (MEMORY_DEPTH * (DATA_WIDTH/8)); // Ensure burst ends within memory byte addressable range
    }

    // Constraint for 4KB boundary crossing (WRAP bursts must not cross)
    constraint c_4k_boundary {
        (burst == 2) -> ((addr & 12'hFFF) + ((len + 1) * (1 << size)) <= 12'h1000); // WRAP bursts must not cross 4KB boundary
    }

    // Data constraints (example, can be expanded)
    constraint c_data_pattern {
        data inside {[0:100], [32'hFFFF_FFFF], [32'h0000_0000]};
    }

    // WSTRB constraints: all bytes valid for now, can be randomized later
    constraint c_strb { strb == (2**(DATA_WIDTH/8))-1; } // All bytes enabled

    // Delay constraints
    constraint c_delays { aw_valid_delay inside {[0:5]}; w_valid_delay inside {[0:5]}; b_ready_delay inside {[0:5]}; ar_valid_delay inside {[0:5]}; r_ready_delay inside {[0:5]}; }

    // Covergroup for functional coverage
    covergroup axi4_cov;
        option.per_instance = 1;
        addr_cp: coverpoint addr {
            bins low_addr = {[0:63]};
            bins mid_addr = {[64:511]};
            bins high_addr = {[512:MEMORY_DEPTH*(DATA_WIDTH/8)-1]};
            bins unaligned_addr = {addr with (addr % 4 != 0)}; // Example for unaligned
        }
        len_cp: coverpoint len {
            bins single = {0};
            bins small_burst = {[1:7]};
            bins max_burst = {15};
        }
        size_cp: coverpoint size {
            bins byte_size = {0};
            bins half_word_size = {1};
            bins word_size = {2};
        }
        burst_cp: coverpoint burst {
            bins fixed_burst = {0};
            bins incr_burst = {1};
            bins wrap_burst = {2};
        }
        operation_cp: coverpoint operation {
            bins write_op = {1};
            bins read_op = {2};
        }
        // Cross coverage for key interactions
        cross addr_cp, len_cp, size_cp, operation_cp;
        cross burst_cp, len_cp;
        cross addr_cp, burst_cp;

    endgroup

    function new();
        axi4_cov = new();
    endfunction

    function void display(string name = "");
        $display("[%0t] %s Transaction: ID=%0h, Addr=%0h, Len=%0d, Size=%0d, Burst=%0d, Op=%0d",
                 $time, name, id, addr, len, size, burst, operation);
    endfunction

endclass
