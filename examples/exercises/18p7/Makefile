TARGET = sha256

$(TARGET).objdump: $(TARGET)
	riscv64-unknown-elf-objdump -D $(TARGET) > $(TARGET).objdump

$(TARGET): $(TARGET).S Makefile
	riscv64-unknown-elf-gcc -g -o $(TARGET) -march=rv32gc_zk -mabi=ilp32 -mcmodel=medany \
	    -nostartfiles -T../../link/link.ld $(TARGET).S
sim:
	spike --isa=rv32gc_zicsr_zicntr_zk +signature=$(TARGET).signature.output +signature-granularity=4 $(TARGET)
	diff --ignore-case $(TARGET).signature.output $(TARGET).reference_output || exit
	echo "Signature matches! Success!"

clean:
	rm -f $(TARGET) $(TARGET).objdump $(TARGET).signature.output
	rm -f *~
