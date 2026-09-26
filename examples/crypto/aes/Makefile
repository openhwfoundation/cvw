CC = gcc
CFLAGS = -g

RISCV_CC = riscv64-unknown-elf-gcc
RISCV_OBJDUMP = riscv64-unknown-elf-objdump
COMMON_DIR = ../../C/common
RISCV_CFLAGS = -gdwarf-2 -march=rv64gc -mabi=lp64d -mcmodel=medany \
		-nostdlib -static -lm -fno-tree-loop-distribute-patterns \
		-nostartfiles -T$(COMMON_DIR)/test.ld -I$(COMMON_DIR)

TARGET = aes

.PHONY: all clean $(TARGET) $(TARGET).elf $(TARGET).objdump

all: $(TARGET) $(TARGET).elf $(TARGET).objdump

$(TARGET): $(TARGET).c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGET) $(TARGET).elf $(TARGET).objdump *~
