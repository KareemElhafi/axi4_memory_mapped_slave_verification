onerror {quit -f}

# Define paths
vlib work

# Compile RTL
vlog -sv -work work ../rtl/axi4_memory.sv

# Compile Testbench for standalone memory
vlog -sv -work work ../memory_standalone_test/memory_interface.sv
vlog -sv -work work ../memory_standalone_test/mem_transaction.sv
vlog -sv -work work ../memory_standalone_test/mem_checker.sv
vlog -sv -work work ../memory_standalone_test/mem_test.sv

# Start simulation
# The run_sim.sh script will handle the actual vsim command with coverage options.

# Add meaningful waveform groups (example, adjust as needed)
# add wave -group Memory_Interface /mem_test/mif/ACLK /mem_test/mif/ARESETn /mem_test/mif/mem_en /mem_test/mif/mem_we /mem_test/mif/mem_addr /mem_test/mif/mem_wdata /mem_test/mif/mem_rdata
# add wave -group DUT_Internal /mem_test/dut/memory
# add wave -group Transaction /mem_test/tr.addr /mem_test/tr.data /mem_test/tr.we

# For automated run, use the -c (command line) option with vsim
# Example for full coverage run:
# vsim -c -do "run -all; coverage report -file mem_coverage_report.txt -detail -assert -directive -code bcsf; quit -f" -coverage -assertdebug -sv_seed random work.mem_test

# Simplified run for basic check:
# vsim -c -do "run -all; quit -f" work.mem_test
