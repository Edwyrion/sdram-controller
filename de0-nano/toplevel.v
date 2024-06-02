module toplevel
(
    // 50 MHz clock
    sys_clk,

    // LEDs
    led,

    // Switches
    switch,

    // Buttons
    key,

    // SDRAM ports
    sdram_addr,
    sdram_ba,
    sdram_cas_n,
    sdram_cke,
    sdram_clk,
    sdram_cs_n,
    sdram_dq,
    sdram_dqm,
    sdram_ras_n,
    sdram_we_n,

    // GPIO 0 banck ports
    gpio_0_d,
    gpio_0_in,

    // GPIO 1 bank ports
    gpio_1_d,
    gpio_1_in
);

    // ================================================================== //
    //  Module port declarations
    // ================================================================== //

    // 50 MHz clock
    input           sys_clk;

    // SDRAM ports
    output  [12:0]  sdram_addr;
    output  [1:0]   sdram_ba;
    output          sdram_cas_n;
    output          sdram_cke;
    output          sdram_clk;
    output          sdram_cs_n;
    inout   [15:0]  sdram_dq;
    output  [1:0]   sdram_dqm;
    output          sdram_ras_n;
    output          sdram_we_n;

    // De0-Nano on-board buttons
    input   [1:0]   key;

    // De0-Nano on-board LEDs
    output  [7:0]   led;

    // De0-Nano on-board switches
    input   [3:0]   switch;

    // De0-Nano GPIO 0 bank ports
    inout   [33:0]  gpio_0_d;
    input   [1:0]   gpio_0_in;

    // De0-Nano GPIO 1 bank ports
    inout   [33:0]  gpio_1_d;
    input   [1:0]   gpio_1_in;

    // ================================================================== //
    //  Internal registers and wires declarations
    // ================================================================== //

	wire clk_143mhz;
	wire sdram_clk;
	
	wire sdram_busy, system_busy;
	wire hdata_out_valid;
	wire [15:0] hdata_out;

	wire empty_w;
	wire [40:0] fifo_out;
	wire [23:0] fifo_haddr;
	wire [15:0] fifo_data;
	wire fifo_hrw;
	wire fifo_hrw_req;
	wire rst_n;

    // ================================================================== //
	//	Module functionality
	// ================================================================== //

	assign rst_n = (switch[3]) ? key[0] : 1'b1;
	assign {fifo_haddr, fifo_data, fifo_hrw} = fifo_out;

	pll_143m pll_143m_inst(
		.inclk0(sys_clk),
		.c0(clk_143mhz)
	);
	 
	assign sdram_clk = clk_143mhz;

	sdram_controller sdram_controller_inst (
        .clk			(sdram_clk),
        .rst_n			(rst_n),
        .busy			(sdram_busy),
		.haddr			(fifo_haddr),
		.hrw			(fifo_hrw),
		.hrw_req		(~empty_w),
		.hdata_in		(fifo_data),
		.hdata_out		(hdata_out),
		.hdata_out_valid(hdata_out_valid),

		// SDRAM interface
		.sdram_addr		(sdram_addr),
		.sdram_ba		(sdram_ba),
		.sdram_dq		(sdram_dq),
		.sdram_dqm		(sdram_dqm),
		.sdram_cke		(sdram_cke),
		.sdram_cs_n		(sdram_cs_n),
		.sdram_ras_n	(sdram_ras_n),
		.sdram_cas_n	(sdram_cas_n),
		.sdram_we_n		(sdram_we_n)
    );

	reg [40:0] fifo_in;
	reg fifo_wen;

	async_fifo afifo_command (
		.rclk		(sdram_clk),
		.rrst_n		(rst_n),
		.rd_data	(fifo_out),
		.rd_enable	(~sdram_busy),
		.empty		(empty_w),

		.wclk		(sys_clk),
		.wrst_n		(rst_n),
		.wr_data	(fifo_in),
		.wr_enable	(fifo_wen),
		.full		(system_busy)
	 );

	defparam afifo_command.DWIDTH = 41;
	defparam afifo_command.AWIDTH = 2;

	wire [15:0] ram_read;
	wire read_empty;
	reg fifo_read;

	async_fifo afifo_data (
		.wclk		(sdram_clk),
		.wrst_n		(rst_n),
		.wr_data	(hdata_out),
		.wr_enable	(hdata_out_valid),
		.empty		(read_empty),

		.rclk		(sys_clk),
		.rrst_n		(rst_n),
		.rd_data	(ram_read),
		.rd_enable	(fifo_read),
		.full		()
	);

	defparam afifo_data.DWIDTH = 16;
	defparam afifo_data.AWIDTH = 2;
	
	//reg [31:0] timer;
	//reg [3:0] address;
	reg [8:0] fifo_read_final;


	reg [32:0] timer;
	reg [7:0] value;

	always @(posedge sys_clk, negedge rst_n) begin
		if (rst_n == 0) begin
			fifo_in <= 0;
			fifo_wen <= 0;
			fifo_read <= 0;
			//address <= 0;
			value <= 8'b11000011;
			timer <= 32'd50_000_000;
			fifo_read_final <= 0;
		end
		else begin
			fifo_wen <= 0;
			fifo_read <= 0;

			if (timer == 0) begin
				
				if (key[0] == 0) begin
					value <= value + 1'b1;
					fifo_in <= {{2'b0, 13'b0, {5'b0, 4'b0}}, {8'b0, value}, 1'b1};
					fifo_wen <= 1;
				end else if (key[1] == 0) begin
					fifo_in <= {{2'b0, 13'b0, {5'b0, 4'b0}}, 16'b0, 1'b0};
					fifo_wen <= 1;
				end
				
				if (~read_empty) begin
					fifo_read_final <= ram_read[7:0];
					fifo_read <= 1;
				end

				timer <= 32'd50_000_000;

			end else begin
				timer <= timer - 1;
			end
			
		end
	end
	
	assign led = (switch[0]) ? fifo_read_final : value;

endmodule