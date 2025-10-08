# Makefile for eth_mac_lite cocotb testbench

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# --- Final Corrected Verilog Sources ---

# Project root directory, which is one level up from this Makefile's location
PROJ_DIR = $(abspath $(PWD)/..)

# Read the filelist, filter out comments AND blank lines, then prepend the project directory path
# This is the robust way to handle the file list.
VERILOG_SOURCES := $(shell grep -vE '^\s*(#|$$)' $(PROJ_DIR)/filelist.txt | sed "s|^|$(PROJ_DIR)/|")

# TOPLEVEL is the name of the toplevel module in your Verilog
TOPLEVEL = eth_mac_lite

# MODULE is the name of the Python test file
MODULE = test_eth_mac_lite

# include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim