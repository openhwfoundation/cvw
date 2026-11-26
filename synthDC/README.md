# Synthesis for RISC-V Microprocessor System-on-Chip Design

This subdirectory contains synthesis scripts for use with Synopsys
(snps) Design Compiler (DC).  Synthesis commands are found in
`scripts/synth.tcl`.

## Example Usage
```bash
make synth DESIGN=cvw_wallypipelinedcore FREQ=500 CONFIG=rv32e
```

## Environment Variables

- `DESIGN`
  - Design provides the name of the output log.  Default is synth.
- `FREQ`
  - Frequency in MHz.  Default is 500
- `CONFIG`
  - The Wally configuration file.  The default is rv32e.
  - Examples: rv32e, rv64gc, rv32gc
- `TECH`
  - The target standard cell library.  The default is sky130.
  - Options:
    - sky90: skywater 90nm TT 25C
    - sky130: skywater 130nm TT 25C
- `SAIFPOWER`
  - Controls if power analysis is driven by switching factor or RTL modelsim simulation. When enabled requires a saif file named power.saif.  The default is 0.
  - Options:
    - 0: switching factor power analysis
    - 1: RTL simulation driven power analysis.

## Extra Tool (PPA)

To run ppa analysis that hones into target frequency, you can type:
`python3 ppa/ppaSynth.py` from the synthDC directory.  This runs a sweep
across all modules listed at the bottom of the `ppaSynth.py` file.

Two options for running the sweep.  The first run runs all modules for
all techs around a given frequency (i.e., freqs).  The second option
will run all designs for the specific module based on bestSynths.csv
values.   Since the second option is 2nd, it has priority.  If the
second set of values is commented out, it will run all widths.

**WARNING:** The first option may runs lots of runs that could expend all the licenses available for a license.  Therefore, care must be taken to be sure that enough licenses are available for this first option.

### Run specific syntheses
```python
widths = [8, 16, 32, 64, 128]
modules = ['mul', 'adder', 'shifter', 'flop', 'comparator', 'binencoder', 'csa', 'mux2', 'mux4', 'mux8']
techs = ['sky90', 'sky130', 'tsmc28', 'tsmc28psyn']
freqs = [5000]
synthsToRun = allCombos(widths, modules, techs, freqs)
```

### Run a sweep based on best delay found in existing syntheses
```python
module = 'adder'
width = 32
tech = 'tsmc28psyn'
synthsToRun = freqSweep(module, width, tech)
```
