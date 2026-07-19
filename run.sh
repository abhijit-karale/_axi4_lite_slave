#!/bin/bash
set -e
iverilog -g2012 -o sim.out rtl/axi4_lite_slave.sv tb/tb_axi4_lite_slave.sv
vvp sim.out
python3 vcd_plot.py waveform/axi4_lite_slave.vcd waveform/axi4_lite_slave_waveform.png \
    aclk aresetn awvalid awready wvalid wready bvalid arvalid arready rvalid rdata --window 0 400
echo "Done. Open waveform/axi4_lite_slave.vcd in GTKWave for full interactive waveform."
