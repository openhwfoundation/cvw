#!/usr/bin/env -S uv run --script
# Madeleine Masser-Frye (mmmasserfrye@hmc.edu) 06/2022
import argparse
import csv
import os
import re
import subprocess
from collections import namedtuple

import matplotlib.lines as lines
import matplotlib.pyplot as plt
import numpy as np
from adjustText import adjust_text
from matplotlib import ticker
from matplotlib.cbook import flatten
from ppa.ppaAnalyze import noOutliers


def synthsintocsv():
    """writes a CSV with one line for every available synthesis
    each line contains the module, tech, width, target freq, and resulting metrics
    """
    print("This takes a moment...")
    bashCommand = "find . -path '*runs/wallypipelinedcore_*' -prune"
    output = subprocess.check_output(["bash", "-c", bashCommand])
    allSynths = output.decode("utf-8").split("\n")[:-1]

    specReg = re.compile("[a-zA-Z0-9]+")
    metricReg = re.compile(r"-?\d+\.\d+[e]?[-+]?\d*")

    with open("Summary.csv", "w") as file:
        writer = csv.writer(file)
        writer.writerow(["Width", "Config", "Mod", "Tech", "Target Freq", "Delay", "Area"])

        for oneSynth in allSynths:
            descrip = specReg.findall(oneSynth)
            #        print("From " + oneSynth + " Find ")
            #        for d in descrip:
            #            print(d)
            base = 4 if descrip[3] == "sram" else 3
            width = descrip[base][:4]
            config = descrip[base][4:]
            if descrip[base + 1][-2:] == "nm":
                mod = ""
            else:
                mod = descrip[base + 1]
                descrip = descrip[1:]
            tech = descrip[base + 1][:-2]
            freq = descrip[base + 2]
            #        print(width, config, mod, tech, freq)
            metrics = []
            for phrase in ["Path Slack", "Design Area"]:
                bashCommand = 'grep "{}" ' + oneSynth[2:] + "/reports/*qor*"
                bashCommand = bashCommand.format(phrase)
                #            print(bashCommand)
                try:
                    output = subprocess.check_output(["bash", "-c", bashCommand])
                    nums = metricReg.findall(str(output))
                    nums = [float(m) for m in nums]
                    metrics += nums
                except:
                    print(width + config + tech + "_" + freq + " doesn't have reports")
            if metrics == []:
                pass
            else:
                delay = 1000 / int(freq) - metrics[0]
                area = metrics[1]
                writer.writerow([width, config, mod, tech, freq, delay, area])


def synthsfromcsv(filename):
    Synth = namedtuple("Synth", "width config mod tech freq delay area")
    with open(filename, newline="") as csvfile:
        csvreader = csv.reader(csvfile)
        global allSynths
        allSynths = list(csvreader)[1:]
        for i in range(len(allSynths)):
            for j in range(len(allSynths[0])):
                try:
                    allSynths[i][j] = int(allSynths[i][j])
                except:
                    try:
                        allSynths[i][j] = float(allSynths[i][j])
                    except:
                        pass
            allSynths[i] = Synth(*allSynths[i])
    return allSynths


def freqPlot(tech, width, config):
    """plots delay, area for syntheses with specified tech, module, width"""

    freqsL, delaysL, areasL = ([[], []] for i in range(3))
    for oneSynth in allSynths:
        if (width == oneSynth.width) & (config == oneSynth.config) & (tech == oneSynth.tech) & (oneSynth.mod == "orig"):
            ind = 1000 / oneSynth.delay < (0.95 * oneSynth.freq)  # when delay is within target clock period
            freqsL[ind] += [oneSynth.freq]
            delaysL[ind] += [oneSynth.delay]
            areasL[ind] += [oneSynth.area]

    fig, (ax1, ax2) = plt.subplots(2, 1, sharex=True)
    allFreqs = list(flatten(freqsL))
    median = np.median(allFreqs) if allFreqs != [] else 0

    for ind in [0, 1]:
        areas = areasL[ind]
        delays = delaysL[ind]
        freqs = freqsL[ind]
        freqs, delays, areas = noOutliers(median, freqs, delays, areas)

        c = "blue" if ind else "gray"
        targs = [1000 / f for f in freqs]

        ax1.scatter(targs, delays, color=c)
        ax2.scatter(targs, areas, color=c)

    freqs = list(flatten(freqsL))
    delays = list(flatten(delaysL))
    areas = list(flatten(areasL))

    legend_elements = [lines.Line2D([0], [0], color="gray", ls="", marker="o", label="timing achieved"), lines.Line2D([0], [0], color="blue", ls="", marker="o", label="slack violated")]

    ax1.legend(handles=legend_elements)
    ytop = ax2.get_ylim()[1]
    ax2.set_ylim(ymin=0, ymax=1.1 * ytop)
    ax2.set_xlabel("Target Cycle Time (ns)")
    ax1.set_ylabel("Cycle Time Achieved (ns)")
    ax2.set_ylabel("Area (sq microns)")
    ax1.set_title(tech + " " + width + config)
    ax2.yaxis.set_major_formatter(ticker.StrMethodFormatter("{x:,.0f}"))
    addFO4axis(fig, ax1, tech)

    plt.savefig(final_directory + "/freqSweep_" + tech + "_" + width + config + ".png")


def areaDelay(tech, delays, areas, labels, fig, ax, norm=False):
    plt.subplots_adjust(left=0.18)

    fo4 = techdict[tech].fo4
    add32area = techdict[tech].add32area
    marker = techdict[tech].shape
    color = techdict[tech].color

    if norm:
        delays = [d / fo4 for d in delays]
        areas = [a / add32area for a in areas]

    plt.scatter(delays, areas, marker=marker, color=color)
    plt.xlabel("Cycle time (ns)")
    plt.ylabel("Area (sq microns)")
    ytop = ax.get_ylim()[1]
    plt.ylim(ymin=0, ymax=1.1 * ytop)

    ax.yaxis.set_major_formatter(ticker.StrMethodFormatter("{x:,.0f}"))

    if len(labels) > 0:
        texts = [plt.text(delays[i], areas[i], labels[i], ha="center", va="center") for i in range(len(labels))]
        adjust_text(texts)
    return fig


def plotFeatures(tech, width, config):
    delays, areas, labels = ([] for i in range(3))
    freq = techdict[tech].targfreq
    for oneSynth in allSynths:
        if (tech == oneSynth.tech) & (freq == oneSynth.freq) & (oneSynth.config == config) & (width == oneSynth.width):
            delays += [oneSynth.delay]
            areas += [oneSynth.area]
            labels += [oneSynth.mod]

    if delays == []:
        print("No delays found for tech ", tech, " freq ", freq, ". Did you set --sky130freq, --sky90freq and --tsmcfreq?\n")

    fig, (ax) = plt.subplots(1, 1)

    fig = areaDelay(tech, delays, areas, labels, fig, ax)

    titlestr = tech + "_" + width + config + "_" + str(freq) + "MHz"
    plt.title(titlestr)
    plt.savefig(final_directory + "/features_" + titlestr + ".png")


def plotConfigs(tech, mod=""):
    delays, areas, labels = ([] for i in range(3))
    freq = techdict[tech].targfreq
    for oneSynth in allSynths:
        if (tech == oneSynth.tech) & (freq == oneSynth.freq) & (oneSynth.mod == mod):
            delays += [oneSynth.delay]
            areas += [oneSynth.area]
            labels += [oneSynth.width + oneSynth.config]

    fig, (ax) = plt.subplots(1, 1)

    fig = areaDelay(tech, delays, areas, labels, fig, ax)

    titleStr = tech + "_" + mod
    plt.title(titleStr)
    plt.savefig(final_directory + "/configs_" + titleStr + ".png")


def normAreaDelay(mod=""):
    fig, (ax) = plt.subplots(1, 1)
    fullLeg = []
    for tech in list(techdict.keys()):
        delays, areas, labels = ([] for i in range(3))
        spec = techdict[tech]
        freq = spec.targfreq
        for oneSynth in allSynths:
            if (tech == oneSynth.tech) & (freq == oneSynth.freq) & (oneSynth.mod == mod):
                delays += [oneSynth.delay]
                areas += [oneSynth.area]
                labels += [oneSynth.width + oneSynth.config]
        areaDelay(tech, delays, areas, labels, fig, ax, norm=True)
        fullLeg += [lines.Line2D([0], [0], markerfacecolor=spec.color, label=tech, marker=spec.shape, markersize=10, color="w")]

    ax.set_title("Normalized Area & Cycle Time by Configuration")
    ax.set_xlabel("Cycle Time (FO4)")
    ax.set_ylabel("Area (add32)")
    ax.legend(handles=fullLeg, loc="upper left")
    plt.savefig(final_directory + "/normAreaDelay.png")


def addFO4axis(fig, ax, tech):
    fo4 = techdict[tech].fo4

    ax3 = fig.add_axes((0.125, 0.14, 0.775, 0.0))
    ax3.yaxis.set_visible(False)  # hide the yaxis

    fo4Range = [x / fo4 for x in ax.get_xlim()]
    dif = fo4Range[1] - fo4Range[0]
    for n in [0.02, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]:
        d = dif / n
        if d > 3 and d < 10:
            r = [int(x / n) for x in fo4Range]
            nsTicks = [round(x * n, 2) for x in range(r[0], r[1] + 1)]
            break
    new_tick_locations = [fo4 * float(x) for x in nsTicks]

    ax3.set_xticks(new_tick_locations)
    ax3.set_xticklabels(nsTicks)
    ax3.set_xlim(ax.get_xlim())
    ax3.set_xlabel("FO4 delays")
    plt.subplots_adjust(left=0.125, bottom=0.25, right=0.9, top=0.9)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-s130", "--sky130freq", type=int, default=500, help="Target frequency used for sky130 syntheses")
    parser.add_argument("-s90", "--sky90freq", type=int, default=1500, help="Target frequency used for sky90 syntheses")
    parser.add_argument("-t", "--tsmcfreq", type=int, default=5000, help="Target frequency used for tsmc28 syntheses")
    args = parser.parse_args()

    TechSpec = namedtuple("TechSpec", "color shape targfreq fo4 add32area add32lpower add32denergy")
    techdict = {}
    techdict["sky130"] = TechSpec("green", "o", args.sky130freq, 99.5e-3, 2581, 18, 0.685)
    techdict["sky90"] = TechSpec("gray", "o", args.sky90freq, 43.2e-3, 1440.600027, 714.057, 0.658023)
    techdict["tsmc28psyn"] = TechSpec("blue", "s", args.tsmcfreq, 12.2e-3, 209.286002, 1060.0, 0.081533)

    current_directory = os.getcwd()
    final_directory = os.path.join(current_directory, "wallyplots")
    if not os.path.exists(final_directory):
        os.makedirs(final_directory)

    synthsintocsv()
    synthsfromcsv("Summary.csv")
    freqPlot("tsmc28psyn", "rv32", "e")
    freqPlot("sky90", "rv32", "e")
    freqPlot("sky130", "rv32", "e")
    plotFeatures("sky90", "rv64", "gc")
    plotFeatures("sky130", "rv64", "gc")
    plotFeatures("tsmc28psyn", "rv64", "gc")
    plotConfigs("sky90", mod="orig")
    plotConfigs("sky130", mod="orig")
    plotConfigs("tsmc28psyn", mod="orig")
    normAreaDelay(mod="orig")
    os.system("./extractArea.pl")
