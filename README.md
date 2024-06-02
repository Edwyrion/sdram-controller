# Implementation of SDRAM controller for De0-nano board

This repository contains a RTL design for an SDRAM controller used by De0-nano board, written in Verilog. In its current form, this SDRAM controller does not support burst read and write operations as describer in a provided datasheet for IS42SxB SDRAM. This controller runs at 143 MHz and therefore requires a clock-domain crossing for interfacing, for this purpose and RTL design of an asynchronnou FIFO module of variable depth and width is provided.

This SDRAM module has been tested on a physical De0-Nano board with Cyclone-IV FPGA chip running at 50 MHz.

## Example of operation

### Single write cycle

![image](https://github.com/Edwyrion/sdram-controller/assets/99217699/7a1ddfbc-fafb-4efc-9c53-0cadc8fd68c8)

### Single read cycle

![image](https://github.com/Edwyrion/sdram-controller/assets/99217699/914320b3-3117-4548-b437-5e37cc9a4266)

## To do
1. Design a better solution for bank selecting, currently all banks are being precharged.
2. Support burst write and read command of variable bursts lengths.
