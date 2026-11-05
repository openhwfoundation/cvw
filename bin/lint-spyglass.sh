#!/bin/bash

###############################################################################
# Script Name: lint_spyglass.sh
# Author: james.stine@okstate.edu 11 June 2025
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# Description:
#   Automates Synopsys SpyGlass linting for Wally RISC-V configurations.
#   Supports command-line options for custom goals and configs.
###############################################################################

# Check WALLY environment
if [ -z "$WALLY" ]; then
    echo "Error: WALLY environment variable is not set."
    echo "Please source your setup before running this script."
    exit 1
fi

# === Defaults ===
GOAL="lint/lint_rtl"
DEFAULT_CONFIGS=(rv32e rv64gc rv32gc rv32imc rv32imcb rv32i rv64i)
CONFIGS=()
BATCH_FLAG="-batch"

# === Parse command-line options ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -g|--goal)
            GOAL="$2"
            shift 2
            ;;
        -c|--configs)
            IFS=',' read -r -a CONFIGS <<< "$2"
            shift 2
            ;;
        --gui)
            BATCH_FLAG=""
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-g lint_goal] [-c config1,config2,...] [--gui]"
            echo "  -g, --goal      Linting goal (e.g., lint/lint_rtl or lint/lint_rtl_enhanced)"
            echo "  -c, --configs   Comma-separated list of configs to run (e.g., rv32e,rv64gc)"
            echo "  --gui           Run SpyGlass with Verdi GUI"
            echo "Defaults: goal=$GOAL, configs=${DEFAULT_CONFIGS[*]}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Use default configs if none provided
if [ ${#CONFIGS[@]} -eq 0 ]; then
    CONFIGS=("${DEFAULT_CONFIGS[@]}")
fi

# For GUI mode, warn if multiple configs are specified
if [ -z "$BATCH_FLAG" ] && [ ${#CONFIGS[@]} -gt 1 ]; then
    echo "Warning: Multiple configurations selected. GUI will open for each configuration sequentially."
fi

# Spyglass work directories/files
SPYGLASS_DIR="$WALLY/synthDC/spyglass"
SPYGLASS_PRJ="$SPYGLASS_DIR/cvw.prj"

# Iterate configs
errors=0
for config in "${CONFIGS[@]}"; do
    # Clean output directory
    rm -rf "$SPYGLASS_DIR/lint-spyglass-reports/$config"

    # Run SpyGlass
    echo "Running spyglass for: $config with goal: $GOAL"
    WALLY_CONFIG=$config spyglass -project "$SPYGLASS_PRJ" -goal "$GOAL" $BATCH_FLAG

    if [ $? -ne 0 ]; then
        echo "Error running spyglass for configuration: $config"
        errors=$((errors + 1))
    else
        echo "Completed: $config"
    fi
done

exit $errors
