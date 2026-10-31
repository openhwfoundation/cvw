## Python Validation Utilities

This directory contains small Python scripts used to **validate and sanity-check debug test programs**.

These utilities are **not part of the Wally processor itself**. They exist solely to help developers confirm that debug features and test programs are producing the expected results during bring-up and verification.

### Purpose

The scripts in this directory are intended to:

- Validate results produced by debug test programs
- Check register and memory signature outputs
- Compare expected vs. observed debug behavior
- Assist in diagnosing discrepancies between simulation, Spike, and OpenOCD runs
- Provide quick sanity checks during debug development

### Scope

- Helper utilities for debug validation  
- Developer-facing tools  
- Optional during development  
- Not required for synthesis, simulation, or hardware execution
