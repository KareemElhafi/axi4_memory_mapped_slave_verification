module axi4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter MEMORY_DEPTH = 1024,
    parameter ID_WIDTH = 0 // AXI ID width, 0 if not used
)(
    input  wire                     ACLK,
    input  wire                     ARESETn,

    // Write address channel
    input  wire [ID_WIDTH-1:0]      AWID,
    input  wire [ADDR_WIDTH-1:0]    AWADDR,
    input  wire [7:0]               AWLEN,
    input  wire [2:0]               AWSIZE,
    input  wire [1:0]               AWBURST,
    input  wire                     AWVALID,
    output reg                      AWREADY,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]    WDATA,
    input  wire [DATA_WIDTH/8-1:0]  WSTRB,
    input  wire                     WVALID,
    input  wire                     WLAST,
    output reg                      WREADY,

    // Write response channel
    output reg [ID_WIDTH-1:0]      BID,
    output reg [1:0]                BRESP,
    output reg                      BVALID,
    input  wire                     BREADY,

    // Read address channel
    input  wire [ID_WIDTH-1:0]      ARID,
    input  wire [ADDR_WIDTH-1:0]    ARADDR,
    input  wire [7:0]               ARLEN,
    input  wire [2:0]               ARSIZE,
    input  wire [1:0]               ARBURST,
    input  wire                     ARVALID,
    output reg                      ARREADY,

    // Read data channel
    output reg [ID_WIDTH-1:0]      RID,
    output reg [DATA_WIDTH-1:0]    RDATA,
    output reg [1:0]                RRESP,
    output reg                      RVALID,
    output reg                      RLAST,
    input  wire                     RREADY
);

    // Internal memory signals
    reg mem_en, mem_we;
    reg [$clog2(MEMORY_DEPTH)-1:0] mem_addr;
    reg [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;

    // Registered memory read data for pipelining
    reg [DATA_WIDTH-1:0] mem_rdata_pipeline;

    // Address and burst management for write channel
    reg [ID_WIDTH-1:0]  write_id_reg;
    reg [ADDR_WIDTH-1:0] write_addr_reg;
    reg [7:0]           write_len_reg;
    reg [2:0]           write_size_reg;
    reg [1:0]           write_burst_reg;
    reg [7:0]           write_beat_count;
    reg [ADDR_WIDTH-1:0] current_write_addr;

    // Address and burst management for read channel
    reg [ID_WIDTH-1:0]  read_id_reg;
    reg [ADDR_WIDTH-1:0] read_addr_reg;
    reg [7:0]           read_len_reg;
    reg [2:0]           read_size_reg;
    reg [1:0]           read_burst_reg;
    reg [7:0]           read_beat_count;
    reg [ADDR_WIDTH-1:0] current_read_addr;

    // Calculated burst increment
    wire [ADDR_WIDTH-1:0] burst_byte_size = (1 << write_size_reg);
    wire [ADDR_WIDTH-1:0] read_burst_byte_size = (1 << read_size_reg);

    // AXI response signals
    reg [1:0] write_resp_status;
    reg [1:0] read_resp_status;

    // FSM states
    reg [2:0] write_state;
    localparam W_IDLE = 3'd0,
               W_ADDR = 3'd1,
               W_DATA = 3'd2,
               W_RESP = 3'd3;

    reg [2:0] read_state;
    localparam R_IDLE = 3'd0,
               R_ADDR = 3'd1,
               R_DATA = 3'd2,
               R_LAST = 3'd3; // Added for pipelined read data

    // AXI Address boundary checks (4KB boundary = 12 bits)
    // Note: AXI spec states that 4KB boundary crossing is only relevant for FIXED and INCR bursts.
    // WRAP bursts must not cross 4KB boundaries.
    wire write_4k_boundary_cross = (write_burst_reg != 2'b01) && // Not WRAP
                                   (((write_addr_reg & 12'hFFF) + ((write_len_reg + 1) * burst_byte_size)) > 12'hFFF);
    wire read_4k_boundary_cross  = (read_burst_reg != 2'b01) && // Not WRAP
                                   (((read_addr_reg & 12'hFFF) + ((read_len_reg + 1) * read_burst_byte_size)) > 12'hFFF);

    // Address range check (word-aligned memory)
    wire write_addr_in_range = (current_write_addr >> ($clog2(DATA_WIDTH/8))) < MEMORY_DEPTH;
    wire read_addr_in_range  = (current_read_addr >> ($clog2(DATA_WIDTH/8))) < MEMORY_DEPTH;

    // Instantiate the memory
    axi4_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH($clog2(MEMORY_DEPTH)),
        .DEPTH(MEMORY_DEPTH)
    ) mem_inst (
        .clk(ACLK),
        .rst_n(ARESETn),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata)
    );

    // Pipelined memory read data
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            mem_rdata_pipeline <= {DATA_WIDTH{1'b0}};
        end else begin
            mem_rdata_pipeline <= mem_rdata;
        end
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            // Reset all outputs
            AWREADY <= 1'b1;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00;
            BID     <= {ID_WIDTH{1'b0}};

            ARREADY <= 1'b1;
            RVALID  <= 1'b0;
            RRESP   <= 2'b00;
            RDATA   <= {DATA_WIDTH{1'b0}};
            RLAST   <= 1'b0;
            RID     <= {ID_WIDTH{1'b0}};

            // Reset internal state
            write_state <= W_IDLE;
            read_state  <= R_IDLE;

            mem_en      <= 1'b0;
            mem_we      <= 1'b0;
            mem_addr    <= {$clog2(MEMORY_DEPTH){1'b0}};
            mem_wdata   <= {DATA_WIDTH{1'b0}};

            write_id_reg        <= {ID_WIDTH{1'b0}};
            write_addr_reg      <= {ADDR_WIDTH{1'b0}};
            write_len_reg       <= 8'b0;
            write_size_reg      <= 3'b0;
            write_burst_reg     <= 2'b00;
            write_beat_count    <= 8'b0;
            current_write_addr  <= {ADDR_WIDTH{1'b0}};
            write_resp_status   <= 2'b00;

            read_id_reg         <= {ID_WIDTH{1'b0}};
            read_addr_reg       <= {ADDR_WIDTH{1'b0}};
            read_len_reg        <= 8'b0;
            read_size_reg       <= 3'b0;
            read_burst_reg      <= 2'b00;
            read_beat_count     <= 8'b0;
            current_read_addr   <= {ADDR_WIDTH{1'b0}};
            read_resp_status    <= 2'b00;

        end else begin
            // Default disables
            mem_en <= 1'b0;
            mem_we <= 1'b0;

            // ------------------------------------
            // Write Channel FSM
            // ------------------------------------
            case (write_state)
                W_IDLE: begin
                    AWREADY <= 1'b1;
                    WREADY  <= 1'b0;
                    BVALID  <= 1'b0;
                    BRESP   <= 2'b00;
                    BID     <= {ID_WIDTH{1'b0}};

                    if (AWVALID && AWREADY) begin
                        write_id_reg        <= AWID;
                        write_addr_reg      <= AWADDR;
                        write_len_reg       <= AWLEN;
                        write_size_reg      <= AWSIZE;
                        write_burst_reg     <= AWBURST;
                        write_beat_count    <= AWLEN;
                        current_write_addr  <= AWADDR;

                        // Determine initial response status based on address phase
                        if (!write_addr_in_range || write_4k_boundary_cross || (AWBURST == 2'b01 && write_4k_boundary_cross)) begin
                            write_resp_status <= 2'b10; // SLVERR
                        end else begin
                            write_resp_status <= 2'b00; // OKAY
                        end

                        AWREADY   <= 1'b0;
                        write_state <= W_ADDR;
                    end
                end

                W_ADDR: begin
                    // AXI4 spec: WREADY can be asserted before AWREADY. Here, we assert it after AW handshake.
                    WREADY  <= 1'b1;
                    write_state <= W_DATA;
                end

                W_DATA: begin
                    if (WVALID && WREADY) begin
                        // Only perform memory write if address is valid and no prior error
                        if (write_resp_status == 2'b00) begin
                            mem_en    <= 1'b1;
                            mem_we    <= 1'b1;
                            mem_addr  <= current_write_addr >> ($clog2(DATA_WIDTH/8));

                            // Apply WSTRB to WDATA
                            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                                if (WSTRB[i]) begin
                                    mem_wdata[(i*8)+:8] <= WDATA[(i*8)+:8];
                                end else begin
                                    mem_wdata[(i*8)+:8] <= memory[mem_addr][(i*8)+:8]; // Read-modify-write
                                end
                            end
                        end

                        if (WLAST) begin
                            WREADY <= 1'b0;
                            write_state <= W_RESP;
                            BVALID <= 1'b1;
                            BRESP  <= write_resp_status;
                            BID    <= write_id_reg;
                        end else begin
                            // Increment address for next beat based on burst type
                            case (write_burst_reg)
                                2'b00: begin // FIXED
                                    // Address remains fixed
                                end
                                2'b01: begin // INCR
                                    current_write_addr <= current_write_addr + burst_byte_size;
                                end
                                2'b10: begin // WRAP
                                    // WRAP burst logic: address wraps around a boundary
                                    // Boundary is (AWLEN+1) * (1 << AWSIZE)
                                    // Base address is AWADDR, aligned to (AWLEN+1) * (1 << AWSIZE)
                                    // For simplicity, assuming WRAP bursts are handled by master not crossing 4KB boundary
                                    // and address calculation is similar to INCR within the wrap boundary.
                                    current_write_addr <= current_write_addr + burst_byte_size;
                                    // Need more complex logic for actual wrap-around
                                end
                                default: begin // Reserved, treat as INCR
                                    current_write_addr <= current_write_addr + burst_byte_size;
                                end
                            endcase
                            write_beat_count <= write_beat_count - 1'b1;
                        end
                    end
                end

                W_RESP: begin
                    if (BREADY && BVALID) begin
                        BVALID <= 1'b0;
                        BRESP  <= 2'b00;
                        BID    <= {ID_WIDTH{1'b0}};
                        write_state <= W_IDLE;
                    end
                end

                default: write_state <= W_IDLE;
            endcase

            // ------------------------------------
            // Read Channel FSM
            // ------------------------------------
            case (read_state)
                R_IDLE: begin
                    ARREADY <= 1'b1;
                    RVALID  <= 1'b0;
                    RLAST   <= 1'b0;
                    RDATA   <= {DATA_WIDTH{1'b0}};
                    RRESP   <= 2'b00;
                    RID     <= {ID_WIDTH{1'b0}};

                    if (ARVALID && ARREADY) begin
                        read_id_reg         <= ARID;
                        read_addr_reg       <= ARADDR;
                        read_len_reg        <= ARLEN;
                        read_size_reg       <= ARSIZE;
                        read_burst_reg      <= ARBURST;
                        read_beat_count     <= ARLEN;
                        current_read_addr   <= ARADDR;

                        // Determine initial response status based on address phase
                        if (!read_addr_in_range || read_4k_boundary_cross || (ARBURST == 2'b01 && read_4k_boundary_cross)) begin
                            read_resp_status <= 2'b10; // SLVERR
                        end else begin
                            read_resp_status <= 2'b00; // OKAY
                        end

                        ARREADY <= 1'b0;
                        read_state <= R_ADDR;
                    end
                end

                R_ADDR: begin
                    // Initiate first memory read
                    if (read_resp_status == 2'b00) begin
                        mem_en   <= 1'b1;
                        mem_addr <= current_read_addr >> ($clog2(DATA_WIDTH/8));
                    end
                    read_state <= R_DATA; // Transition to data phase after initiating read
                end

                R_DATA: begin
                    // Data is available from mem_rdata_pipeline (1 cycle after mem_addr is set)
                    RVALID <= 1'b1;
                    RDATA  <= mem_rdata_pipeline;
                    RRESP  <= read_resp_status;
                    RID    <= read_id_reg;
                    RLAST  <= (read_beat_count == 0);

                    if (RREADY && RVALID) begin
                        RVALID <= 1'b0;
                        if (read_beat_count > 0) begin
                            // Continue burst - update address for next read
                            case (read_burst_reg)
                                2'b00: begin // FIXED
                                    // Address remains fixed
                                end
                                2'b01: begin // INCR
                                    current_read_addr <= current_read_addr + read_burst_byte_size;
                                end
                                2'b10: begin // WRAP
                                    // Similar to write WRAP, assuming master handles 4KB boundary
                                    current_read_addr <= current_read_addr + read_burst_byte_size;
                                    // Need more complex logic for actual wrap-around
                                end
                                default: begin // Reserved, treat as INCR
                                    current_read_addr <= current_read_addr + read_burst_byte_size;
                                end
                            endcase
                            read_beat_count <= read_beat_count - 1'b1;

                            // Initiate next memory read
                            if (read_resp_status == 2'b00) begin
                                mem_en   <= 1'b1;
                                mem_addr <= current_read_addr >> ($clog2(DATA_WIDTH/8));
                            end
                            read_state <= R_DATA; // Stay in R_DATA for next transfer
                        end else begin
                            // End of burst
                            RLAST <= 1'b0;
                            read_state <= R_IDLE;
                        end
                    end
                end

                default: read_state <= R_IDLE;
            endcase
        end
    end

endmodule
