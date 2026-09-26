#!/usr/bin/env -S uv run --script
# Daniel Torres 2022
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import json
import subprocess
import sys

import plotly.graph_objects as go
from plotly.subplots import make_subplots

debug = True

def loadCoremark(coremarkData):
    """loads the coremark data dictionary"""
    coremarkPath = "riscv-coremark/work/coremark.sim.log"

    keywordlist = ["CoreMark 1.0", "CoreMark Size", "MTIME", "MINSTRET", "Branches Miss Predictions", "BTB Misses"]
    for keyword in keywordlist:
        bashInst = "cat " + coremarkPath + ' | grep "' + keyword +  "\" | cut -d ':' -f 2 | cut -d \" \" -f 2 | tail -1"
        result = subprocess.run(bashInst, stdout=subprocess.PIPE, shell=True)
        if (debug): print(result)
        coremarkData[keyword] = int(result.stdout)
    if (debug): print(coremarkData)
    return coremarkData

def loadEmbench(embenchPath, embenchData):
    """loads the embench data dictionary"""
    with open(embenchPath) as f:
        embenchData = json.load(f)
    if (debug): print(embenchData)
    return embenchData

def graphEmbench(embenchSpeedOpt_SpeedData, embenchSizeOpt_SpeedData, embenchSpeedOpt_SizeData, embenchSizeOpt_SizeData):
    fig = make_subplots(rows=2, cols=4,
                        # subplot_titles( "Wally's Embench Cycles and Instret (with -O2)","Wally's Embench Cycles Per Instruction (with -O2)"))
                        subplot_titles=( "Wally's Embench Cycles and Instret (with -O2)","Wally's Embench Cycles Per Instruction (with -O2)","Wally's Embench Speed Score (with -O2)","Wally's Embench Size Score (with -O2)",
                                     "Wally's Embench Cycles and Instret (with -Os)","Wally's Embench Cycles Per Instruction (with -Os)","Wally's Embench Speed Score (with -Os)","Wally's Embench Size Score (with -Os)"))

    ydata = list(embenchSpeedOpt_SpeedData["speed results"]["detailed speed results"].keys()) + ["speed geometric mean","speed geometric sd","speed geometric range"]
    xdata = list(embenchSpeedOpt_SpeedData["speed results"]["detailed speed results"].values()) + [embenchSpeedOpt_SpeedData["speed results"]["speed geometric mean"],embenchSpeedOpt_SpeedData["speed results"]["speed geometric sd"],embenchSpeedOpt_SpeedData["speed results"]["speed geometric range"]]

    fig.add_trace( go.Bar(
            y=ydata,
            x=xdata,
            textposition='outside', text=xdata,
            orientation='h'),
            row=1,col=3)

    ydata = list(embenchSizeOpt_SpeedData["speed results"]["detailed speed results"].keys()) + ["speed geometric mean","speed geometric sd","speed geometric range"]
    xdata = list(embenchSizeOpt_SpeedData["speed results"]["detailed speed results"].values()) + [embenchSizeOpt_SpeedData["speed results"]["speed geometric mean"],embenchSizeOpt_SpeedData["speed results"]["speed geometric sd"],embenchSizeOpt_SpeedData["speed results"]["speed geometric range"]]

    fig.add_trace( go.Bar(
            y=ydata,
            x=xdata,
            textposition='outside', text=xdata,
            orientation='h'),
            row=2,col=3)


    ydata = list(embenchSpeedOpt_SizeData["size results"]["detailed size results"].keys()) + ["size geometric mean","size geometric sd","size geometric range"]
    xdata = list(embenchSpeedOpt_SizeData["size results"]["detailed size results"].values()) + [embenchSpeedOpt_SizeData["size results"]["size geometric mean"],embenchSpeedOpt_SizeData["size results"]["size geometric sd"],embenchSpeedOpt_SizeData["size results"]["size geometric range"]]

    fig.add_trace( go.Bar(
            y=ydata,
            x=xdata,
            textposition='outside', text=xdata,
            orientation='h'),
            row=1,col=4)

    ydata = list(embenchSizeOpt_SizeData["size results"]["detailed size results"].keys()) + ["size geometric mean","size geometric sd","size geometric range"]
    xdata = list(embenchSizeOpt_SizeData["size results"]["detailed size results"].values()) + [embenchSizeOpt_SizeData["size results"]["size geometric mean"],embenchSizeOpt_SizeData["size results"]["size geometric sd"],embenchSizeOpt_SizeData["size results"]["size geometric range"]]

    fig.add_trace( go.Bar(
            y=ydata,
            x=xdata,
            textposition='outside', text=xdata,
            orientation='h'),
            row=2,col=4)

    #         facet_row="Score", facet_col="Optimization Flag",
    #         category_orders={"Score": ["Cycles & Instr", "CPI", "SpeedScore", "SizeScore"],
    #                           "Optimization Flag": ["O2", "Os"]}),
    #         orientation='h')
    fig.update_layout(height=1500,width=4000, title_text="Wally Embench Scores", showlegend=False)

    fig.write_image("figure.png", engine="kaleido")
    # fig.show()


def main():
    coremarkData = {}
    embenchSizeOpt_SpeedData = {}
    embenchSpeedOpt_SpeedData = {}
    embenchSizeOpt_SizeData = {}
    embenchSpeedOpt_SizeData = {}
    coremarkData = loadCoremark(coremarkData)
    embenchSpeedOpt_SpeedData = loadEmbench("embench/actual_embench_results/wallySpeedOpt_speed.json", embenchSpeedOpt_SpeedData)
    embenchSizeOpt_SpeedData = loadEmbench("embench/actual_embench_results/wallySizeOpt_speed.json", embenchSizeOpt_SpeedData)
    embenchSpeedOpt_SizeData = loadEmbench("embench/actual_embench_results/wallySpeedOpt_size.json", embenchSpeedOpt_SizeData)
    embenchSizeOpt_SizeData = loadEmbench("embench/actual_embench_results/wallySizeOpt_size.json", embenchSizeOpt_SizeData)

    graphEmbench(embenchSpeedOpt_SpeedData, embenchSizeOpt_SpeedData, embenchSpeedOpt_SizeData, embenchSizeOpt_SizeData)

if __name__ == '__main__':
    sys.exit(main())

# "ls -Art ../addins/embench-iot/logs/*speed* | tail -n 1 " # gets most recent embench speed log
