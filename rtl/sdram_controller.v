// =============================================================================== //
//                               SDRAM Controller
//                              edwyrion@gmail.com
// Description:
// This module is a simple SDRAM controller for a 16-bit wide external SDRAM chip.
// The purpose of this module is to provide a simple interface between the Terasic
// DE0-Nano FPGA board and the external SDRAM chip IS42S16160B.
//
// Copyright (c) 2024 Erik A. Rapp
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================== //

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10230

module sdram_controller
(
    // Basic signals
    clk, rst_n, busy,

    // HOST interface
    haddr, hdata_in, hdata_out, hrw, hrw_req, hdata_out_valid,

    // DRAM interface
    sdram_addr, sdram_ba, sdram_dq, sdram_dqm,
    sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n
);

    // ================================================================== //
    //  Module parameter declarations
    // ================================================================== //

    // SDRAM parameters
    parameter   SDRAM_CLK_FREQ      = 143, // [MHz]
                SDRAM_REFRESH_RATE  = 64, // [ms]
                SDRAM_REFRESH_COUNT = 8192;

    // Address parameters
    localparam  ROW_WIDTH       = 13,
                COL_WIDTH       = 9,
                BANK_WIDTH      = 2;

    localparam  RADDR_WIDTH     = ROW_WIDTH,
                HADDR_WIDTH     = BANK_WIDTH + ROW_WIDTH + COL_WIDTH; // {sdram_ba, row_addr, col_addr}

    // Refresh parameters
    localparam	SDRAM_REFRESH_CYCLES = (SDRAM_CLK_FREQ * SDRAM_REFRESH_RATE * 1_000) / SDRAM_REFRESH_COUNT; // ~7.81 [us] @ 143 [MHz]

    // Timing parameters [cycles], default @ 143 [MHz]
    parameter [3:0]     tRC     = 4'd9,
                        tRCD    = 4'd2,
                        tRAS    = 4'd6,
                        tRP     = 4'd6,
                        tMRD    = 4'd2,
                        tDPL    = 4'd2;

    // Mode register default values
    parameter   MR_BURST_LEN        = 3'd0, // Burst length = 1
                MR_BURST_TYPE       = 1'b0, // Sequential burst
                MR_CAS_LAT          = 3'd3, // CAS latency = 3
                MR_OP_MODE          = 2'd0, // Standard operation
                MR_WR_BURST_MODE    = 1'b0, // Burst write mode
                MR_RESERVED         = {3{1'b0}}; // Reserved bits, recommended to be 0

    // ================================================================== //
    //  Module port declarations
    // ================================================================== //

    // 143 MHz clock and asynchronous reset
    input                       clk;
    input                       rst_n;

    // HOST interface
    input   [HADDR_WIDTH-1:0]   haddr; // {sdram_ba[1:0], row_addr[12:0], col_addr[8:0]}
    input   [15:0]              hdata_in;
    output  [15:0]              hdata_out;
    input                       hrw; // 1'b0 - read, 1'b1 - write
    input                       hrw_req;
    output                      hdata_out_valid;
    output                      busy;

    // SDRAM interface
    output  [RADDR_WIDTH-1:0]   sdram_addr;
    output  [BANK_WIDTH-1:0]    sdram_ba;
    inout   [15:0]              sdram_dq;
    output  [1:0]               sdram_dqm; // {dqmh, dqml}
    output                      sdram_cke;
    output                      sdram_cs_n;
    output                      sdram_ras_n;
    output                      sdram_cas_n;
    output                      sdram_we_n;

    // ================================================================== //
    //  Module internal declarations
    // ================================================================== //

    reg [HADDR_WIDTH-1:0]       haddr_r;
    reg [15:0]                  hdata_in_r;
    reg                         hrw_r;
    reg [15:0]                  wr_data_r;
    reg [15:0]                  rd_data_r;
    reg [2:0]                   sdram_out_valid_r; // CAS latency = 3
    reg                         hdata_out_valid_r;
    reg                         busy_r;
    reg [RADDR_WIDTH-1:0]       addr_r;
    reg [BANK_WIDTH-1:0]        bank_addr_r;
    reg [1:0]                   dqm_r;
    reg                         wr_enable_r;
    reg                         init_done;
    reg [10:0]                  refresh_counter;
    reg                         refresh_req, refresh_req_ack;
    reg [3:0]                   command; // {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n}, we can safely ignore sdram_cke signal

    // ================================================================== //
    //  Module functionality
    // ================================================================== //


    assign {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = command;
    assign sdram_cke = 1'b1; // Always enabled
    assign sdram_ba = bank_addr_r;
    assign sdram_dqm = dqm_r;
    assign sdram_addr = addr_r;
    assign hdata_out_valid = hdata_out_valid_r;
    assign busy = busy_r;
    assign hdata_out = rd_data_r;
    assign sdram_dq = (wr_enable_r) ? wr_data_r : {16{1'bz}};

    // Refresh counter
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            refresh_counter <= SDRAM_REFRESH_CYCLES; 
        end
        else begin
            if (refresh_counter > 11'b0) begin
                refresh_counter <= refresh_counter - 1'b1;
            end
            else begin
                refresh_counter <= SDRAM_REFRESH_CYCLES;
            end
        end
    end

    // Command = {1'b1, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n}
    localparam [3:0]    CMD_NOP     =   4'b0111,   // No operation
                        CMD_BST     =   4'b0110,   // Burst stop
                        CMD_PRE     =   4'b0010,   // Precharge selected bank
                        CMD_REF     =   4'b0001,   // CBR auto refresh (CLK => 1), self refresh (CLK => 0)
                        CMD_ACT     =   4'b0011,   // Activate bank
                        CMD_WR      =   4'b0100,   // Write
                        CMD_RD      =   4'b0101,   // Read
                        CMD_MRS     =   4'b0000,   // Mode register set
                        CMD_DESL    =   4'b1111;   // Deselect, {sdram_ras_n, sdram_cas_n, sdram_we_n} are don't cares

    // States: Initialization sequence
    localparam [3:0]    INIT_PRE    =   5'd0,
                        INIT_REF    =   5'd1,
                        INIT_MRS    =   5'd2,
                        IDLE        =   5'd3,
                        REF_PRE     =   5'd4,
                        REF_ARF     =   5'd5,
                        RW_ACT      =   5'd6,
                        RW_READ     =   5'd7,
                        RW_WRITE    =   5'd8;

    reg [3:0] state;
    reg [3:0] state_cnt, next_state_cnt; // Maximal possible hold time is 10 cycles for tRC
    reg [2:0] repeat_counter; // Used only for initialization refresh sequence

    // State (command delay) counter
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            state_cnt <= 4'b0;
        end
        else begin
            if (state_cnt == 4'b0) begin
                state_cnt <= next_state_cnt;
            end
            else begin
                state_cnt <= state_cnt - 1'b1;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            dqm_r           <= 2'b11;
            wr_enable_r     <= 1'b0;
            refresh_req_ack <= 1'b0;
            repeat_counter  <= 3'd7;
            state           <= INIT_PRE;
        end
        else begin
            if (state_cnt == 0) begin
                case (state)
                    IDLE: begin
                        command <= CMD_DESL;
                        wr_enable_r <= 1'b0;
                        dqm_r <= 2'b0;

                        // Refresh has the highest priority
                        if (refresh_req) begin
                            state <= REF_PRE;
                        end
                        else begin
                            if (hrw_req) begin
                                haddr_r <= haddr;
                                hrw_r <= hrw;
                                wr_data_r <= hdata_in;
                                state <= RW_ACT;
                            end
                        end
                    end // IDLE

                    INIT_PRE: begin
                        command <= CMD_PRE;
                        addr_r <= {{2{1'b0}}, 1'b1, {10{1'b0}}}; // Precharge all banks
                        bank_addr_r <= 2'b11;
                        state <= INIT_REF;
                    end // INIT_PRE

                    INIT_REF: begin
                        command <= CMD_REF;
                        if (repeat_counter == 3'b0) begin                        
                            state <= INIT_MRS;
                        end
                        else begin
                            repeat_counter <= repeat_counter - 1'b1;
                            state <= INIT_REF;
                        end
                    end // INIT_REF

                    INIT_MRS: begin
                        command <= CMD_MRS;
                        {bank_addr_r, addr_r} <= {{3{1'b0}}, MR_WR_BURST_MODE, MR_OP_MODE, MR_CAS_LAT, MR_BURST_TYPE, MR_BURST_LEN};
                        //init_done <= 1'b1;  
                        state <= IDLE;
                    end // INIT_MRS

                    REF_PRE: begin
                        command <= CMD_PRE;
                        bank_addr_r <= 2'b11;
                        addr_r <= {{2'b0}, 1'b1, {10'b0}}; // Precharge all banks
                        refresh_req_ack <= 1'b1;
                        repeat_counter <= 1'b1;
                        state <= REF_ARF;
                    end // REF_PRE

                    REF_ARF: begin
                        command <= CMD_REF;
                        if (repeat_counter == 3'b0) begin
                            state <= IDLE;
                        end
                        else begin
                            repeat_counter <= repeat_counter - 1'b1;
                            state <= REF_ARF;
                        end
                    end // REF_ARF

                    RW_ACT: begin
                        command <= CMD_ACT;
                        {bank_addr_r, addr_r} <= haddr_r[23:9];

                        if (hrw_r == 1'b0) begin
                            state <= RW_READ;
                        end
                        else begin
                            state <= RW_WRITE;                          
                        end
                    end // RW_ACT

                    RW_READ: begin
                        command <= CMD_RD;
                        {bank_addr_r, addr_r} <= {haddr_r[23:22], {{2{1'b0}}, {1{1'b1}}, {1{1'b0}}, haddr_r[8:0]}}; // Precharge all banks
                        state <= IDLE;
                    end // RW_READ

                    RW_WRITE: begin
                        command <= CMD_WR;
                        {bank_addr_r, addr_r} <= {haddr_r[23:22], {{2{1'b0}}, {1{1'b1}}, {1{1'b0}}, haddr_r[8:0]}}; // Precharge all banks
                        wr_enable_r <= 1'b1;
                        state <= IDLE;
                    end // RW_WRITE

                    default: begin
                        state <= IDLE;
                        command <= CMD_DESL;
                    end
                endcase
            end
            else begin
                refresh_req_ack <= 1'b0;
                wr_enable_r <= 1'b0;
                command <= CMD_NOP;
            end
        end
    end

    always @(*) begin

        next_state_cnt = 4'b0;

        case (state)
            INIT_PRE, REF_PRE: begin
                next_state_cnt = tRP;
            end // Precharge command

            INIT_REF, REF_ARF: begin
                next_state_cnt = tRC;
            end // Refresh command

            INIT_MRS: begin
                next_state_cnt = tMRD;
            end // Mode register set

            RW_ACT: begin
                next_state_cnt = tRCD;
            end // Activate row command

            RW_READ: begin
                next_state_cnt = MR_CAS_LAT;
            end // Read command

            RW_WRITE: begin
                next_state_cnt = tDPL;
            end // Write command
        endcase
    end

    // Refresh request flag
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            refresh_req <= 1'b0;
        end
        else begin
            refresh_req <= (refresh_req || (refresh_counter == 11'b0)) && ~refresh_req_ack && init_done;
        end
    end

    // Initialization flag
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            init_done <= 1'b0;
        end
        else begin
            init_done <= init_done || (state == IDLE);
        end
    end

    // Valid data flag (for read)
	wire rd_strobe;
    assign rd_strobe = (command == CMD_RD) ? 1'b1 : 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            sdram_out_valid_r <= 3'b0;
        end
        else begin
            sdram_out_valid_r <= {sdram_out_valid_r, rd_strobe};
        end
    end

    // Register valid data flag
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            hdata_out_valid_r <= 3'b0;
        end
        else begin
            hdata_out_valid_r <= sdram_out_valid_r[2];
        end
    end

    // Reading data, host side
    always @(posedge clk) begin
        rd_data_r <= sdram_dq;
    end

    // Busy flag
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            busy_r <= 1'b1; // Reset => DRAM initialization
        end
        else begin
            // Set the busy flag if the state is not IDLE and there is no refresh request or command delay and the initialization is done
            busy_r <= (state != IDLE) || refresh_req || (state_cnt != 0) || ~init_done;
        end
    end

    // DEBUG
    // synopsys translate_off
    reg [23:0] code_name;
    assign code_name =  (command == 4'h0) ? 24'h4c4d52 : // Load mode register
                        (command == 4'h1) ? 24'h415246 : // Auto refresh
                        (command == 4'h2) ? 24'h505245 : // Precharge
                        (command == 4'h3) ? 24'h414354 : // Activate
                        (command == 4'h4) ? 24'h205752 : // Write
                        (command == 4'h5) ? 24'h205244 : // Read
                        (command == 4'h6) ? 24'h425354 : // Burst stop
                        (command == 4'h7) ? 24'h4e4f50 : // No operation
                        (command == 4'hF) ? 24'h444553 : 24'h424144; // Deselect or unknown
    // synopsys translate_on
endmodule