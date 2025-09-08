# Top-level Verilog module name (without file extension)
filename := top

# Physical constraints file (Pin mapping for FPGA)
pcf_file := ./io.pcf

# FPGA device parameters
DEVICE   := lp1k      # iCE40 device family (low-power 1K)
PKG      := cm36      # Package (36-pin)
FREQ     := 48        # Target frequency for P&R (MHz)

# Verilog source files (all .v files in current directory)
SOURCES  := ./*.v ../../lib/uart/*.v ../../lib/bram/*.v

# Detect iCELink mount path (for flashing)
ICELINK_DIR := $(shell df | grep iCELink | awk '{print $$6}')
$(warning iCELink path: $(ICELINK_DIR))

# Default target: build .bin file
all: $(filename).bin

# --------------------------------------------------------------------
# Step 1: Synthesis (single run)
# - read_verilog -defer: Load all .v sources, allow forward references
# - hierarchy -top: Set the top module
# - synth_ice40 -top: Map for iCE40 architecture
# - write_json:  Netlist for nextpnr
# - write_blif:  Optional legacy/inspection netlist
# NOTE: Multi-target rule builds BOTH json & blif in one Yosys run.
# --------------------------------------------------------------------
$(filename).json $(filename).blif: $(SOURCES)
	yosys -p "\
		read_verilog -defer $(SOURCES); \
		hierarchy -top $(filename); \
		synth_ice40 -top $(filename); \
		write_json $(filename).json; \
		write_blif $(filename).blif \
	"

# --------------------------------------------------------------------
# Step 2: Place & Route (nextpnr-ice40)
# - --$(DEVICE): Target device
# - --package:   Package name
# - --json:      Input netlist from Yosys
# - --pcf:       Pin constraints
# - --asc:       Output ASCII bitstream
# - --freq:      Timing target (MHz)
# --------------------------------------------------------------------
$(filename).asc: $(filename).json $(pcf_file)
	nextpnr-ice40 \
		--$(DEVICE) \
		--package $(PKG) \
		--json $< \
		--pcf $(pcf_file) \
		--asc $@ \
		--freq $(FREQ) \
		--log $(filename).log

# --------------------------------------------------------------------
# Step 3: Pack the ASCII bitstream into a binary file
# --------------------------------------------------------------------
$(filename).bin: $(filename).asc
	icepack $< $@

# --------------------------------------------------------------------
# Flash the bitstream to iCELink (if mounted)
# --------------------------------------------------------------------
prog_flash: $(filename).bin
	@if [ -d '$(ICELINK_DIR)' ]; then \
		cp $< $(ICELINK_DIR); \
		echo "Copied to: $(ICELINK_DIR)"; \
	else \
		echo "iCELink not found"; \
		exit 1; \
	fi

# --------------------------------------------------------------------
# Clean build artifacts
# --------------------------------------------------------------------
clean:
	rm -f $(filename).json $(filename).blif $(filename).asc $(filename).bin $(filename).log

.PHONY: all clean prog_flash
