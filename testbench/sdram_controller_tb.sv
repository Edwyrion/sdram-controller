`timescale 1ns/100ps

module sdram_controller_tb();

    reg clk_143mhz = 0;
    reg clk_50mhz = 0;

    always begin
        #(3.5) clk_143mhz = ~clk_143mhz;
    end
    always begin
        #(10) clk_50mhz = ~clk_50mhz;
    end

    reg rst_n = 1;

    wire busy;

    wire [23:0] haddr;
    wire [15:0] hdata_in;
    wire hrw;
    wire hrw_req;
    wire hdata_out_valid;
    wire [15:0] hdata_out;

    sdram_controller sdram_controller_inst
    (
        .clk(clk_143mhz),
        .rst_n(rst_n),

        // Host interface
        .busy(busy),

        .haddr(haddr),
        .hrw(hrw),
        .hrw_req(hrw_req),
        .hdata_in(hdata_in),
        .hdata_out_valid(hdata_out_valid),
        .hdata_out(hdata_out),


        // SDRAM interface
        .sdram_addr(),
        .sdram_ba(),
        .sdram_dq(),
        .sdram_dqm(),

        .sdram_cke(),
        .sdram_cs_n(),
        .sdram_ras_n(),
        .sdram_cas_n(),
        .sdram_we_n()
    );

    reg fifo_wr = 0;
    reg [40:0] fifo_data = 41'b0;
    wire command_empty;
    wire data_empty;

    reg rd_enable = 0;
    wire rd_data;


    wire [40:0] fifo_out; // format: {haddr[41:18], hdata_in[17:2], hrw[1], hrw_req} 
    // haddr format : {sdram_ba[1:0], row_addr[12:0], col_addr[8:0]}

    assign {haddr, hdata_in, hrw} = fifo_out;

    async_fifo command_fifo_inst
    (
        .wclk(clk_50mhz),
        .rclk(clk_143mhz),
        .wrst_n(rst_n),
        .rrst_n(rst_n),
        .empty(command_empty),
        .full(),

        .wr_data(fifo_data),
        .rd_data(fifo_out),
        .wr_enable(fifo_wr),
        .rd_enable(~command_empty && ~busy)
    );

    defparam command_fifo_inst.DWIDTH = 41; 
    defparam command_fifo_inst.AWIDTH = 3;

    assign hrw_req = ~command_empty && ~busy;

    async_fifo data_fifo_inst
    (
        .wclk(clk_143mhz),
        .rclk(clk_50mhz),
        .wrst_n(rst_n),
        .rrst_n(rst_n),
        .empty(data_empty),
        .full(),

        .wr_data(hdata_out),
        .rd_data(rd_data),
        .wr_enable(hdata_out_valid),
        .rd_enable(rd_enable)
    );

    defparam data_fifo_inst.DWIDTH = 16;
    defparam data_fifo_inst.AWIDTH = 3;

    initial begin

        // Reset
        rst_n = 0;
        
        repeat (10) @ (posedge clk_50mhz);
        rst_n = 1;

        @ (posedge clk_50mhz iff !busy);
        sdram_write(2'b0, 13'hAA, 9'h55, 16'hBEEF);

        @ (posedge clk_50mhz);
        sdram_read(2'b0, 13'hAA, 9'h55);

        #10000;

        $finish;

    end

    initial begin
        $dumpfile("sdram_controller_tb.vcd");
        $dumpvars(0, sdram_controller_tb);
    end

    task sdram_write(bit [1:0] bank, bit [12:0] row, bit [8:0] col, bit [15:0] data);
        $display("Writing to SDRAM: bank = %d, row = %d, col = %d, data = 0x%h", bank, row, col, data);
        fifo_data = {{bank, row, col}, data, 1'b1};
        fifo_wr = 1;
        @ (posedge clk_50mhz);
        fifo_wr = 0;
    endtask

    task sdram_read(bit [1:0] bank, bit [12:0] row, bit [8:0] col);
        $display("Reading from SDRAM: bank = %d, row = %d, col = %d", bank, row, col);
        fifo_data = {{bank, row, col}, 16'b0, 1'b0};
        fifo_wr = 1;
        @ (posedge clk_50mhz);
        fifo_wr = 0;

        // Wait for data to be available
        while (data_empty) begin
            @ (posedge clk_50mhz);
        end

        rd_enable = 1;
        $display("Data read from SDRAM: %0h", rd_data);
        @ (posedge clk_50mhz);
        rd_enable = 0;
    endtask

endmodule