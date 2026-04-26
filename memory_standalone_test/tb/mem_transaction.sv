// =============================================================================
// Class       : mem_transaction
// Description : Randomisable stimulus for the standalone memory testbench.
//               Covers address corners, data distributions, and enable/write
//               enable control.
// =============================================================================

`ifndef MEM_TRANSACTION_SV
`define MEM_TRANSACTION_SV

class mem_transaction;

    rand logic        mem_en;
    rand logic        mem_we;
    rand logic [9:0]  mem_addr;
    rand logic [31:0] mem_wdata;

    // Enable: mostly active
    constraint c_en { mem_en dist {0 := 1, 1 := 9}; }

    // Write-enable only when enabled
    constraint c_we {
        if (mem_en) mem_we dist {0 := 6, 1 := 4};
        else        mem_we == 1'b0;
    }

    // --- Address range constraints (enable one at a time) ---
    constraint c_addr_range {
        mem_addr inside {[10'd0 : 10'd1023]};
    }

    constraint c_addr_corners {
        mem_addr inside {
            10'd0,    10'd1,    10'd7,    10'd15,
            10'd31,   10'd63,   10'd127,  10'd255,
            10'd511,  10'd1023,
            10'b1010101010, 10'b0101010101,
            10'b1111111111, 10'b1111100000,
            10'b0000011111
        };
    }

    // --- Data distribution constraints (enable one at a time) ---
    constraint c_data_lo {
        mem_wdata inside {[32'd0 : 32'd65535]};
    }

    constraint c_data_mid {
        mem_wdata inside {[32'd65536 : 32'd1048575]};
    }

    constraint c_data_hi {
        mem_wdata inside {[32'd1048576 : 32'hFFFF_FFFF]};
    }

    constraint c_data_corners {
        mem_wdata inside {
            32'd0,          32'd1,
            32'hFFFF_FFFF,  32'hAAAA_AAAA,
            32'h5555_5555,  32'hDEAD_BEEF,
            32'h1111_0000,  32'h0000_1111
        };
    }

    // -------------------------------------------------------------------------
    // Coverage
    // -------------------------------------------------------------------------
    covergroup mem_cov;
        option.per_instance = 1;

        cp_en: coverpoint mem_en {
            bins disabled = {0};
            bins enabled  = {1};
        }

        cp_we: coverpoint mem_we iff (mem_en) {
            bins read_op  = {0};
            bins write_op = {1};
        }

        cp_addr: coverpoint mem_addr iff (mem_en) {
            bins corners[] = {
                10'd0, 10'd1, 10'd7, 10'd15, 10'd31,
                10'd63, 10'd127, 10'd255, 10'd511, 10'd1023,
                10'b1010101010, 10'b0101010101, 10'b1111111111,
                10'b1111100000, 10'b0000011111
            };
            bins range_lo  = {[10'd0   : 10'd255]};
            bins range_mid = {[10'd256 : 10'd767]};
            bins range_hi  = {[10'd768 : 10'd1023]};
        }

        cp_wdata: coverpoint mem_wdata iff (mem_en && mem_we) {
            bins corners[] = {
                32'd0, 32'd1, 32'hFFFF_FFFF, 32'hAAAA_AAAA,
                32'h5555_5555, 32'hDEAD_BEEF
            };
            bins grp_lo  = {[32'd0          : 32'd65535]};
            bins grp_mid = {[32'd65536      : 32'd1048575]};
            bins grp_hi  = {[32'd1048576    : 32'hFFFF_FFFF]};
        }

        cx_we_addr: cross cp_we, cp_addr;

    endgroup

    function new();
        mem_cov = new();
    endfunction

    function void display(string prefix = "");
        $display("%s[MEM] en=%b we=%b addr=0x%03h wdata=0x%08h",
                 prefix, mem_en, mem_we, mem_addr, mem_wdata);
    endfunction

endclass

`endif // MEM_TRANSACTION_SV
