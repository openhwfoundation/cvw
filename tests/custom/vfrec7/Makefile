# Standalone Verilator unit test for src/vpu/vfrec7/.
# Run with: make (requires $WALLY to be set, e.g. `source setup.sh`)

TOP      = tb_vfrec7
WKDIR    = wkdir
CONFIG   = rv64gc
INCLUDE  = -I$(WALLY)/config/shared -I$(WALLY)/config/$(CONFIG)
SRCS     = $(WALLY)/src/cvw.sv $(WALLY)/src/fpu/unpackinput.sv \
           $(WALLY)/src/vpu/vfrec7/*.sv $(WALLY)/src/generic/lzc.sv $(TOP).sv wrapper.c

sim: $(WKDIR)/$(TOP)
	@WALLY=$(WALLY) $(WKDIR)/$(TOP)

$(WKDIR)/$(TOP): $(SRCS)
	verilator --binary --timing -j 0 \
	  -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	  $(INCLUDE) $(SRCS) --top-module $(TOP) -o $(TOP) --Mdir $(WKDIR)

clean:
	rm -rf $(WKDIR)

.PHONY: sim clean
