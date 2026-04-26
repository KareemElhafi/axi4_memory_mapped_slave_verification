#!/bin/bash

# Configuration
SIMULATOR="questa" # Options: questa, iverilog
TEST_TYPE="axi4"   # Options: axi4, mem

# Paths
RTL_DIR="../rtl"
TB_DIR="../tb"
MEM_STANDALONE_DIR="../memory_standalone_test"
SIM_DIR="."

# Output files
LOG_FILE="simulation.log"
COVERAGE_DB="coverage.ucdb"
COVERAGE_REPORT="coverage_report.txt"

# --- Functions ---

function clean_up {
  echo "Cleaning up previous simulation files..."
  rm -rf work *.log *.ucdb *.txt transcript vsim.wlf
  echo "Cleanup complete."
}

function run_questa_axi4 {
  echo "Running AXI4 simulation with QuestaSim..."
  vsim -c -do "do ${SIM_DIR}/sim_axi4.do" \
       -coverage -assertdebug -sv_seed random \
       -L work -L altera_mf -L altera_lnsim -L cycloneive -L lpm -L sgate -L altera \
       work.axi4_testbench | tee ${LOG_FILE}

  if [ $? -ne 0 ]; then
    echo "Error: QuestaSim AXI4 simulation failed!"
    exit 1
  fi

  echo "Generating AXI4 coverage report..."
  vcover report -html -output axi4_coverage_html -assert -directive -code bcsf ${COVERAGE_DB}
  vcover report -file ${COVERAGE_REPORT} -assert -directive -code bcsf ${COVERAGE_DB}
  echo "AXI4 coverage report generated: ${COVERAGE_REPORT} and axi4_coverage_html/"
}

function run_questa_mem {
  echo "Running Standalone Memory simulation with QuestaSim..."
  vsim -c -do "do ${SIM_DIR}/sim_mem.do" \
       -coverage -assertdebug -sv_seed random \
       -L work -L altera_mf -L altera_lnsim -L cycloneive -L lpm -L sgate -L altera \
       work.mem_tb_top | tee ${LOG_FILE}

  if [ $? -ne 0 ]; then
    echo "Error: QuestaSim Standalone Memory simulation failed!"
    exit 1
  fi

  echo "Generating Standalone Memory coverage report..."
  vcover report -html -output mem_coverage_html -assert -directive -code bcsf ${COVERAGE_DB}
  vcover report -file ${COVERAGE_REPORT} -assert -directive -code bcsf ${COVERAGE_DB}
  echo "Standalone Memory coverage report generated: ${COVERAGE_REPORT} and mem_coverage_html/"
}

function run_iverilog_axi4 {
  echo "Running AXI4 simulation with Icarus Verilog..."
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

  if [ $? -ne 0 ]; then
    echo "Error: Icarus Verilog AXI4 compilation failed!"
    exit 1
  fi

  vvp ${SIM_DIR}/sim.vvp | tee ${LOG_FILE}

  if [ $? -ne 0 ]; then
    echo "Error: Icarus Verilog AXI4 simulation failed!"
    exit 1
  fi
}

function run_iverilog_mem {
  echo "Running Standalone Memory simulation with Icarus Verilog..."
  iverilog -g2012 -o ${SIM_DIR}/sim.vvp \
    ${RTL_DIR}/axi4_memory.sv \
    ${MEM_STANDALONE_DIR}/memory_interface.sv \
    ${MEM_STANDALONE_DIR}/mem_transaction.sv \
    ${MEM_STANDALONE_DIR}/mem_checker.sv \
    ${MEM_STANDALONE_DIR}/mem_test.sv

  if [ $? -ne 0 ]; then
    echo "Error: Icarus Verilog Standalone Memory compilation failed!"
    exit 1
  fi

  vvp ${SIM_DIR}/sim.vvp | tee ${LOG_FILE}

  if [ $? -ne 0 ]; then
    echo "Error: Icarus Verilog Standalone Memory simulation failed!"
    exit 1
  fi
}

# --- Main Script ---

# Parse command line arguments
while getopts s:t: flag
do
    case "${flag}" in
        s) SIMULATOR=${OPTARG};;
        t) TEST_TYPE=${OPTARG};;
        *)
            echo "Usage: $0 [-s <simulator>] [-t <test_type>]"
            echo "  -s: Simulator (questa or iverilog, default: ${SIMULATOR})"
            echo "  -t: Test type (axi4 or mem, default: ${TEST_TYPE})"
            exit 1;;
    esac
done

clean_up

if [ "${SIMULATOR}" == "questa" ]; then
  if [ "${TEST_TYPE}" == "axi4" ]; then
    run_questa_axi4
  elif [ "${TEST_TYPE}" == "mem" ]; then
    run_questa_mem
  else
    echo "Error: Invalid test type for QuestaSim: ${TEST_TYPE}"
    exit 1
  fi
elif [ "${SIMULATOR}" == "iverilog" ]; then
  if [ "${TEST_TYPE}" == "axi4" ]; then
    run_iverilog_axi4
  elif [ "${TEST_TYPE}" == "mem" ]; then
    run_iverilog_mem
  else
    echo "Error: Invalid test type for Icarus Verilog: ${TEST_TYPE}"
    exit 1
  fi
else
  echo "Error: Unsupported simulator: ${SIMULATOR}"
  exit 1
fi

echo "Simulation completed successfully for ${TEST_TYPE} with ${SIMULATOR}."
