#!/bin/bash
# this script is used to run regression inside the Dockerfile.regression
# of course, you can run it in the current environment as soon as
#   - RISCV is defined
#   - QUESTA is defined
# declare with empty string: export ABC=

# Options:
# - CVW_GIT: git clone address, only main branch supported
# - CLEAN_CVW: declared with empty string to clone
# - BUILD_ACT: declared with empty string to rebuild the ACT tests
# - RUN_QUESTA: declared with empty string to run vsim to check

# now only main branch is supported
if [ -z "${CVW_GIT}" ]; then
    echo "No CVW_GIT is provided"
    export CVW_GIT="https://github.com/openhwfoundation/cvw"
else
    echo "Using customized CVW_GIT: ${CVW_GIT}"
    # support specific branch now
    export CVW_GIT=$(echo ${CVW_GIT} | sed -E "s/tree\// -b /g")
fi

git config --global http.version HTTP/1.1

# if cvw is not available or CLEAN_CVW(empty string) is defined
if [[ ! -f "/home/${USERNAME}/cvw/setup.sh" ]] || [[ "${CLEAN_CVW}" -eq 1 ]]; then
    cd /home/${USERNAME} && rm -rf /home/${USERNAME}/cvw
    git clone --recurse-submodules  ${CVW_GIT} /home/${USERNAME}/cvw
    # if failed to clone submodules for some reason, please run `git submodule update`
fi

# Preset Environment Variable
export PATH="${RISCV}/bin:${PATH}"
export CVW_HOME="/home/${USERNAME}/cvw"
export QUESTA="/cad/mentor/questa_sim-xxxx.x_x"
export PATH="${QUESTA}/questasim/bin:${PATH}"

# cd /home/${USERNAME}/cvw && chmod +x ./setup.sh && ./setup.sh
chmod +x ${CVW_HOME}/setup.sh && source ${CVW_HOME}/setup.sh
chmod +x ${CVW_HOME}/site-setup.sh && source ${CVW_HOME}/site-setup.sh

# Overwriting
export QUESTAPATH=/cad/mentor/questa_sim-xxxx.x_x/questasim/bin

# # if you are making it alone, it works
# make

cd ${CVW_HOME}
# build the tests only if BUILD_ACT is defined with empty string
if [[ "${BUILD_ACT}" -eq 1 ]]; then
    make install && make act && make testfloat
fi

if [[ "${RUN_QUESTA}" -eq 1 ]] ; then
    if [ ! -f "${QUESTA}/questasim/bin/vsim" ]; then
        echo "Cannot find vsim with ${QUESTA}/questasim/bin/vsim"
    else
        # cd sim && ./regression-wally 2>&1 > ./regression_questa.out && cd ..
        # make verify
        regression-wally
    fi
fi

make coverage
make benchmarks

if [[ ! NO_VERILATOR -eq 1 ]]; then
    make -C sim/verilator run
    # by default it runs the arch64i on rv64gc
    cat ${CVW_HOME}/sim/verilator/logs/rv64gc_arch64i.log
fi
