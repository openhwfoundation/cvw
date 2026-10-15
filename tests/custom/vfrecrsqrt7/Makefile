# Standalone Verilator unit test for src/vpu/vfrecrsqrt7.sv.
# Run with: make (requires $WALLY to be set, e.g. `source setup.sh`)

TOP      = tb_vfrecrsqrt7
WKDIR    = wkdir
RESULTS  = results
CONFIG   = rv64gc
INCLUDE  = -I$(WALLY)/config/shared -I$(WALLY)/config/$(CONFIG)
SRCS     = $(WALLY)/src/cvw.sv $(WALLY)/src/fpu/unpackinput.sv \
           $(WALLY)/src/vpu/vfrecrsqrt7.sv $(WALLY)/src/generic/lzc.sv $(TOP).sv wrapper.c

# $(RESULTS) is wiped and recreated on every run (not just on rebuild) so old
# logs never linger: results/vfrecrsqrt7.log has one PASS/FAIL line per check.
sim: $(WKDIR)/$(TOP)
	@rm -rf $(RESULTS)
	@mkdir -p $(RESULTS)
	@WALLY=$(WALLY) $(WKDIR)/$(TOP)

$(WKDIR)/$(TOP): $(SRCS)
	verilator --binary --timing -j 0 \
	  -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
	  $(INCLUDE) $(SRCS) --top-module $(TOP) -o $(TOP) --Mdir $(WKDIR)

clean:
	rm -rf $(WKDIR) $(RESULTS)

.PHONY: sim clean
