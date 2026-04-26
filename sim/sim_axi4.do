onerror {quit -f}

# Define paths
vlib work

# Compile RTL
vlog -sv -work work ../rtl/axi4_memory.sv
vlog -sv -work work ../rtl/axi4.sv

# Compile Testbench
vlog -sv -work work ../tb/axi4_interface.sv
vlog -sv -work work ../tb/axi4_transaction.sv
vlog -sv -work work ../tb/axi4_driver.sv
vlog -sv -work work ../tb/axi4_monitor.sv
vlog -sv -work work ../tb/axi4_scoreboard.sv
vlog -sv -work work ../tb/axi4_sequencer.sv
vlog -sv -work work ../tb/axi4_assert.sv
vlog -sv -work work ../tb/axi4_testbench.sv

# Start simulation
vsim -L work -c -do "set StdArithNoWarnings 1; run -all; quit -f" work.axi4_testbench

# Enable assertions, functional coverage, and code coverage
# For QuestaSim, these are typically enabled during compilation or simulation setup
# Assertions are enabled by default with -sv. For coverage:
# vsim -coverage -assertdebug -sv_seed random -do "run -all; coverage report -file coverage_axi4.txt -detail -assert -directive -code bcsf; quit -f" work.axi4_testbench

# Add meaningful waveform groups (example, adjust as needed)
# add wave -group AXI4_AW /axi4_testbench/axi_vif/AWID /axi4_testbench/axi_vif/AWADDR /axi4_testbench/axi_vif/AWLEN /axi4_testbench/axi_vif/AWSIZE /axi4_testbench/axi_vif/AWBURST /axi4_testbench/axi_vif/AWVALID /axi4_testbench/axi_vif/AWREADY
# add wave -group AXI4_W /axi4_testbench/axi_vif/WDATA /axi4_testbench/axi_vif/WSTRB /axi4_testbench/axi_vif/WVALID /axi4_testbench/axi_vif/WLAST /axi4_testbench/axi_vif/WREADY
# add wave -group AXI4_B /axi4_testbench/axi_vif/BID /axi4_testbench/axi_vif/BRESP /axi4_testbench/axi_vif/BVALID /axi4_testbench/axi_vif/BREADY
# add wave -group AXI4_AR /axi4_testbench/axi_vif/ARID /axi4_testbench/axi_vif/ARADDR /axi4_testbench/axi_vif/ARLEN /axi4_testbench/axi_vif/ARSIZE /axi4_testbench/axi_vif/ARBURST /axi4_testbench/axi_vif/ARVALID /axi4_testbench/axi_vif/ARREADY
# add wave -group AXI4_R /axi4_testbench/axi_vif/RID /axi4_testbench/axi_vif/RDATA /axi4_testbench/axi_vif/RRESP /axi4_testbench/axi_vif/RVALID /axi4_testbench/axi_vif/RLAST /axi4_testbench/axi_vif/RREADY
# add wave -group DUT_Internal /axi4_testbench/dut_inst/write_state /axi4_testbench/dut_inst/read_state /axi4_testbench/dut_inst/mem_en /axi4_testbench/dut_inst/mem_we /axi4_testbench/dut_inst/mem_addr /axi4_testbench/dut_inst/mem_wdata /axi4_testbench/dut_inst/mem_rdata

# To run with GUI:
# vsim -L work -assertdebug -sv_seed random work.axi4_testbench
# do wave.do
# run -all

# For coverage reporting (uncomment and adjust for your specific needs)
# coverage save -onexit axi4_coverage.ucdb
# coverage report -file axi4_coverage_report.txt -detail -assert -directive -code bcsf

# For automated run, use the -c (command line) option with vsim
# Example for full coverage run:
# vsim -c -do "run -all; coverage report -file axi4_coverage_report.txt -detail -assert -directive -code bcsf; quit -f" -coverage -assertdebug -sv_seed random work.axi4_testbench

# Simplified run for basic check:
# vsim -c -do "run -all; quit -f" work.axi4_testbench

# The run_sim.sh script will handle the actual vsim command with coverage options.
