`timescale 1ns/1ps

module async_fifo_tb();

    reg wclk, rclk;

    always #(10ns)    wclk  = ~wclk; // 50 [MHz] clock
    always #(3.5ns)   rclk  = ~rclk; // 143 [MHz] clock

    wire empty, full;
    reg wrst_n, rrst_n;
    reg wr_enable, rd_enable;

    reg [7:0] error_count = 0;

    localparam  DWIDTH = 4,
                AWIDTH = 3;

    reg [DWIDTH-1:0] wr_data, wr_data_q[$], wr_data_rd;
    wire [DWIDTH-1:0] rd_data;

    async_fifo afifo_inst
    (
        .wclk(wclk),
        .rclk(rclk),
        .wrst_n(wrst_n),
        .rrst_n(rrst_n),
        .wr_enable(wr_enable),
        .rd_enable(rd_enable),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .empty(empty),
        .full(full)
    );

    defparam    afifo_inst.DWIDTH = DWIDTH,
                afifo_inst.AWIDTH = AWIDTH;

    // Defaulting FIFO contents to 0, not necessary
    initial begin
        for (int i = 0; i < (1 << AWIDTH); i++) begin
            afifo_inst.fifo_mem[i] = 0;
        end
    end

    // Write interface
    initial begin
        wclk = 0;
        wrst_n = 0;
        wr_enable = 0;
        wr_data = {DWIDTH{1'b0}};

        repeat (5) @(posedge wclk);
        wrst_n = 1;

        for (int i = 0; i < 16; i++) begin
            @(posedge wclk iff ~full);
                wr_enable = ((i % 2) == 0) && (~full);
                if (wr_enable) begin
                    wr_data = $urandom;
                    wr_data_q.push_back(wr_data);
                end
        end
    end

    // Read interface
    initial begin
        rclk = 0;
        rrst_n = 0;
        rd_enable = 0;

        repeat (10) @(posedge rclk);
        rrst_n = 1;

        #350;

        for (int i = 0; i < 16; i++) begin
            @(posedge rclk iff ~empty);
                rd_enable = ((i % 2) == 0) && (~empty);
                if (rd_enable) begin
                    wr_data_rd = wr_data_q.pop_front();
                    if (wr_data_rd !== rd_data) begin
                        $display("ERROR: wr_data_rd = %h, rd_data = %h", wr_data_rd, rd_data);
                        error_count = error_count + 1;
                    end
                    else begin
                        $display("PASSED: wr_data_rd = %h, rd_data = %h", wr_data_rd, rd_data);
                    end
                end
        end

        //$finish;
    end

    // Simulation
    initial begin
        $dumpfile("async_fifo_tb.vcd"); $dumpvars;
    end

endmodule