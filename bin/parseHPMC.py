#!/usr/bin/env -S uv run --script

###########################################
## Written: Rose Thompson rose@rosethompson.net
## Created: 20 September 2023
## Modified:
##
## Purpose: Parses the performance counters from a modelsim trace.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

import argparse
import math
import os
import sys

import matplotlib.pyplot as plt
import numpy as np

WALLY = os.environ.get('WALLY')

RefDataBP = [('twobitCModel6', 'twobitCModel', 64, 128, 10.0060297551637), ('twobitCModel8', 'twobitCModel', 256, 512, 8.4320392215602), ('twobitCModel10', 'twobitCModel', 1024, 2048, 7.29493318805151),
           ('twobitCModel12', 'twobitCModel', 4096, 8192, 6.84739616147794), ('twobitCModel14', 'twobitCModel', 16384, 32768, 5.68432926870082), ('twobitCModel16', 'twobitCModel', 65536, 131072, 5.68432926870082),
           ('gshareCModel6', 'gshareCModel', 64, 128, 11.4737703417701), ('gshareCModel8', 'gshareCModel', 256, 512, 8.52341470761974), ('gshareCModel10', 'gshareCModel', 1024, 2048, 6.32975690693015),
           ('gshareCModel12', 'gshareCModel', 4096, 8192, 4.55424632377659), ('gshareCModel14', 'gshareCModel', 16384, 32768, 3.54251547725509), ('gshareCModel16', 'gshareCModel', 65536, 131072, 1.90424999467293)]
RefDataBTB = [('BTBCModel6', 'BTBCModel', 64, 128, 1.51480272475844), ('BTBCModel8', 'BTBCModel', 256, 512, 0.209057900418965), ('BTBCModel10', 'BTBCModel', 1024, 2048, 0.0117345454469572),
              ('BTBCModel12', 'BTBCModel', 4096, 8192, 0.00125540990359826), ('BTBCModel14', 'BTBCModel', 16384, 32768, 0.000732471628510962), ('BTBCModel16', 'BTBCModel', 65536, 131072, 0.000732471628510962)]

def ParseBranchListFile(path):
    '''Take the path to the list of Questa Sim log files containing the performance counters outputs.  File
    is formatted in row columns.  Each row is a trace with the file, branch predictor type, and the parameters.
    parameters can be any number and depend on the predictor type. Returns a list of lists.'''
    lst = []
    with open(path) as BranchList:
        for line in BranchList:
            tokens = line.split()
            predictorLog = f"{WALLY}/sim/{args.sim}/logs/{tokens[0]}"
            predictorType = tokens[1]
            predictorParams = tokens[2::]
            lst.append([predictorLog, predictorType, predictorParams])
            #print(predictorLog, predictorType, predictorParams)
    return lst

def ProcessFile(fileName):
    '''Extract performance counters from a modelsim log.  Outputs a list of tuples for each test/benchmark.
    The tuple contains the test name, optimization characteristics, and dictionary of performance counters.'''
    # 1 find lines with Read memfile and extract test name
    # 2 parse counters into a list of (name, value) tuples (dictionary maybe?)
    benchmarks = []
    HPMClist = { }
    testName = ''
    opt = ''
    with open(fileName) as transcript:
        for line in transcript.readlines():
            lineToken = line.split()
            if (args.sim == "questa") & (lineToken[0] == "#"):
                lineToken = lineToken[1:] # Questa uses a leading # for each line, other simulators do not
            if(len(lineToken) > 2 and lineToken[0] == 'Read' and lineToken[1] == 'memfile'):
                opt = lineToken[2].split('/')[-4]
                testName = lineToken[2].split('/')[-1].split('.')[0]
                HPMClist = { }
            elif(len(lineToken) > 3 and lineToken[0][0:3] == 'Cnt'):
                countToken = line.split('=')[1].split()
                value = int(countToken[0]) if countToken[0] != 'x' else 0
                name = ' '.join(countToken[1:])
                HPMClist[name] = value
            elif ('is done' in line):
                benchmarks.append((testName, opt, HPMClist))
    return benchmarks


def ComputeStats(benchmarks):
    for benchmark in benchmarks:
        (nameString, opt, dataDict) = benchmark
        dataDict['CPI'] = 1.0 * int(dataDict['Mcycle']) / int(dataDict['InstRet'])
        dataDict['BDMR'] = 100.0 * int(dataDict['BP Dir Wrong']) / int(dataDict['Br Count'])
        dataDict['BTMR'] = 100.0 * int(dataDict['BP Target Wrong']) / (int(dataDict['Br Count']) + int(dataDict['Jump Not Return']))
        dataDict['RASMPR'] = 100.0 * int(dataDict['RAS Wrong']) / int(dataDict['Return'])
        dataDict['ClassMPR'] = 100.0 * int(dataDict['Instr Class Wrong']) / int(dataDict['InstRet'])
        dataDict['ICacheMR'] = 100.0 * int(dataDict['I Cache Miss']) / int(dataDict['I Cache Access'])

        cycles = int(dataDict['I Cache Miss'])
        if(cycles == 0): ICacheMR = 0
        else: ICacheMR = 100.0 * int(dataDict['I Cache Cycles']) / cycles
        dataDict['ICacheMT'] = ICacheMR

        dataDict['DCacheMR'] = 100.0 * int(dataDict['D Cache Miss']) / int(dataDict['D Cache Access'])

        (nameString, opt, dataDict) = benchmark
        cycles = int(dataDict['D Cache Miss'])
        if(cycles == 0): DCacheMR = 0
        else: DCacheMR = 100.0 * int(dataDict['D Cache Cycles']) / cycles
        dataDict['DCacheMT'] = DCacheMR


def ComputeGeometricAverage(benchmarks):
    fields = ['BDMR', 'BTMR', 'RASMPR', 'ClassMPR', 'ICacheMR', 'DCacheMR', 'CPI', 'ICacheMT', 'DCacheMT']
    AllAve = {}
    for field in fields:
        Product = 1
        index = 0
        for (testName, opt, HPMCList) in benchmarks:
            #print(HPMCList)
            value = HPMCList[field]
            if(value != 0): Product *= value # if that value is 0 exclude from mean because it destories the geo mean
            index += 1
        AllAve[field] = Product ** (1.0/index)
    benchmarks.append(('Mean', '', AllAve))

def GenerateName(predictorType, predictorParams):
    if(predictorType == 'gshare' or  predictorType == 'twobit' or predictorType == 'btb' or predictorType == 'class' or predictorType == 'ras' or predictorType == 'global'):
        return predictorType + predictorParams[0]
    elif(predictorType == 'local'):
        return predictorType + predictorParams[0] + '_' + predictorParams[1]
    else:
        print(f'Error unsupported predictor type {predictorType}')
        sys.exit(-1)

def GenerateDisplayName(predictorType, predictorParams):
    if(predictorType == 'gshare' or  predictorType == 'twobit' or predictorType == 'btb' or predictorType == 'class' or predictorType == 'ras' or predictorType == 'global'):
        return predictorType
    elif(predictorType == 'local'):
        return predictorType + predictorParams[0]
    else:
        print(f'Error unsupported predictor type {predictorType}')
        sys.exit(-1)

def ComputePredNumEntries(predictorType, predictorParams):
    if(predictorType == 'gshare' or  predictorType == 'twobit' or predictorType == 'btb' or predictorType == 'class' or predictorType == 'global'):
        return 2**int(predictorParams[0])
    elif(predictorType == 'ras'):
        return int(predictorParams[0])
    elif(predictorType == 'local'):
        return 2**int(predictorParams[0]) * int(predictorParams[1]) + 2**int(predictorParams[1])
    else:
        print(f'Error unsupported predictor type {predictorType}')
        sys.exit(-1)

def ComputePredSize(predictorType, predictorParams):
    if(predictorType == 'gshare' or  predictorType == 'twobit' or predictorType == 'btb' or predictorType == 'class' or predictorType == 'global'):
        return 2*2**int(predictorParams[0])
    elif(predictorType == 'ras'):
        return int(predictorParams[0])
    elif(predictorType == 'local'):
        return 2**int(predictorParams[0]) * int(predictorParams[1]) + 2*2**int(predictorParams[1])
    else:
        print(f'Error unsupported predictor type {predictorType}')
        sys.exit(-1)

def BuildDataBase(predictorLogs):
    # Once done with the following loop, performanceCounterList will contain the predictor type and size along with the
    # raw performance counter data and the processed data on a per benchmark basis.  It also includes the geometric mean.
    # list
    #   branch predictor configuration 0 (tuple)
    #     benchmark name
    #     compiler optimization
    #     data (dictionary)
    #       dictionary of performance counters
    #   branch predictor configuration 1 (tuple)
    #     benchmark name (dictionary)
    #     compiler optimization
    #     data
    #       dictionary of performance counters
    # ...
    performanceCounterList = []
    for trace in predictorLogs:
        predictorLog = trace[0]
        predictorType = trace[1]
        predictorParams = trace[2]
        # Extract the performance counter data
        performanceCounters = ProcessFile(predictorLog)
        ComputeStats(performanceCounters)
        ComputeGeometricAverage(performanceCounters)
        #print(performanceCounters)
        performanceCounterList.append([GenerateName(predictorType, predictorParams), GenerateDisplayName(predictorType, predictorParams), performanceCounters, ComputePredNumEntries(predictorType, predictorParams), ComputePredSize(predictorType, predictorParams)])
    return performanceCounterList

def ReorderDataBase(performanceCounterList):
    # Reorder the data so the benchmark name comes first, then the branch predictor configuration
    benchmarkFirstList = []
    for (predictorName, predictorPrefixName, benchmarks, entries, size) in performanceCounterList:
        for benchmark in benchmarks:
            (nameString, opt, dataDict) = benchmark
            benchmarkFirstList.append((nameString, opt, predictorName, predictorPrefixName, entries, size, dataDict))
    return benchmarkFirstList

def ExtractSelectedData(benchmarkFirstList):
    # now extract all branch prediction direction miss rates for each
    # namestring + opt, config
    benchmarkDict = { }
    for benchmark in benchmarkFirstList:
        (name, opt, config, prefixName, entries, size, dataDict) = benchmark
        #print(f'config = {config}, prefixName = {prefixName} entries = {entries}')
        # use this code to distinguish speed opt and size opt.
        #if opt == 'bd_speedopt_speed': NewName = name+'Sp'
        #elif opt == 'bd_sizeopt_speed': NewName = name+'Sz'
        #else: NewName = name
        NewName = name
        #print(NewName)
        #NewName = name+'_'+opt
        if NewName in benchmarkDict:
            benchmarkDict[NewName].append((config, prefixName, entries, size, dataDict[ReportPredictorType]))
        else:
            benchmarkDict[NewName] = [(config, prefixName, entries, size, dataDict[ReportPredictorType])]
    return benchmarkDict

def ReportAsTable(benchmarkDict):
    refLine = benchmarkDict['Mean']
    FirstLine = []
    SecondLine = []
    for Elements in refLine:
        (name, typ, size, entries, val) = Elements
        FirstLine.append(name)
        SecondLine.append(entries if not args.size else size)

    sys.stdout.write('benchmark\t\t')
    for name in FirstLine:
        if(len(name) < 8): sys.stdout.write(f'{name}\t\t')
        else: sys.stdout.write(f'{name}\t')
    sys.stdout.write('\n')
    sys.stdout.write('size\t\t\t')
    for size in SecondLine:
        if(len(str(size)) < 8): sys.stdout.write(f'{size}\t\t')
        else: sys.stdout.write(f'{size}\t')
    sys.stdout.write('\n')

    if(args.summary):
        sys.stdout.write('Mean\t\t\t')
        for (name, typ, size, entries, val) in refLine:
            sys.stdout.write('%0.2f\t\t' % (val if not args.invert else 100 - val))
        sys.stdout.write('\n')

    if(not args.summary):
        for benchmark in benchmarkDict:
            length = len(benchmark)
            if(length < 8): sys.stdout.write(f'{benchmark}\t\t\t')
            elif(length < 16): sys.stdout.write(f'{benchmark}\t\t')
            else: sys.stdout.write(f'{benchmark}\t')
            for (name, typ, entries, size, val) in benchmarkDict[benchmark]:
                sys.stdout.write('%0.2f\t\t' % (val if not args.invert else 100 -val))
            sys.stdout.write('\n')

def ReportAsText(benchmarkDict):
    if(args.summary):
        mean = benchmarkDict['Mean']
        print('Mean')
        for (name, typ, entries, size, val) in mean:
            sys.stdout.write(f'{name} {entries if not args.size else size} {val if not args.invert else 100 - val:0.2f}\n')

    if(not args.summary):
        for benchmark in benchmarkDict:
            print(benchmark)
            for (name, prefixName, entries, size, val) in benchmarkDict[benchmark]:
                sys.stdout.write(f'{name} {entries if not args.size else size} {val if not args.invert else 100 - val:0.2f}\n')

def Inversion(lst):
    return [x if not args.invert else 100 - x for x in lst]

def BarGraph(seriesDict, xlabelList, BenchPerRow, FileName, IncludeLegend):
    index = 0
    NumberInGroup = len(seriesDict)
    # Figure out width of bars.  NumberInGroup bars + want 2 bar space
    # the space between groups is 1
    EffectiveNumInGroup = NumberInGroup + 2
    barWidth = 1 / EffectiveNumInGroup
    _ = plt.subplots(figsize = (EffectiveNumInGroup*BenchPerRow/8, 4))
    colors = ['blue', 'blue', 'blue', 'blue', 'blue', 'blue', 'black', 'black', 'black', 'black', 'black', 'black']
    for name in seriesDict:
        values = seriesDict[name]
        xpos = np.arange(len(values))
        xpos = [x + index*barWidth for x in xpos]
        plt.bar(xpos, Inversion(values), width=barWidth, edgecolor='grey', label=name, color=colors[index%len(colors)])
        index += 1
    plt.xticks([r + barWidth*(NumberInGroup/2-0.5) for r in range(0, BenchPerRow)], xlabelList)
    plt.xlabel('Benchmark')
    if(not args.invert): plt.ylabel('Misprediction Rate (%)')
    else:  plt.ylabel('Prediction Accuracy (%)')
    if(IncludeLegend): plt.legend(loc='upper right', ncol=2)
    plt.savefig(FileName)

def SelectPartition(xlabelListBig, seriesDictBig, group, BenchPerRow):
    seriesDictTrunk = {}
    for benchmarkName in seriesDictBig:
        lst = seriesDictBig[benchmarkName]
        seriesDictTrunk[benchmarkName] = lst[group*BenchPerRow:(group+1)*BenchPerRow]
    xlabelListTrunk = xlabelListBig[group*BenchPerRow:(group+1)*BenchPerRow]
    return(xlabelListTrunk, seriesDictTrunk)


def ReportAsGraph(benchmarkDict, bar, FileName):
    def FormatToPlot(currBenchmark):
        names = []
        sizes = []
        values = []
        typs = []
        for config in currBenchmark:
            names.append(config[0])
            sizes.append(config[1])
            values.append(config[2])
            typs.append(config[3])
        return (names, sizes, values, typs)
    titlesInvert = {'BDMR' : 'Branch Direction Accuracy',
              'BTMR' : 'Branch Target Accuracy',
              'RASMPR': 'RAS Accuracy',
              'ClassMPR': 'Class Prediction Accuracy'}
    titles = {'BDMR' : 'Branch Direction Misprediction',
              'BTMR' : 'Branch Target Misprediction',
              'RASMPR': 'RAS Misprediction',
              'ClassMPR': 'Class Misprediction'}
    if(args.summary):
        markers = ['x', '.', '+', '*', '^', 'o', ',', 's']
        colors = ['blue', 'black', 'gray', 'dodgerblue', 'lightsteelblue', 'turquoise', 'black', 'blue']

        # the benchmarkDict['Mean'] contains sequences of results for multiple
        # branch predictors with various parameterizations
        # group the parameterizations by the common typ.
        sequences = {}
        for (name, typ, entries, size, value) in benchmarkDict['Mean']:
            if typ not in sequences:
                sequences[typ] = [(entries if not args.size else int(size/8), value)]
            else:
                sequences[typ].append((entries if not args.size else int(size/8) ,value))
        # then graph the common typ as a single line+scatter plot
        # finally repeat for all typs of branch predictors and overlay
        fig, axes = plt.subplots()
        index = 0
        if(args.invert): plt.title(titlesInvert[ReportPredictorType])
        else: plt.title(titles[ReportPredictorType])
        for branchPredName in sequences:
            data = sequences[branchPredName]
            (xdata, ydata) = zip(*data)
            if args.invert: ydata = [100 - x for x in ydata]
            axes.plot(xdata, ydata, color=colors[index])
            axes.scatter(xdata, ydata, label=branchPredName, color=colors[index], marker=markers[index])
            index = (index + 1) % len(markers)
        axes.legend(loc='upper left')
        axes.set_xscale("log")
        axes.set_ylabel('Prediction Accuracy')
        Xlabel = 'Entries' if not args.size else 'Size (bytes)'
        axes.set_xlabel(Xlabel)
        axes.set_xticks(xdata)
        axes.set_xticklabels(xdata)
        axes.grid(color='b', alpha=0.5, linestyle='dashed', linewidth=0.5)
        if FileName is None: plt.show()
        else: plt.savefig(FileName)

    # if(not args.summary):
    #     size = len(benchmarkDict)
    #     sizeSqrt = math.sqrt(size)
    #     isSquare = math.isclose(sizeSqrt, round(sizeSqrt))
    #     numCol = math.floor(sizeSqrt)
    #     numRow = numCol + (0 if isSquare else 1)
    #     index = 1
    #     fig = plt.figure()
    #     for benchmarkName in benchmarkDict:
    #         currBenchmark = benchmarkDict[benchmarkName]
    #         (names, typs, sizes, values) = FormatToPlot(currBenchmark)
    #         #axes.plot(numRow, numCol, index)
    #         ax = fig.add_subplot(numRow, numCol, index)
    #         ax.bar(names, values)
    #         ax.title.set_text(benchmarkName)
    #         #plt.ylabel('BR Dir Miss Rate (%)')
    #         #plt.xlabel('Predictor')
    #         index += 1

    if(not args.summary):
        NumBenchmarks = len(benchmarkDict)
        # NumBenchmarksSqrt = math.sqrt(NumBenchmarks)
        # isSquare = math.isclose(NumBenchmarksSqrt, round(NumBenchmarksSqrt))
        # numCol = math.floor(NumBenchmarksSqrt)
        # numRow = numCol + (0 if isSquare else 1)
        index = 1
        BenchPerRow = 5

        xlabelList = []
        seriesDict = {}

        for benchmarkName in benchmarkDict:
            currBenchmark = benchmarkDict[benchmarkName]
            xlabelList.append(benchmarkName)
            for (name, typ, entries, size, value) in currBenchmark:
                if(name not in seriesDict):
                    seriesDict[name] = [value]
                else:
                    seriesDict[name].append(value)
            if(index >= BenchPerRow): break
            index += 1

        xlabelListBig = []
        seriesDictBig = {}
        for benchmarkName in benchmarkDict:
            currBenchmark = benchmarkDict[benchmarkName]
            xlabelListBig.append(benchmarkName)
            for (name, typ, entries, size, value) in currBenchmark:
                if(name not in seriesDictBig):
                    seriesDictBig[name] = [value]
                else:
                    seriesDictBig[name].append(value)

        #The next step will be to split the benchmarkDict into length BenchPerRow pieces then repeat the following code
        # on each piece.
        for row in range(0, math.ceil(NumBenchmarks / BenchPerRow)):
            (xlabelListTrunk, seriesDictTrunk) = SelectPartition(xlabelListBig, seriesDictBig, row, BenchPerRow)
            FileName = f'barSegment{row}.svg'
            groupLen = len(xlabelListTrunk)
            BarGraph(seriesDictTrunk, xlabelListTrunk, groupLen, FileName, (row == 0))


# main
parser = argparse.ArgumentParser(description='Parses performance counters from a Questa Sim trace to produce a graph or graphs.')

# parse program arguments
metric = parser.add_mutually_exclusive_group()
metric.add_argument('-r', '--ras', action='store_const', help='Plot return address stack (RAS) performance.', default=False, const=True)
metric.add_argument('-d', '--direction', action='store_const', help='Plot direction prediction (2-bit, Gshare, local, etc) performance.', default=False, const=True)
metric.add_argument('-t', '--target', action='store_const', help='Plot branch target buffer (BTB) performance.', default=False, const=True)
metric.add_argument('-c', '--iclass', action='store_const', help='Plot instruction classification performance.', default=False, const=True)

parser.add_argument('-s', '--summary', action='store_const', help='Show only the geometric average for all benchmarks.', default=False, const=True)
parser.add_argument('-b', '--bar', action='store_const', help='Plot graphs.', default=False, const=True)
parser.add_argument('-g', '--reference', action='store_const', help='Include the golden reference model from branch-predictor-simulator. Data stored statically at the top of %(prog)s.  If you need to regenreate use CModelBranchAcurracy.sh', default=False, const=True)
parser.add_argument('-i', '--invert', action='store_const', help='Invert metric. Example Branch miss prediction becomes prediction accuracy. 100 - miss rate', default=False, const=True)
parser.add_argument('--size', action='store_const', help='Display x-axis as size in bits rather than number of table entries', default=False, const=True)

displayMode = parser.add_mutually_exclusive_group()
displayMode.add_argument('--text', action='store_const', help='Display in text format only.', default=False, const=True)
displayMode.add_argument('--table', action='store_const', help='Display in text format only.', default=False, const=True)
displayMode.add_argument('--gui', action='store_const', help='Display in text format only.', default=False, const=True)
displayMode.add_argument('--debug', action='store_const', help='Display in text format only.', default=False, const=True)
parser.add_argument('sources', nargs=1, help='File lists the input Questa transcripts to process.')
parser.add_argument('sim', choices=["questa", "verilator", "vcs"], help='Simulator that was used to generate logs. This is used to find the files specified in the sources file.')
parser.add_argument('FileName', metavar='FileName', type=str, nargs='?', help='output graph to file <name>.png If not included outputs to screen.', default=None)

args = parser.parse_args()

# Figure what we are reporting
ReportPredictorType = 'BDMR'  # default
if(args.ras): ReportPredictorType = 'RASMPR'
if(args.target): ReportPredictorType = 'BTMR'
if(args.iclass): ReportPredictorType = 'ClassMPR'

# Figure how we are displaying the data
ReportMode = 'gui' # default
if(args.text): ReportMode = 'text'
if(args.table): ReportMode = 'table'
if(args.debug): ReportMode = 'debug'

# read the questa sim list file.
# row, col format.  each row is a questa sim run with performance counters and a particular
# branch predictor type and size. size can be multiple parameters for more complex predictors like
# local history and tage.
# <file> <type> <size>
predictorLogs = ParseBranchListFile(args.sources[0])          # digests the traces
performanceCounterList = BuildDataBase(predictorLogs)         # builds a database of performance counters by trace and then by benchmark
benchmarkFirstList = ReorderDataBase(performanceCounterList)  # reorder first by benchmark then trace
benchmarkDict = ExtractSelectedData(benchmarkFirstList)       # filters to just the desired performance counter metric

if(args.reference and args.direction): benchmarkDict['Mean'].extend(RefDataBP)
if(args.reference and args.target): benchmarkDict['Mean'].extend(RefDataBTB)
#print(benchmarkDict['Mean'])
#print(benchmarkDict['aha-mont64Speed'])
#print(benchmarkDict)

# table format
if(ReportMode == 'table'):
    ReportAsTable(benchmarkDict)

if(ReportMode == 'text'):
    ReportAsText(benchmarkDict)

if(ReportMode == 'gui'):
    ReportAsGraph(benchmarkDict, args.bar, args.FileName)

# *** this is only needed of -b (no -s)

# debug
#config0 = performanceCounterList[0][0]
#data0 = performanceCounterList[0][1]
#bench0 = data0[0]
#bench0name = bench0[0]
#bench0data = bench0[2]
#bench0BrCount = bench0data['Br Count']
#bench1 = data0[1]

#print(data0)
#print(bench0)
#print(bench1)

#print(bench0name)
#print(bench0BrCount)
