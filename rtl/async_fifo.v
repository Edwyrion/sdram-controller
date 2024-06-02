
// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10230

module ff_synchronizer
(
    clk, rst_n,
    ptr, ptr_sync
);

    // ================================================================== //
    //  Module parameters declarations
    // ================================================================== //

    parameter   AWIDTH  = 2;
    parameter   DWIDTH  = 16;
    localparam  DEPTH   = (1 << AWIDTH);

    // ================================================================== //
    //  Module port declarations
    // ================================================================== //

    input                   clk;
    input                   rst_n;
    input       [AWIDTH:0]  ptr;
    output      [AWIDTH:0]  ptr_sync;

    // ================================================================== //
    //  Internal registers and wires declarations
    // ================================================================== //

    reg         [AWIDTH:0]  ptr_sync_r;
    reg         [AWIDTH:0]  ptr_q;

    // ================================================================== //
    //  Module functionality
    // ================================================================== //

    assign ptr_sync = ptr_sync_r;

    // Synchronize the write pointer to the read clock domain
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            {ptr_sync_r, ptr_q} <= 0;
        end
        else begin
            {ptr_sync_r, ptr_q} <= {ptr_q, ptr};
        end
    end

endmodule

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10230

module async_fifo
(
    // Globals
    wclk, rclk,

    empty, full,
    wr_data, wr_enable, wrst_n,
    rd_data, rd_enable, rrst_n
);

    // ================================================================== //
    //  Module parameters declarations
    // ================================================================== //

    parameter   AWIDTH = 2; // Address width of 1 is not supported
    parameter   DWIDTH = 16;
    localparam  DEPTH = (1 << AWIDTH);
    
    // Check for unsupported configurations
    initial begin
        if (AWIDTH < 2) begin
            $display("Error: Address width of < 2 is not supported.");
            $finish;
        end
    end

    // ================================================================== //
    //  Module port declarations
    // ================================================================== //

    // Clocks and asynchronous resets
    input                   wclk;
    input                   wrst_n;
    input                   rclk;
    input                   rrst_n;

    // FIFO write interface
    input   [DWIDTH-1:0]    wr_data;
    input                   wr_enable;
    output                  full;

    // FIFO read interface
    output  [DWIDTH-1:0]    rd_data;
    input                   rd_enable;
    output                  empty;

    // ================================================================== //
    //  Internal registers and wires declarations
    // ================================================================== //

    // Internal signals
    wire    [AWIDTH-1:0]    wr_addr;
    wire    [AWIDTH-1:0]    rd_addr;
    wire                    full_next;
    wire                    empty_next;
    reg                     full_r;
    reg                     empty_r;

    // Synchonized write pointer
    reg     [AWIDTH:0]      wr_ptr;
    wire    [AWIDTH:0]      wr2rd_q2_ptr;

    // Gray counter for the write pointer
    reg     [AWIDTH:0]      wr_cnt_binary;
    wire    [AWIDTH:0]      wr_cnt_binary_next, wr_cnt_gray_next;

    // Synchronized read pointer
    reg     [AWIDTH:0]      rd_ptr;
    wire    [AWIDTH:0]      rd2wr_q2_ptr;

    // Gray counter for the read pointer
    reg     [AWIDTH:0]      rd_cnt_binary;
    wire    [AWIDTH:0]      rd_cnt_binary_next, rd_cnt_gray_next;

    // FIFO memory
    reg     [DWIDTH-1:0]    fifo_mem [0:DEPTH-1];
    reg     [DWIDTH-1:0]    rd_data_r;

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            fifo_mem[i] = {DWIDTH{1'b0}};
        end
    end

    // ================================================================== //
	//	Module functionality
	// ================================================================== //

    assign empty = empty_r;
    assign full = full_r;

    // Reading and writing the FIFO memory
    always @(posedge wclk) begin
        if (wr_enable && ~full) begin
            fifo_mem[wr_addr] <= wr_data;
        end
    end

    assign rd_data = fifo_mem[rd_addr];

    // Synchronize the read pointer to the write clock domain
    ff_synchronizer rd2wr_sync (
        .clk(wclk),
        .rst_n(wrst_n),
        .ptr(rd_ptr),
        .ptr_sync(rd2wr_q2_ptr)
    );

    defparam rd2wr_sync.AWIDTH = AWIDTH;
    defparam rd2wr_sync.DWIDTH = DWIDTH;

    // Gray counter for the write pointer
    always @(posedge wclk or negedge wrst_n) begin
        if (wrst_n == 0) begin
            {wr_cnt_binary, wr_ptr} <= 0;
        end
        else begin
            {wr_cnt_binary, wr_ptr} <= {wr_cnt_binary_next, wr_cnt_gray_next};
        end
    end

    assign wr_addr = wr_cnt_binary[AWIDTH-1:0];

    assign wr_cnt_binary_next = wr_cnt_binary + {{AWIDTH{1'b0}}, (wr_enable & ~full)};
    assign wr_cnt_gray_next = (wr_cnt_binary_next ^ (wr_cnt_binary_next >> 1));

    // Update the full flag
    // TODO: Modify this to account for the case of AWIDTH < 2
    assign full_next = (wr_cnt_gray_next == {~rd2wr_q2_ptr[AWIDTH:AWIDTH-1], rd2wr_q2_ptr[AWIDTH-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (wrst_n == 0) begin
            full_r <= 1'b0;
        end
        else begin
            full_r <= full_next;
        end
    end

    // Synchronize the write pointer to the read clock domain
    ff_synchronizer wr2rd_sync (
        .clk(rclk),
        .rst_n(rrst_n),
        .ptr(wr_ptr),
        .ptr_sync(wr2rd_q2_ptr)
    );

    defparam wr2rd_sync.AWIDTH = AWIDTH;
    defparam wr2rd_sync.DWIDTH = DWIDTH;

    // Gray counter for the read pointer
    always @(posedge rclk or negedge rrst_n) begin
        if (rrst_n == 0) begin
            {rd_cnt_binary, rd_ptr} <= 0;
        end
        else begin
            {rd_cnt_binary, rd_ptr} <= {rd_cnt_binary_next, rd_cnt_gray_next};
        end
    end

    assign rd_addr = rd_cnt_binary[AWIDTH-1:0];

    assign rd_cnt_binary_next = rd_cnt_binary + {{AWIDTH{1'b0}}, (rd_enable & ~empty)};
    assign rd_cnt_gray_next = ((rd_cnt_binary_next >> 1) ^ rd_cnt_binary_next);

    // Update the empty flag
    assign empty_next = (rd_cnt_gray_next == wr2rd_q2_ptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (rrst_n == 0) begin
            empty_r <= 1'b1;
        end
        else begin
            empty_r <= empty_next;
        end
    end

endmodule