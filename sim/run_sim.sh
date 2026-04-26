#!/bin/bash

# Define paths
RTL_DIR="../rtl"
TB_DIR="../tb"
SIM_DIR="."

# Simulator specific commands (using Icarus Verilog as an example)
# For other simulators like VCS, QuestaSim, Xcelium, commands will differ.

# Compilation
iverilog -g2012 -o ${SIM_DIR}/sim.vvp \
  ${RTL_DIR}/axi4_memory.sv \
  ${RTL_DIR}/axi4.sv \
  ${TB_DIR}/axi4_interface.sv \
  ${TB_DIR}/axi4_transaction.sv \
  ${TB_DIR}/axi4_driver.sv \
  ${TB_DIR}/axi4_monitor.sv \
  ${TB_DIR}/axi4_scoreboard.sv \
  ${TB_DIR}/axi4_sequencer.sv \
  ${TB_DIR}/axi4_assert.sv \
  ${TB_DIR}/axi4_testbench.sv

# Check for compilation errors
if [ $? -ne 0 ]; then
  echo "Error: Compilation failed!"
  exit 1
fi

echo "Compilation successful. Running simulation..."

# Simulation
vvp ${SIM_DIR}/sim.vvp

# Check for simulation errors
if [ $? -ne 0 ]; then
  echo "Error: Simulation failed!"
  exit 1
fi

echo "Simulation finished."
