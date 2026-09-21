TARGET = mei

$(TARGET).objdump: $(TARGET).elf
	riscv64-unknown-elf-objdump -D $(TARGET).elf > $(TARGET).objdump

%.elf: %.S Makefile
	riscv64-unknown-elf-gcc -g -o $@ -march=rv64gc -mabi=lp64 -mcmodel=medany \
	    -nostartfiles -Tlink.ld $<

sim:
	spike -d +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET).elf
	diff --ignore-case $(TARGET).signature.output $(TARGET).reference_output || exit
	echo "Signature matches! Success!"

wally:
	wsim rv64gc --elf $(TARGET).elf --lockstepverbose

clean:
	rm -f $(TARGET).elf *.objdump* *.signature.output *.elf* *.memfile
