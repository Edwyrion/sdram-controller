module pll_143m
(
    inclk0, c0
);

    // Module ports
    input   inclk0;
    output  c0;

    // Internal signals
	wire [4:0] pll_clocks;
	assign c0 = pll_clocks[0];

    altpll altpll_inst
    (
        .inclk({1'b0, inclk0}),
		.areset(1'b0),
        .pllena(1'b1),
        .clk(pll_clocks),
		.locked()
    );
	 
	defparam	altpll_inst.bandwidth_type			= "AUTO",
				altpll_inst.width_clock				= 5,
				altpll_inst.clk0_divide_by			= 36,
				altpll_inst.clk0_duty_cycle			= 50,
				altpll_inst.clk0_multiply_by 		= 103, 
				altpll_inst.clk0_phase_shift 		= "0",
				altpll_inst.compensate_clock 		= "CLK0",
				altpll_inst.inclk0_input_frequency 	= 20000, // 50 MHz
				altpll_inst.intended_device_family 	= "Cyclone IV E",
				altpll_inst.lpm_hint 				= "CBX_MODULE_PREFIX=pll_143m",
				altpll_inst.lpm_type 				= "altpll",
				altpll_inst.operation_mode 			= "NORMAL",
				altpll_inst.pll_type 				= "AUTO",
				altpll_inst.port_activeclock 		= "PORT_UNUSED",
				altpll_inst.port_areset 			= "PORT_UNUSED",
				altpll_inst.port_clkbad0 			= "PORT_UNUSED",
				altpll_inst.port_clkbad1 			= "PORT_UNUSED",
				altpll_inst.port_clkloss 			= "PORT_UNUSED",
				altpll_inst.port_clkswitch 			= "PORT_UNUSED",
				altpll_inst.port_configupdate 		= "PORT_UNUSED",
				altpll_inst.port_fbin 				= "PORT_UNUSED",
				altpll_inst.port_inclk0 			= "PORT_USED",
				altpll_inst.port_inclk1 			= "PORT_UNUSED",
				altpll_inst.port_locked 			= "PORT_UNUSED",
				altpll_inst.port_pfdena 			= "PORT_UNUSED",
				altpll_inst.port_phasecounterselect = "PORT_UNUSED",
				altpll_inst.port_phasedone 			= "PORT_UNUSED",
				altpll_inst.port_phasestep 			= "PORT_UNUSED",
				altpll_inst.port_phaseupdown 		= "PORT_UNUSED",
				altpll_inst.port_pllena 			= "PORT_UNUSED",
				altpll_inst.port_scanaclr 			= "PORT_UNUSED",
				altpll_inst.port_scanclk 			= "PORT_UNUSED",
				altpll_inst.port_scanclkena 		= "PORT_UNUSED",
				altpll_inst.port_scandata 			= "PORT_UNUSED",
				altpll_inst.port_scandataout 		= "PORT_UNUSED",
				altpll_inst.port_scandone 			= "PORT_UNUSED",
				altpll_inst.port_scanread 			= "PORT_UNUSED",
				altpll_inst.port_scanwrite 			= "PORT_UNUSED",
				altpll_inst.port_clk0 				= "PORT_USED",
				altpll_inst.port_clk1 				= "PORT_UNUSED",
				altpll_inst.port_clk2 				= "PORT_UNUSED",
				altpll_inst.port_clk3 				= "PORT_UNUSED",
				altpll_inst.port_clk4 				= "PORT_UNUSED",
				altpll_inst.port_clk5 				= "PORT_UNUSED",
				altpll_inst.port_clkena0 			= "PORT_UNUSED",
				altpll_inst.port_clkena1 			= "PORT_UNUSED",
				altpll_inst.port_clkena2 			= "PORT_UNUSED",
				altpll_inst.port_clkena3 			= "PORT_UNUSED",
				altpll_inst.port_clkena4 			= "PORT_UNUSED",
				altpll_inst.port_clkena5 			= "PORT_UNUSED",
				altpll_inst.port_extclk0 			= "PORT_UNUSED",
				altpll_inst.port_extclk1 			= "PORT_UNUSED",
				altpll_inst.port_extclk2 			= "PORT_UNUSED",
				altpll_inst.port_extclk3 			= "PORT_UNUSED";
endmodule