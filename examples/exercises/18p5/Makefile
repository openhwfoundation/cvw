TARGET = gf_inv

$(TARGET).objdump: $(TARGET)
	riscv64-unknown-elf-objdump -D $(TARGET) > $(TARGET).objdump

$(TARGET): $(TARGET).S Makefile
	riscv64-unknown-elf-gcc -g -o $(TARGET) -march=rv32gc -mabi=ilp32 -mcmodel=medany \
	    -nostartfiles -nostdlib -T../../link/link.ld $(TARGET).S

sim:
	spike --isa=rv32gc_zicsr_zicntr +signature=$(TARGET).signature.output +signature-granularity=4 $(TARGET)
	diff --ignore-case $(TARGET).signature.output $(TARGET).reference_output || exit
	echo "Signature matches! Success!"

clean:
	rm -f $(TARGET) $(TARGET).objdump $(TARGET).signature.output
	rm -f *~
