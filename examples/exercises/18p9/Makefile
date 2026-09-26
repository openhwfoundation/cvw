TARGET = aes

$(TARGET).objdump: $(TARGET)
	riscv64-unknown-elf-objdump -S -D $(TARGET) > $(TARGET).objdump
	spike $(TARGET)

$(TARGET): $(TARGET).c Makefile
	riscv64-unknown-elf-gcc -o $(TARGET) -gdwarf-2 -O3\
	  -march=rv64gc -mabi=lp64d -mcmodel=medany \
	  -nostdlib -static -lm -fno-tree-loop-distribute-patterns \
	  -T../../C/common/test.ld -I../../C/common \
	  $(TARGET).c ../../C/common/crt.S ../../C/common/syscalls.c

clean:
	rm -f $(TARGET) $(TARGET).objdump
	rm -f *~
