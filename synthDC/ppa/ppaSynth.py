#!/usr/bin/env -S uv run --script
#
# Python regression test for DC
# Madeleine Masser-Frye mmasserfrye@hmc.edu 5/22
# James Stine james.stine@okstate.edu 15 October 2023
#

import re
import subprocess
from multiprocessing import Pool

from ppaAnalyze import synthsfromcsv


def runCommand(module, width, tech, freq):
    command = f"make synth DESIGN={module} WIDTH={width} TECH={tech} DRIVE=INV FREQ={freq} MAXOPT=1 MAXCORES=1"
    subprocess.call(command, shell=True)

def deleteRedundant(synthsToRun):
    '''removes any previous runs for the current synthesis specifications'''
    synthStr = "rm -rf runs/{}_{}_rv32e_{}_{}_*"
    for synth in synthsToRun:
        bashCommand = synthStr.format(*synth)
        subprocess.check_output(['bash','-c', bashCommand])

def freqSweep(module, width, tech):
    synthsToRun = []
    arr = [-8, -6, -4, -2, 0, 2, 4, 6, 8]
    allSynths = synthsfromcsv('ppa/bestSynths.csv')
    for synth in allSynths:
        if (synth.module == module) & (synth.tech == tech) & (synth.width == width):
            f = 1000/synth.delay
            for freq in [round(f+f*x/100) for x in arr]:
                synthsToRun += [[synth.module, str(synth.width), synth.tech, str(freq)]]
    return synthsToRun

def freqModuleSweep(widths, modules, tech):
    synthsToRun = []
    arr = [-8, -6, -4, -2, 0, 2, 4, 6, 8]
    allSynths = synthsfromcsv('ppa/bestSynths.csv')
    for w in widths:
        for module in modules:
            for synth in allSynths:
                if (synth.module == str(module)) & (synth.tech == tech) & (synth.width == w):
                    f = 1000/synth.delay
                    for freq in [round(f+f*x/100) for x in arr]:
                        synthsToRun += [[synth.module, str(synth.width), synth.tech, str(freq)]]
    return synthsToRun

def filterRedundant(synthsToRun):
    bashCommand = "find . -path '*runs/*' -prune"
    output = subprocess.check_output(['bash','-c', bashCommand])
    specReg = re.compile('[a-zA-Z0-9]+')
    allSynths = output.decode("utf-8").split('\n')[:-1]
    allSynths = [specReg.findall(oneSynth)[2:7] for oneSynth in allSynths]
    allSynths = [oneSynth[0:2] + [oneSynth[3][:-2]] + [oneSynth[4]] for oneSynth in allSynths]
    output = []
    for synth in synthsToRun:
        if (synth not in allSynths):
            output += [synth]
    return output

def allCombos(widths, modules, techs, freqs):
    synthsToRun = []
    for w in widths:
        for module in modules:
            for tech in techs:
                for freq in freqs:
                    synthsToRun += [[module, str(w), tech, str(freq)]]
    return synthsToRun


if __name__ == '__main__':

    ##### Run specific syntheses for a specific frequency
    widths = [8, 16, 32, 64, 128]
    modules = ['mul', 'adder', 'shifter', 'flop', 'comparator', 'binencoder', 'csa', 'mux2', 'mux4', 'mux8']
    techs = ['sky90', 'sky130', 'tsmc28', 'tsmc28psyn']
    freqs = [5000]
    synthsToRun = allCombos(widths, modules, techs, freqs)

    ##### Run a sweep based on best delay found in existing syntheses
    module = 'adder'
    width = 32
    tech = 'tsmc28psyn'
    synthsToRun = freqSweep(module, width, tech)

    ##### Run a sweep for multiple modules/widths based on best delay found in existing syntheses
    modules = ['adder']
    # widths = [8, 16, 32, 64, 128]
    widths = [32]
    tech = 'sky130'
    synthsToRun = freqModuleSweep(widths, modules, tech)

    ##### Only do syntheses for which a run doesn't already exist
    synthsToRun = filterRedundant(synthsToRun)
    pool = Pool(processes=25)

pool.starmap(runCommand, synthsToRun)
pool.close()
pool.join()
