# synth/Makefile
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26

WORK_DIR 		?= $(CURDIR)/work

SYNTH_TECH 		?= sky130

PROCESSOR_DIR   ?= $(CURDIR)/sample_processor/src
INC_DIR       	?= $(CURDIR)/sample_processor/incdir

SYNTH_TOP 		?= riscvsingle
SYNTH_FILES 	?=
LIB_FILES 		?=

PROCESSOR_TOP 	?= riscvsingle

SYNTH_MAKE_FLAGS 	?= \
	OUTPUTBASEDIR=$(WORK_DIR) \
	NAME=lynn \
	DESIGN=$(SYNTH_TOP) \
	SYNTH_FILES=$(SYNTH_FILES) \
	LIB_FILES=$(LIB_FILES) \
	PROCESSORTOP=$(PROCESSOR_TOP) \
	INCDIR=$(INC_DIR) \
	CONFIG=- \
	MOD=- \
	HDLDIR=$(PROCESSOR_DIR) \
	LYNN=1 \
	TECH=$(SYNTH_TECH)

all: synth

.PHONY: synth
synth:
	@mkdir -p $(WORK_DIR)
	@$(MAKE) -C $(WALLY)/synthDC $(SYNTH_MAKE_FLAGS) synth

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
