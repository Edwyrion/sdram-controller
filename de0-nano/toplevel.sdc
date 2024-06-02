create_clock -name {sys_clk} -period 20.000ns [get_ports {sys_clk}]
derive_pll_clocks
derive_clock_uncertainty


# false path for synchronization flip-flops

set_clock_groups -group [get_clocks {sys_clk}] -group [get_clocks {pll*clk[0]}] -asynchronous