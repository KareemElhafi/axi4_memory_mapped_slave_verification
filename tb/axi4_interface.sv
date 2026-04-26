interface axi4_interface (
    input bit ACLK,
    input bit ARESETn
);

    // AXI4 signals
    logic [3:0]     AWID;       // Assuming ID_WIDTH = 4 for example
    logic [15:0]    AWADDR;
    logic [7:0]     AWLEN;
    logic [2:0]     AWSIZE;
    logic [1:0]     AWBURST;
    logic           AWVALID;
    logic           AWREADY;

    logic [31:0]    WDATA;
    logic [3:0]     WSTRB;      // Assuming DATA_WIDTH = 32, so 4 bytes
    logic           WVALID;
    logic           WLAST;
    logic           WREADY;

    logic [3:0]     BID;
    logic [1:0]     BRESP;
    logic           BVALID;
    logic           BREADY;

    logic [3:0]     ARID;
    logic [15:0]    ARADDR;
    logic [7:0]     ARLEN;
    logic [2:0]     ARSIZE;
    logic [1:0]     ARBURST;
    logic           ARVALID;
    logic           ARREADY;

    logic [3:0]     RID;
    logic [31:0]    RDATA;
    logic [1:0]     RRESP;
    logic           RVALID;
    logic           RLAST;
    logic           RREADY;

    // Clocking block for DUT synchronization
    clocking cb_dut @(posedge ACLK);
        default input #1step output #1;
        input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID;
        output AWREADY;
        input  WDATA, WSTRB, WVALID, WLAST;
        output WREADY;
        output BID, BRESP, BVALID;
        input  BREADY;
        input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID;
        output ARREADY;
        output RID, RDATA, RRESP, RVALID, RLAST;
        input  RREADY;
    endclocking

    // Clocking block for Testbench synchronization
    clocking cb_tb @(posedge ACLK);
        default input #1step output #1;
        output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWVALID;
        input  AWREADY;
        output WDATA, WSTRB, WVALID, WLAST;
        input  WREADY;
        input  BID, BRESP, BVALID;
        output BREADY;
        output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARVALID;
        input  ARREADY;
        input  RID, RDATA, RRESP, RVALID, RLAST;
        output RREADY;
    endclocking

    // Modport for DUT connection
    modport dut (
        input  ACLK,
        input  ARESETn,

        // Write address channel
        input  AWID,
        input  AWADDR,
        input  AWLEN,
        input  AWSIZE,
        input  AWBURST,
        input  AWVALID,
        output AWREADY,

        // Write data channel
        input  WDATA,
        input  WSTRB,
        input  WVALID,
        input  WLAST,
        output WREADY,

        // Write response channel
        output BID,
        output BRESP,
        output BVALID,
        input  BREADY,

        // Read address channel
        input  ARID,
        input  ARADDR,
        input  ARLEN,
        input  ARSIZE,
        input  ARBURST,
        input  ARVALID,
        output ARREADY,

        // Read data channel
        output RID,
        output RDATA,
        output RRESP,
        output RVALID,
        output RLAST,
        input  RREADY
    );

    // Modport for Testbench connection
    modport tb (
        input  ACLK,
        output ARESETn,

        // Write address channel
        output AWID,
        output AWADDR,
        output AWLEN,
        output AWSIZE,
        output AWBURST,
        output AWVALID,
        input  AWREADY,

        // Write data channel
        output WDATA,
        output WSTRB,
        output WVALID,
        output WLAST,
        input  WREADY,

        // Write response channel
        input  BID,
        input  BRESP,
        input  BVALID,
        output BREADY,

        // Read address channel
        output ARID,
        output ARADDR,
        output ARLEN,
        output ARSIZE,
        output ARBURST,
        output ARVALID,
        input  ARREADY,

        // Read data channel
        input  RID,
        input  RDATA,
        input  RRESP,
        input  RVALID,
        input  RLAST,
        output RREADY
    );

endinterface
