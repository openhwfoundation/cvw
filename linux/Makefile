BUILDROOT_VERSION := 2026.02.x

BUILDROOT         := buildroot
IMAGE_DIR         := ${BUILDROOT}/output/images
DISASSEMBLY_DIR   := ${IMAGE_DIR}/disassembly
WALLYLINUX        := $(WALLY)/linux
BR2_EXTERNAL_TREE := $(WALLYLINUX)/br2-external-tree
LINUX_TESTVECTORS := $(RISCV)/linux-testvectors

BUILDROOT_OUTPUTS := Image fw_jump.bin fw_jump.elf rootfs.cpio vmlinux busybox
BUILDROOT_OUTPUTS := $(foreach name, $(BUILDROOT_OUTPUTS), $(IMAGE_DIR)/$(name))

# Device tree files
DTS ?= $(wildcard devicetree/*.dts)
DTB := $(foreach name, $(DTS:%.dts=%.dtb), $(IMAGE_DIR)/$(notdir $(name)))

# Disassembly files
BINARIES := fw_jump.elf vmlinux busybox
OBJDUMPS := $(foreach name, $(basename $(BINARIES) .elf), $(DISASSEMBLY_DIR)/$(name).objdump)

# Testvector files
RAW_RAM_FILE     := ${LINUX_TESTVECTORS}/ramGDB.bin
RAM_FILE         := ${LINUX_TESTVECTORS}/ram.bin
RAW_BOOTMEM_FILE := ${LINUX_TESTVECTORS}/bootmemGDB.bin
BOOTMEM_FILE     := ${LINUX_TESTVECTORS}/bootmem.bin

.PHONY: all check_environment check_write_permissions config build disassemble devicetrees install dumptvs clean cleanDTB

# Default target
all: check_write_permissions clean config build disassemble install dumptvs

# Check if the environment variables are set correctly
check_environment: $(RISCV) $(WALLY)
ifeq ($(findstring :$(RISCV)/lib:,:$(LD_LIBRARY_PATH):),)
	@(echo "ERROR: Your environment variables are not set correctly." >&2 \
	&& echo "Make sure to source setup.sh or install buildroot using the wally-tool-chain-install.sh script." >&2 \
	&& exit 1)
endif

# Check if the user has write permissions to the RISCV directory, potentially using sudo
SUDO := $(shell mkdir -p $(RISCV)/.test > /dev/null 2>&1 || echo sudo)
check_write_permissions: check_environment
ifeq ($(SUDO), sudo)
	@echo "Cannot write to '$(RISCV)'." \
		"Using sudo (you may be prompted for your password several times throughout the install)"
endif
	@$(SUDO) mkdir -p $(RISCV)/.test || \
		(echo "ERROR: Still unable to write to '$(RISCV)'." >&2 \
		&& exit 1)
	@$(SUDO) rm -r $(RISCV)/.test

# Build buildroot and device tree binaries
build: $(BUILDROOT_OUTPUTS) devicetrees

# Build buildroot itself
# LD_LIBRARY_PATH must be unset to avoid conflicts between the host and cross compiler
$(BUILDROOT_OUTPUTS) $(IMAGE_DIR): check_environment $(BUILDROOT)
	bash -c "unset LD_LIBRARY_PATH; $(MAKE) -C $(BUILDROOT)"

# Install buildroot to $RISCV
install: check_write_permissions
	$(SUDO) rm -rf $(RISCV)/$(BUILDROOT)
	$(SUDO) mv $(BUILDROOT) $(RISCV)/$(BUILDROOT)

# Generate linux boot testvectors
dumptvs: ${RAM_FILE} ${BOOTMEM_FILE}

# Format QEMU memory dumps for use as testvectors
${LINUX_TESTVECTORS}/%.bin: ${LINUX_TESTVECTORS}/%GDB.bin
	truncate -s %8 $^ # Extend file to 8 byte multiple
	objcopy --reverse-bytes=8 -F binary $^ $@ # Reverse bytes

# Generate memory dumps from QEMU buildroot boot
TCP_PORT := 1235
${LINUX_TESTVECTORS}/%GDB.bin: | $(LINUX_TESTVECTORS)
	${WALLYLINUX}/qemuBoot.sh --gdb ${TCP_PORT} &
	riscv64-unknown-elf-gdb -batch \
		-ex "target remote :${TCP_PORT}" \
		-ex "maintenance packet Qqemu.PhyMemMode:1" \
		-ex "printf \"Creating ${RAW_BOOTMEM_FILE}\n\"" \
		-ex "dump binary memory ${RAW_BOOTMEM_FILE} 0x1000 0x1fff" \
		-ex "printf \"Creating ${RAW_RAM_FILE}\n\"" \
		-ex "dump binary memory ${RAW_RAM_FILE} 0x80000000 0x8fffffff" \
		-ex "kill"

# Generate device tree binaries
devicetrees: $(DTB)
$(IMAGE_DIR)/%.dtb: ${WALLYLINUX}/devicetree/%.dts | $(IMAGE_DIR)
	dtc -I dts -O dtb $< > $@

# Create disassembly files
disassemble: check_environment $(OBJDUMPS) $(DISASSEMBLY_DIR)/rootfs

# Extract rootfs
$(DISASSEMBLY_DIR)/rootfs: $(IMAGE_DIR)/rootfs.cpio
	@echo "Ignore error about dev/console when extracting rootfs from rootfs.cpio"
	-cpio -id -D $(DISASSEMBLY_DIR)/rootfs -F $(IMAGE_DIR)/rootfs.cpio

# Disassemble binaries
$(DISASSEMBLY_DIR)/%.objdump: $(IMAGE_DIR)/% | $(DISASSEMBLY_DIR)
	riscv64-unknown-elf-objdump -S $< >> $@
	$(WALLY)/bin/extractFunctionRadix.sh $@

# Disassemble binaries ending in .elf
# Add -D flag back to disassemble all sections (instead of just code sections)
# once objdump bug is fixed and the pinned version of the toolchain is updated.
$(DISASSEMBLY_DIR)/%.objdump: $(IMAGE_DIR)/%.elf | $(DISASSEMBLY_DIR)
	riscv64-unknown-elf-objdump -S $< >> $@
	$(WALLY)/bin/extractFunctionRadix.sh $@

# Load wally buildroot configuration
config: $(BUILDROOT) $(BR2_EXTERNAL_TREE)/configs/wally_defconfig
	$(MAKE) -C $(BUILDROOT) wally_defconfig BR2_EXTERNAL=$(BR2_EXTERNAL_TREE)

# Clone buildroot and checkout the correct version
$(BUILDROOT):
	git clone https://github.com/buildroot/buildroot.git $@
	cd $@; git checkout $(BUILDROOT_VERSION)

# Create directories
$(LINUX_TESTVECTORS): check_write_permissions
	$(SUDO) mkdir -p $@

$(DISASSEMBLY_DIR):
	mkdir -p $@

# Remove device tree binaries
cleanDTB:
	rm -f $(IMAGE_DIR)/*.dtb

# Remove buildroot directory
clean:
	rm -rf $(BUILDROOT)

# Check if the RISCV environment variable is set
$(RISCV):
	@ echo "ERROR: No $(RISCV) directory. Make sure you have installed the Wally Toolchain."
	@ echo "and sourced setup.sh"

# Check if the WALLY environment variable is set
$(WALLY):
	@ echo "ERROR: $$WALLY is not set. Make sure you have sourced setup.sh"
