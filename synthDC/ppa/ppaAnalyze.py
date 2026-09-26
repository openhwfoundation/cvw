#!/usr/bin/env -S uv run --script
#
# Python regression test for DC
# Madeleine Masser-Frye mmasserfrye@hmc.edu 5/22
# James Stine james.stine@okstate.edu 15 October 2023

import csv
import os
import re
import subprocess
from collections import namedtuple

import matplotlib as mpl
import matplotlib.lines as lines
import matplotlib.pyplot as plt
import numpy as np
import scipy.optimize as opt
import sklearn.metrics as skm  # deprecated, will need to replace with scikit-learn
from matplotlib.cbook import flatten


def synthsfromcsv(filename):
    Synth = namedtuple("Synth", "module tech width freq delay area lpower denergy")
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


def synthsintocsv():
    """writes a CSV with one line for every available synthesis
    each line contains the module, tech, width, target freq, and resulting metrics
    """
    print("This takes a moment...")
    bashCommand = "find . -path '*runs/*' -prune"
    output = subprocess.check_output(["bash", "-c", bashCommand])
    allSynths = output.decode("utf-8").split("\n")[:-1]

    specReg = re.compile("[a-zA-Z0-9]+")
    metricReg = re.compile(r"-?\d+\.\d+[e]?[-+]?\d*")

    with open("ppaData.csv", "w") as file:
        writer = csv.writer(file)
        writer.writerow(
            [
                "Module",
                "Tech",
                "Width",
                "Target Freq",
                "Delay",
                "Area",
                "L Power (nW)",
                "D energy (nJ)",
            ]
        )

        for oneSynth in allSynths:
            module, width, risc, tech, freq = specReg.findall(oneSynth)[1:6]
            tech = tech[:-2]
            metrics = []
            for phrase in [["Path Slack", "qor"], ["Design Area", "qor"], ["100", "power"]]:
                bashCommand = 'grep "{}" ' + oneSynth[2:] + "/reports/*{}*"
                bashCommand = bashCommand.format(*phrase)
                try:
                    output = subprocess.check_output(["bash", "-c", bashCommand])
                except:
                    print(module + width + tech + freq + " doesn't have reports")
                    print("Consider running cleanup() first")
                nums = metricReg.findall(str(output))
                nums = [float(m) for m in nums]
                metrics += nums
            delay = 1000 / int(freq) - metrics[0]
            area = metrics[1]
            lpower = metrics[4]
            tpower = metrics[2] + metrics[3] + metrics[4] * 0.000001
            denergy = (tpower) / int(freq) * 1000  # (switching + internal powers)*delay, more practical units for regression coefs

            if "flop" in module:  # since two flops in each module
                [area, lpower, denergy] = [n / 2 for n in [area, lpower, denergy]]

            writer.writerow([module, tech, width, freq, delay, area, lpower, denergy])


def cleanup():
    """removes runs that didn't work"""
    bashCommand = 'grep -r "Error" runs/ppa*/reports/*qor*'
    try:
        output = subprocess.check_output(["bash", "-c", bashCommand])
        allSynths = output.decode("utf-8").split("\n")[:-1]
        for run in allSynths:
            run = run.split("MHz")[0]
            bc = "rm -r " + run + "*"
            output = subprocess.check_output(["bash", "-c", bc])
    except:
        pass

    bashCommand = "find . -path '*runs/*' -prune"
    output = subprocess.check_output(["bash", "-c", bashCommand])
    allSynths = output.decode("utf-8").split("\n")[:-1]
    for oneSynth in allSynths:
        for phrase in [["Path Length", "qor"]]:
            bashCommand = 'grep "{}" ' + oneSynth[2:] + "/reports/*{}*"
            bashCommand = bashCommand.format(*phrase)
            try:
                output = subprocess.check_output(["bash", "-c", bashCommand])
            except:
                bc = "rm -r " + oneSynth[2:]
                output = subprocess.check_output(["bash", "-c", bc])
    print("All cleaned up!")


def getVals(tech, module, var, freq=None, width=None):
    """for a specified tech, module, and variable/metric
    returns a list of values for that metric in ascending width order
    works at a specified target frequency or if none is given, uses the synthesis with the best achievable delay for each width
    """

    widthsToGet = width if width is not None else widths

    metric = []
    widthL = []

    if freq is not None:
        for oneSynth in allSynths:
            if (oneSynth.freq == freq) & (oneSynth.tech == tech) & (oneSynth.module == module) & (oneSynth.width != 1):
                widthL += [oneSynth.width]
                osdict = oneSynth._asdict()
                metric += [osdict[var]]
        metric = [x for _, x in sorted(zip(widthL, metric))]  # ordering
    else:
        for w in widthsToGet:
            for oneSynth in bestSynths:
                if (oneSynth.width == w) & (oneSynth.tech == tech) & (oneSynth.module == module):
                    osdict = oneSynth._asdict()
                    met = osdict[var]
                    metric += [met]
    return metric


def csvOfBest(filename):
    bestSynths = []
    for tech in [x.tech for x in techSpecs]:
        for mod in modules:
            for w in widths:
                m = np.Inf  # large number to start
                best = None
                for oneSynth in allSynths:  # best achievable, rightmost green
                    if (oneSynth.width == w) & (oneSynth.tech == tech) & (oneSynth.module == mod):
                        if (oneSynth.delay < m) & (1000 / oneSynth.delay > oneSynth.freq):
                            m = oneSynth.delay
                            best = oneSynth

                if (best is not None) & (best not in bestSynths):
                    bestSynths += [best]

    with open(filename, "w") as file:
        writer = csv.writer(file)
        writer.writerow(
            [
                "Module",
                "Tech",
                "Width",
                "Target Freq",
                "Delay",
                "Area",
                "L Power (nW)",
                "D energy (nJ)",
            ]
        )
        for synth in bestSynths:
            writer.writerow(list(synth))
    return bestSynths


def genLegend(fits, coefs, r2=None, spec=None, ale=False):
    """generates a list of two legend elements (or just an equation if no r2 or spec)
    labels line with fit equation and dots with r squared of the fit
    """

    coefsr = [str(sigfig(c, 2)) for c in coefs]
    if ale:
        if normAddWidth == 32:
            sub = "S"
        elif normAddWidth != 1:
            print("Equations are wrong, check normAddWidth")
    else:
        sub = "N"

    eqDict = {
        "c": "",
        "l": sub,
        "s": "$" + sub + "^2$",
        "g": "$log_2$(" + sub + ")",
        "n": "" + sub + "$log_2$(" + sub + ")",
    }
    eq = ""
    ind = 0

    for k in eqDict:
        if k in fits:
            if str(coefsr[ind]) != "0":
                eq += " + " + coefsr[ind] + eqDict[k]
            ind += 1

    eq = eq[3:]  # chop off leading ' + '

    if (r2 is None) or (spec is None):
        return eq
    else:
        legend_elements = [lines.Line2D([0], [0], color=spec.color, label=eq)]
        legend_elements += [
            lines.Line2D(
                [0],
                [0],
                color=spec.color,
                ls="",
                marker=spec.shape,
                label="$R^2$=" + str(round(r2, 4)),
            )
        ]
        return legend_elements


def oneMetricPlot(module, widths, var, freq=None, ax=None, fits="clsgn", norm=True, color=None):
    """module: string module name
    freq: int freq (MHz)
    var: string delay, area, lpower, or denergy
    fits: constant, linear, square, log2, Nlog2
    plots given variable vs width for all matching syntheses with regression
    """
    singlePlot = True
    if ax or (freq == 10):
        singlePlot = False
    if ax is None:
        ax = plt.gca()

    fullLeg = []
    allWidths = []
    allMetrics = []

    ale = var != "delay"  # if not delay, must be area, leakage, or energy
    modFit = fitDict[module]
    fits = modFit[ale]

    ls = "--" if freq else "-"

    for spec in techSpecs:
        # print(f"Searching for module of spec {spec} and module {module} and var {var}")
        metric = getVals(spec.tech, module, var, freq=freq)
        # print(f"Found metric : {metric}")
        if norm:
            techdict = spec._asdict()
            norm = techdict[var]
            metric = [m / norm for m in metric]

        if len(widths) == len(metric):
            # don't include the spec if we don't have points for all widths
            # print(f"Width \neq Metric")
            xp, pred, coefs, r2 = regress(widths, metric, fits, ale)
            fullLeg += genLegend(fits, coefs, r2, spec, ale=ale)
            c = color if color else spec.color
            ax.scatter(widths, metric, color=c, marker=spec.shape)
            ax.plot(xp, pred, color=c, linestyle=ls)
            allWidths += widths
            allMetrics += metric

        # print(f"Widths passed into regress : {allWidths}")
        if len(allWidths) > 0:
            xp, pred, coefs, r2 = regress(allWidths, allMetrics, fits)
            ax.plot(xp, pred, color="orange", linestyle=ls)
        else:
            xp, pred, coefs, r2 = regress(widths, metric, fits)
            ax.plot(xp, pred, color="orange", linestyle=ls)

    if norm:
        ylabeldic = {
            "lpower": "Leakage Power (add32)",
            "denergy": "Energy/Op (add32)",
            "area": "Area (add32)",
            "delay": "Delay (FO4)",
        }
    else:
        ylabeldic = {
            "lpower": "Leakage Power (nW)",
            "denergy": "Dynamic Energy (nJ)",
            "area": "Area (sq microns)",
            "delay": "Delay (ns)",
        }

    ax.set_ylabel(ylabeldic[var])
    ax.set_xticks(widths)

    if singlePlot or (var == "lpower") or (var == "denergy"):
        ax.set_xlabel("Width (bits)")
    if not singlePlot and ((var == "delay") or (var == "area")):
        ax.tick_params(labelbottom=False)

    if singlePlot:
        fullLeg += genLegend(fits, coefs, r2, combined, ale=ale)
        legLoc = "upper left" if ale else "center right"
        ax.add_artist(ax.legend(handles=fullLeg, loc=legLoc))
        titleStr = "  (target  " + str(freq) + "MHz)" if freq is not None else " (best achievable delay)"
        ax.set_title(module + titleStr)
        plt.savefig(".plots/" + module + "_" + var + ".png")
        # plt.show()
    return r2


def regress(widths, var, fits="clsgn", ale=False):
    """fits a curve to the given points
    returns lists of x and y values to plot that curve and coefs for the eq with r2
    """
    if len(var) != len(widths):
        # print(
        #    f"There are not enough variables to match widths. Widths : {widths} Variables Found : {var}, padding to match may affect correctness (doing it anyways)\n"
        # )
        if len(widths) > len(var):
            while len(widths) > len(var):
                var.append(0.0)
        if len(var) > len(widths):
            while len(var) > len(widths):
                widths.append(0)

    # widths = [8, 16, 32, 64, 128]
    # print(f"Regress var : {var}")
    # print(f"Regress widths : {widths}")
    funcArr = genFuncs(fits)
    xp = np.linspace(min(widths) / 2, max(widths) * 1.1, 200)
    xpToCalc = xp

    if ale:
        widths = [w / normAddWidth for w in widths]
        xpToCalc = [x / normAddWidth for x in xp]

    mat = []
    for w in widths:
        row = []
        for func in funcArr:
            row += [func(w)]
        mat += [row]

    # var = [0, 1, 2, 3, 4]
    y = np.array(var, dtype=np.float64)
    coefs = opt.nnls(mat, y)[0]

    yp = []
    for w in widths:
        n = [func(w) for func in funcArr]
        yp += [sum(np.multiply(coefs, n))]
    r2 = skm.r2_score(y, yp)

    pred = []
    for x in xpToCalc:
        n = [func(x) for func in funcArr]
        pred += [sum(np.multiply(coefs, n))]

    return xp, pred, coefs, r2


def makeCoefTable():
    """writes CSV with each line containing the coefficients for a regression fit
    to a particular combination of module, metric (including both techs, normalized)
    """
    with open("ppaFitting.csv", "w") as file:
        writer = csv.writer(file)
        writer.writerow(["Module", "Metric", "Target", "1", "N", "N^2", "log2(N)", "Nlog2(N)", "R^2"])

        for module in modules:
            for freq in [10, None]:
                target = "easy" if freq else "hard"
                for var in ["delay", "area", "lpower", "denergy"]:
                    ale = var != "delay"
                    metL = []
                    modFit = fitDict[module]
                    fits = modFit[ale]

                    for spec in techSpecs:
                        metric = getVals(spec.tech, module, var, freq=freq)
                        techdict = spec._asdict()
                        norm = techdict[var]
                        metL += [m / norm for m in metric]

                    xp, pred, coefs, r2 = regress(widths * 2, metL, fits, ale)
                    coefs = np.ndarray.tolist(coefs)
                    coefsToWrite = [None] * 5
                    fitTerms = "clsgn"
                    ind = 0
                    for i in range(len(fitTerms)):
                        if fitTerms[i] in fits:
                            coefsToWrite[i] = coefs[ind]
                            ind += 1
                    row = [module, var, target] + coefsToWrite + [r2]
                    writer.writerow(row)


def sigfig(num, figs):
    return "{:g}".format(float("{:.{p}g}".format(num, p=figs)))


def makeEqTable():
    """writes CSV with each line containing the equations for fits for each metric
    to a particular module (including both techs, normalized)
    """
    with open("ppaEquations.csv", "w") as file:
        writer = csv.writer(file)
        writer.writerow(
            [
                "Element",
                "Best delay",
                "Fast area",
                "Fast leakage",
                "Fast energy",
                "Small area",
                "Small leakage",
                "Small energy",
            ]
        )

        for module in modules:
            eqs = []
            for freq in [None, 10]:
                for var in ["delay", "area", "lpower", "denergy"]:
                    if (var == "delay") and (freq == 10):
                        pass
                    else:
                        ale = var != "delay"
                        metL = []
                        modFit = fitDict[module]
                        fits = modFit[ale]

                        for spec in techSpecs:
                            metric = getVals(spec.tech, module, var, freq=freq)
                            techdict = spec._asdict()
                            norm = techdict[var]
                            metL += [m / norm for m in metric]

                        xp, pred, coefs, r2 = regress(widths * 2, metL, fits, ale)
                        coefs = np.ndarray.tolist(coefs)
                        eqs += [genLegend(fits, coefs, ale=ale)]
            row = [module] + eqs
            writer.writerow(row)


def genFuncs(fits="clsgn"):
    """helper function for regress()
    returns array of functions with one for each term desired in the regression fit
    """
    funcArr = []
    if "c" in fits:
        funcArr += [lambda x: 1]
    if "l" in fits:
        funcArr += [lambda x: x]
    if "s" in fits:
        funcArr += [lambda x: x**2]
    if "g" in fits:
        funcArr += [lambda x: np.log2(x)]
    if "n" in fits:
        funcArr += [lambda x: x * np.log2(x)]
    return funcArr


def noOutliers(median, freqs, delays, areas):
    """returns a pared down list of freqs, delays, and areas
    cuts out any syntheses in which target freq isn't within 75% of the min delay target to focus on interesting area
    helper function to freqPlot()
    """
    f = []
    d = []
    a = []
    for i in range(len(freqs)):
        norm = freqs[i] / median
        if (norm > 0.4) & (norm < 1.4):
            f += [freqs[i]]
            d += [delays[i]]
            a += [areas[i]]

    return f, d, a


def freqPlot(tech, mod, width):
    """plots delay, area, area*delay, and area*delay^2 for syntheses with specified tech, module, width"""

    freqsL, delaysL, areasL = ([[], []] for i in range(3))
    for oneSynth in allSynths:
        if (mod == oneSynth.module) & (width == oneSynth.width) & (tech == oneSynth.tech):
            ind = 1000 / oneSynth.delay < oneSynth.freq  # when delay is within target clock period
            freqsL[ind] += [oneSynth.freq]
            delaysL[ind] += [oneSynth.delay]
            areasL[ind] += [oneSynth.area]

    median = np.median(list(flatten(freqsL)))

    f, (ax1, ax2) = plt.subplots(2, 1, sharex=True)
    for ax in (ax1, ax2):
        ax.ticklabel_format(useOffset=False, style="plain")

    for ind in [0, 1]:
        areas = areasL[ind]
        delays = delaysL[ind]
        freqs = freqsL[ind]

        freqs, delays, areas = noOutliers(median, freqs, delays, areas)  # comment out to see all syntheses

        c = "blue" if ind else "green"
        ax1.scatter(freqs, delays, color=c)
        ax2.scatter(freqs, areas, color=c)

    legend_elements = [
        lines.Line2D([0], [0], color="green", ls="", marker="o", label="timing achieved"),
        lines.Line2D([0], [0], color="blue", ls="", marker="o", label="slack violated"),
    ]

    ax1.legend(handles=legend_elements)
    width = str(width)

    ax2.set_xlabel("Target Freq (MHz)")
    ax1.set_ylabel("Delay (ns)")
    ax2.set_ylabel("Area (sq microns)")
    ax1.set_title(mod + "_" + width)
    if ("mux" in mod) & ("d" in mod):
        width = mod
        mod = "muxd"
    plt.savefig("./plots/freqBuckshot/" + tech + "/" + mod + "/" + width + ".png")
    # plt.show()


def squareAreaDelay(tech, mod, width):
    """plots delay, area, area*delay, and area*delay^2 for syntheses with specified tech, module, width"""
    global allSynths
    freqsL, delaysL, areasL = ([[], []] for i in range(3))
    for oneSynth in allSynths:
        if (mod == oneSynth.module) & (width == oneSynth.width) & (tech == oneSynth.tech):
            ind = 1000 / oneSynth.delay < oneSynth.freq  # when delay is within target clock period
            freqsL[ind] += [oneSynth.freq]
            delaysL[ind] += [oneSynth.delay]
            areasL[ind] += [oneSynth.area]

    f, (ax1) = plt.subplots(1, 1)
    ax2 = ax1.twinx()

    for ind in [0, 1]:
        areas = areasL[ind]
        delays = delaysL[ind]
        targets = freqsL[ind]
        targets = [1000 / f for f in targets]

        targets, delays, areas = noOutliers(targets, delays, areas)  # comment out to see all

        if not ind:
            achievedDelays = delays

        c = "blue" if ind else "green"
        ax1.scatter(targets, delays, marker="^", color=c)
        ax2.scatter(targets, areas, marker="s", color=c)

    bestAchieved = min(achievedDelays)

    legend_elements = [
        lines.Line2D([0], [0], color="green", ls="", marker="^", label="delay (timing achieved)"),
        lines.Line2D([0], [0], color="green", ls="", marker="s", label="area (timing achieved)"),
        lines.Line2D([0], [0], color="blue", ls="", marker="^", label="delay (timing violated)"),
        lines.Line2D([0], [0], color="blue", ls="", marker="s", label="area (timing violated)"),
    ]

    ax2.legend(handles=legend_elements, loc="upper left")

    ax1.set_xlabel("Delay Targeted (ns)")
    ax1.set_ylabel("Delay Achieved (ns)")
    ax2.set_ylabel("Area (sq microns)")
    ax1.set_title(mod + "_" + str(width))

    squarify(f)

    xvals = np.array(ax1.get_xlim())
    frac = (min(flatten(delaysL)) - xvals[0]) / (xvals[1] - xvals[0])
    areaLowerLim = min(flatten(areasL)) - 100
    areaUpperLim = max(flatten(areasL)) / frac + areaLowerLim
    ax2.set_ylim([areaLowerLim, areaUpperLim])
    ax1.plot(xvals, xvals, ls="--", c=".3")
    ax1.hlines(y=bestAchieved, xmin=xvals[0], xmax=xvals[1], color="black", ls="--")

    plt.savefig("./plots/squareareadelay_" + mod + "_" + str(width) + ".png")
    # plt.show()


def squarify(fig):
    """helper function for squareAreaDelay()
    forces matplotlib figure to be a square
    """
    w, h = fig.get_size_inches()
    if w > h:
        t = fig.subplotpars.top
        b = fig.subplotpars.bottom
        axs = h * (t - b)
        l = (1.0 - axs / w) / 2
        fig.subplots_adjust(left=l, right=1 - l)
    else:
        t = fig.subplotpars.right
        b = fig.subplotpars.left
        axs = w * (t - b)
        l = (1.0 - axs / h) / 2
        fig.subplots_adjust(bottom=l, top=1 - l)


def plotPPA(mod, freq=None, norm=True, aleOpt=False):
    """for the module specified, plots width vs delay, area, leakage power, and dynamic energy with fits
    if no freq specified, uses the synthesis with best achievable delay for each width
    overlays data from both techs
    """
    with mpl.rc_context({"figure.figsize": (7, 3.46)}):
        fig, axs = plt.subplots(2, 2)

    arr = [["delay", "area"], ["lpower", "denergy"]]

    freqs = [freq]
    if aleOpt:
        freqs += [10]

    for i in [0, 1]:
        for j in [0, 1]:
            leg = []
            for f in freqs:
                if (arr[i][j] == "delay") and (f == 10):
                    pass
                else:
                    # print(f"Passing in widths {widths}")
                    r2 = oneMetricPlot(mod, widths, arr[i][j], ax=axs[i, j], freq=f, norm=norm)
                    ls = "--" if f else "-"
                    leg += [
                        lines.Line2D(
                            [0],
                            [0],
                            color="orange",
                            label="$R^2$=" + str(round(r2, 4)),
                            linestyle=ls,
                        )
                    ]

            if (mod in ["flop", "csa"]) & (arr[i][j] == "delay"):
                axs[i, j].set_ylim(ymin=0)
                ytop = axs[i, j].get_ylim()[1]
                axs[i, j].set_ylim(ymax=1.1 * ytop)
            else:
                axs[i, j].legend(handles=leg, handlelength=1.5)

    titleStr = f"  (target {freq} MHz)" if freq is not None else ""
    plt.suptitle(mod + titleStr)
    plt.tight_layout(pad=0.05, w_pad=1, h_pad=0.5, rect=(0, 0, 1, 0.97))

    if freq != 10:
        n = "normalized" if norm else "unnormalized"
        saveStr = "./plots/" + n + "/" + mod + "_" + ".png"
        print(f"Saving to {saveStr}")
        plt.savefig(saveStr)
    # plt.show()


def makeLineLegend():
    """generates legend to accompany normalized plots"""
    plt.rcParams["figure.figsize"] = (5.5, 0.3)
    fig = plt.figure()
    fullLeg = [lines.Line2D([0], [0], color="black", label="fastest", linestyle="-")]
    fullLeg += [lines.Line2D([0], [0], color="black", label="smallest", linestyle="--")]
    fullLeg += [lines.Line2D([0], [0], color="blue", label="tsmc28", marker="^")]
    fullLeg += [lines.Line2D([0], [0], color="blue", label="tsmc28psyn", marker="x")]
    fullLeg += [lines.Line2D([0], [0], color="green", label="sky90", marker="o")]
    fullLeg += [lines.Line2D([0], [0], color="purple", label="sky130", marker="+")]
    fullLeg += [lines.Line2D([0], [0], color="orange", label="combined", marker="_")]
    fig.legend(handles=fullLeg, ncol=5, handlelength=1.4, loc="center")
    saveStr = "./plots/legend.png"
    plt.savefig(saveStr)


def muxPlot(fits="clsgn", norm=True):
    """module: string module name
    freq: int freq (MHz)
    var: string delay, area, lpower, or denergy
    fits: constant, linear, square, log2, Nlog2
    plots given variable vs width for all matching syntheses with regression
    """
    ax = plt.gca()

    inputs = [2, 4, 8]
    allInputs = inputs * 2
    fullLeg = []

    for crit in ["data", "control"]:
        allMetrics = []
        muxes = ["mux2", "mux4", "mux8"]

        if crit == "data":
            ls = "--"
            muxes = [m + "d" for m in muxes]
        elif crit == "control":
            ls = "-"

        for spec in techSpecs:
            metric = []
            for module in muxes:
                metric += getVals(spec.tech, module, "delay", width=[1])

            if norm:
                techdict = spec._asdict()
                norm = techdict["delay"]
                metric = [m / norm for m in metric]
                # print(spec.tech, ' ', metric)

            if len(metric) == 3:  # don't include the spec if we don't have points for all
                xp, pred, coefs, r2 = regress(inputs, metric, fits, ale=False)
                ax.scatter(inputs, metric, color=spec.color, marker=spec.shape)
                ax.plot(xp, pred, color=spec.color, linestyle=ls)
                allMetrics += metric

        xp, pred, coefs, r2 = regress(allInputs, allMetrics, fits)
        ax.plot(xp, pred, color="red", linestyle=ls)
        fullLeg += [lines.Line2D([0], [0], color="red", label=crit, linestyle=ls)]

    ax.set_ylabel("Delay (FO4)")
    ax.set_xticks(inputs)
    ax.set_xlabel("Number of inputs")
    ax.set_title("mux timing")

    ax.legend(handles=fullLeg)
    plt.savefig("./plots/mux.png")


def stdDevError():
    """calculates std deviation and error for paper-writing purposes"""
    for var in ["delay", "area", "lpower", "denergy"]:
        errlist = []
        for module in modules:
            ale = var != "delay"
            metL = []
            modFit = fitDict[module]
            fits = modFit[ale]
            funcArr = genFuncs(fits)

            for spec in techSpecs:
                metric = getVals(spec.tech, module, var)
                techdict = spec._asdict()
                norm = techdict[var]
                metL += [m / norm for m in metric]

            ws = [w / normAddWidth for w in widths] if ale else widths
            ws = ws * 2
            mat = []
            for w in ws:
                row = []
                for func in funcArr:
                    row += [func(w)]
                mat += [row]

            y = np.array(metL, dtype=np.float)
            coefs = opt.nnls(mat, y)[0]

            yp = []
            for w in ws:
                n = [func(w) for func in funcArr]
                yp += [sum(np.multiply(coefs, n))]

            if (var == "delay") & (module == "flop"):
                pass
            elif (module == "mult") & ale:
                pass
            else:
                for i in range(len(y)):
                    errlist += [abs(y[i] / yp[i] - 1)]
                # print(module, ' ', var, ' ', np.mean(errlist[-10:]))

        avgErr = np.mean(errlist)
        stdv = np.std(errlist)

        print(var, " ", avgErr, " ", stdv)


def makePlotDirectory():
    """creates plots directory in same level as this script to store plots in"""
    current_directory = os.getcwd()
    final_directory = os.path.join(current_directory, "plots")
    if not os.path.exists(final_directory):
        os.makedirs(final_directory)
    os.chdir(final_directory)

    for folder in ["freqBuckshot", "normalized", "unnormalized"]:
        new_directory = os.path.join(final_directory, folder)
        if not os.path.exists(new_directory):
            os.makedirs(new_directory)
        os.chdir(new_directory)
        if "freq" in folder:
            for tech in ["sky90", "sky130", "tsmc28", "tsmc28psyn"]:
                for mod in modules:
                    tech_directory = os.path.join(new_directory, tech)
                    mod_directory = os.path.join(tech_directory, mod)
                    if not os.path.exists(mod_directory):
                        os.makedirs(mod_directory)
                os.chdir("..")

    os.chdir(current_directory)


if __name__ == "__main__":
    ##############################
    # set up stuff, global variables
    widths = [8, 16, 32, 64, 128]
    modules = ["adder"]

    normAddWidth = 32  # divisor to use with N since normalizing to add_32

    fitDict = {
        "adder": ["cg", "l", "l"],
        "mul": ["cg", "s", "s"],
        "comparator": ["cg", "l", "l"],
        "csa": ["c", "l", "l"],
        "shifter": ["cg", "l", "ln"],
        "flop": ["c", "l", "l"],
        "binencoder": ["cg", "l", "l"],
    }
    fitDict.update({key: ["cg", "l", "l"] for key in ["mux2", "mux4", "mux8"]})

    TechSpec = namedtuple("TechSpec", "tech color shape delay area lpower denergy")
    # FO4 delay information information
    techSpecs = [
        # ["sky90", "green", "o", 43.2e-3, 1440.600027, 714.057, 0.658022690438],
        # Area/Lpower/Denergy needs to be corrected here (jes)
        ["sky130", "orange", "o", 99.5e-3, 1440.600027, 714.057, 0.658022690438],
        # ["tsmc28", "blue", "^", 12.2e-3, 209.286002, 1060.0, 0.08153281695882594],
        # ["tsmc28psyn", "blue", "^", 12.2e-3, 209.286002, 1060.0, 0.08153281695882594],
    ]
    techSpecs = [TechSpec(*t) for t in techSpecs]
    combined = TechSpec("combined fit", "red", "_", 0, 0, 0, 0)
    ##############################

    # cleanup() # run to remove garbage synth runs
    synthsintocsv()  # slow, run only when new synth runs to add to csv

    allSynths = synthsfromcsv("ppaData.csv")  # your csv here!
    bestSynths = csvOfBest("bestSynths.csv")
    makePlotDirectory()

    # ### other functions
    # makeCoefTable()
    # makeEqTable()
    # muxPlot()
    # stdDevError()

    for mod in modules:
        for w in widths:
            # freqPlot('sky90', mod, w)
            freqPlot("sky130", mod, w)
            # freqPlot('tsmc28', mod, w)
            # freqPlot('tsmc28psyn', mod, w)
            plotPPA(mod, norm=False)
            plotPPA(mod, aleOpt=True)
            plt.close("all")
