###########################################
## Dockerfile
##
## Written: james.stine@okstate.edu 28 January 2023
## Modified:
##
## Purpose: Dockerfile for Wally docker container creation
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
## https:##solderpad.org#licenses#SHL-2.1#
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################
# Compliance Development Environment Image
FROM debian

# UPDATE / UPGRADE
RUN apt update

# INSTALL
RUN apt install -y git gawk make texinfo bison flex build-essential python3 libz-dev libexpat-dev autoconf device-tree-compiler ninja-build libpixman-1-dev build-essential ncurses-base ncurses-bin libncurses5-dev dialog curl wget ftp libgmp-dev python3-pip pkg-config libglib2.0-dev opam  build-essential z3 pkg-config zlib1g-dev verilator cpio bc vim emacs gedit nano

RUN pip3 install chardet==3.0.4
RUN pip3 install urllib3==1.22
RUN pip3 install testresources
RUN pip3 install riscof --ignore-installed PyYAML
RUN echo "root:wally" | chpasswd

# ADD RISCV
WORKDIR /opt/riscv

# Create a user group 'xyzgroup'
ARG USERNAME=cad
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Change RISCV user
run chown -Rf cad:cad /opt

# Add cad user
USER $USERNAME

# SET ENVIRONMENT VARIABLES
ENV RISCV=/opt/riscv
ENV PATH=$PATH:$RISCV/bin

# TOOLCHAIN
RUN git clone https://github.com/riscv/riscv-gnu-toolchain && \
    cd riscv-gnu-toolchain && \
    ./configure --prefix=${RISCV} --enable-multilib --with-multilib-generator="rv32e-ilp32e--;rv32i-ilp32--;rv32im-ilp32--;rv32iac-ilp32--;rv32imac-ilp32--;rv32imafc-ilp32f--;rv32imafdc-ilp32d--;rv64i-lp64--;rv64ic-lp64--;rv64iac-lp64--;rv64imac-lp64--;rv64imafdc-lp64d--;rv64im-lp64--;" && \
    make --jobs && \
    make install

# QEMU
WORKDIR /opt/riscv
RUN git clone --recurse-submodules https://github.com/qemu/qemu && \
  cd qemu && \
  ./configure --target-list=riscv64-softmmu --prefix=$RISCV  && \
  make --jobs && \
  make install

# Spike
WORKDIR /opt/riscv
RUN git clone https://github.com/riscv-software-src/riscv-isa-sim && \
  mkdir riscv-isa-sim/build && \
  cd riscv-isa-sim/build && \
  ../configure --prefix=$RISCV --enable-commitlog && \
  make --jobs && \
  make install  && \
  cd ../arch_test_target/spike/device && \
  sed -i 's/--isa=rv32ic/--isa=rv32iac/' rv32i_m/privilege/Makefile.include && \
  sed -i 's/--isa=rv64ic/--isa=rv64iac/' rv64i_m/privilege/Makefile.include

# SAIL
WORKDIR /opt/riscv
RUN opam init -y --disable-sandboxing
RUN opam switch create ocaml-base-compiler.4.06.1
RUN opam install sail -y
RUN eval $(opam config env) && \
 cd $RISCV && \
 git clone https://github.com/riscv/sail-riscv.git && \
 cd sail-riscv && \
 make && \
 ARCH=RV32 make && \
 ARCH=RV64 make && \
 ln -s $RISCV/sail-riscv/c_emulator/riscv_sim_RV64 $RISCV/bin/riscv_sim_RV64 && \
 ln -s $RISCV/sail-riscv/c_emulator/riscv_sim_RV32 $RISCV/bin/riscv_sim_RV32

# Buildroot
WORKDIR /opt/riscv
RUN git clone --recurse-submodules https://github.com/openhwgroup/cvw.git
ENV export WALLY=/opt/riscv/riscv-wally
RUN git clone https://github.com/buildroot/buildroot.git && \
  cd buildroot && \
  git checkout 2021.05 && \
  cp -r /opt/riscv/riscv-wally/linux/buildroot-config-src/wally ./board && \
  cp ./board/wally/main.config .config && \
  make --jobs

# change to cad's hometown
WORKDIR /home/cad
