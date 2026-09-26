#!/usr/bin/env -S uv run --script
# Madeleine Masser-Frye mmasserfrye@hmc.edu 1/2023

import argparse
import subprocess
from multiprocessing import Pool


def runSynth(config, mod, tech, freq, maxopt, usesram):
    global pool
    prefix = "syn_sram_" if usesram else "syn_"
    cfg = prefix + config
    command = f"make synth DESIGN=wallypipelinedcore CONFIG={cfg} MOD={mod} TECH={tech} DRIVE=FLOP FREQ={freq} MAXOPT={maxopt} USESRAM={usesram} MAXCORES=1"
    pool.map(mask, [command])

def mask(command):
    subprocess.Popen(command, shell=True)


if __name__ == '__main__':

    techs = ['sky130', 'sky90', 'tsmc28', 'tsmc28psyn']
    allConfigs = ['rv32gc', 'rv32imc', 'rv64gc', 'rv64imc', 'rv32e', 'rv32i', 'rv64i']
    freqVaryPct = [-20, -12, -8, -6, -4, -2, 0, 2, 4, 6, 8, 12, 20]
#    freqVaryPct = [-20, -10, 0, 10, 20]

    pool = Pool()

    parser = argparse.ArgumentParser()

    parser.add_argument("-s", "--freqsweep", type=int, help = "Synthesize wally with target frequencies at given MHz and +/- 2, 4, 6, 8 %%")
    parser.add_argument("-c", "--configsweep", action='store_true', help = "Synthesize wally with configurations 32e, 32imc, 64ic, 32gc, and 64gc")
    parser.add_argument("-f", "--featuresweep", action='store_true', help = "Synthesize wally with features turned off progressively to visualize critical path")

    parser.add_argument("-v", "--version", choices=allConfigs, help = "Configuration of wally")
    parser.add_argument("-t", "--targetfreq", type=int, help = "Target frequency")
    parser.add_argument("-e", "--tech", choices=techs, help = "Technology")
    parser.add_argument("-o", "--maxopt", action='store_true', help = "Turn on MAXOPT")
    parser.add_argument("-r", "--usesram", action='store_true', help = "Use SRAM modules")

    args = parser.parse_args()

    tech = args.tech if args.tech else 'sky90'
    maxopt = int(args.maxopt)
    usesram = int(args.usesram)
    mod = 'orig'

    if args.freqsweep:
        sc = args.freqsweep
        config = args.version if args.version else 'rv32e'
        for freq in [round(sc+sc*x/100) for x in freqVaryPct]: # rv32e freq sweep
            runSynth(config, mod, tech, freq, maxopt, usesram)
    elif args.configsweep:
        defaultfreq = 1500 if tech == 'sky90' else 5000
        freq = args.targetfreq if args.targetfreq else defaultfreq
        for config in ['rv32i', 'rv64gc', 'rv64i', 'rv32gc', 'rv32imc', 'rv32e']: #configs
            runSynth(config, mod, tech, freq, maxopt, usesram)
    elif args.featuresweep:
        defaultfreq = 500 if tech == 'sky90' else 1500
        freq = args.targetfreq if args.targetfreq else defaultfreq
        config = args.version if args.version else 'rv64gc'
        for mod in ['noAtomic', 'noFPU', 'noMulDiv', 'noPriv', 'pmp0']:
            runSynth(config, mod, tech, freq, maxopt, usesram)
    else:
        defaultfreq = 500 if tech == 'sky90' else 1500
        freq = args.targetfreq if args.targetfreq else defaultfreq
        config = args.version if args.version else 'rv64gc'
        runSynth(config, mod, tech, freq, maxopt, usesram)
