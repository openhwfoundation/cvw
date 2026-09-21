D Wally Toolchain Docker Container

Installing RISC-V tools from source gives you maximum control, but has several disadvantages:

* Building the executables takes several hours.
* Linux is poorly standardized, and the build steps might not work on your version
* The source files are constantly changing, and the versions you download might not be compatible with this textbook flow.

Docker is a tools to run applications in a prepackaged container including all of the operating system support required.  Wally offers a ~30GB container image with the open-source tools pre-installed from Section D.1. In particular, using the container solves the long build time for gcc and the fussy installation of sail. The container runs on any platform supporting Docker, including Windows and Mac as well as Linux.  It can access files outside the container, including local installation of CAD tools such as Questa, and a local clone of the core-v-wally repository.

Docker can be run on most operating systems, including Linux, Windows, and Mac. The Wally Docker container is hosted at DockerHub (http://docker.io).

Podman is a more secure and easier-to-use variation of Docker for Linux developed by RedHat.  Both Docker and Podman run the same containers.  

D.3.1 Podman Installation on Linux

A system administrator must install Podman if it is not already present.

For Ubuntu 20.10 or later:

$ sudo apt-get -y install podman

For RedHat / Rocky:

$ sudo yum -y install podman

D.3.2 Pulling the Wally Container

Once Podman is installed, a user can pull the Wally container image.  The user must sign up for a free account at docker.io, and will be prompted for the credentials when running podman login.

$ podman login docker.io
$ podman pull docker.io/wallysoc/wally-docker:latest

D.3.3 Running the Docker Container in Podman

To activate podman with GUI support, first identify your display port in the /tmp/.X11-unix file as shown below.  For example, the user ben is on port X51.  

$ ls -la /tmp/.X11-unix/
drwxrwxrwt   2 root    root     4096 Jan  6 05:01 .
drwxrwxrwt 122 root    root    40960 Jan 17 08:09 ..
srwxrwxrwx   1 root    root        0 Jan  5 08:48 X0
srwxrwxrwx   1 xwalter xwalter     0 Jan  5 09:21 X50
srwxrwxrwx   1 ben     ben         0 Jan  6 05:01 X51

Then run podman with the display number after the X (51 in this case).  The -v options also mount the user’s home directory (/home/ben) and cad tools (/cad) to be visible from the container.  Change these as necessary based on your local system configuration.

$ podman run -it --net=host -e DISPLAY=:51 -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/ben:/home/ben -v /cad:/cad -p 8080:8080 docker.io/wallysoc/wally-docker

Podman sets up all the RISC-V software in the same location of /opt/riscv as the cad user as discussed previously.  This shared directory is called $RISCV.  This environmental variable should also be set up within the Docker container automatically and ready to use once the container is run.  It is important to understand that Docker containers are self-contained, and any data created within your container is lost when you exit the container. Therefore, be sure to work in your mounted home directory (e.g. /home/ben) to permanently save your work outside the container.

To have permission to write to your mounted home directory, you must become root inside the Wally container.  This is an acceptable practice as the security will be maintained within podman for the user that runs podman.  To become root once inside your container:

$ su   # when prompted for password, enter wally

D.3.4 Cleaning up a Podman Container

The Docker container image is large, so users may need to clean up a container when they aren’t using it anymore.
The images that are loaded can be examined, once you pull the Wally container, by typing:

$ podman images

To remove individual podman images, the following Linux command will remove the specific podman image where the image name is obtained from the  podman images command (this command also works equally well using the <Image_ID> instead of the <Image_name>, as well).

$ podman rmi -f <Image_name>

D.3.5 Running the Docker Container on Windows or MacOS

Docker Desktop is easiest to use for Mac OS or Windows and can be installed by downloading from http://docker.com.  Once the desktop application is installed, users can log into their DockerHub account through the Docker Desktop application and manage their containers easily.  

*** with Questa
*** questa unavailable native on Mac


D.3.6 Regenerating the Docker File

We use the following steps to generate the Docker file.  You can adapt them is you wish to make your own custom Docker image, such as one with commercial CAD tools installed in your local environment.

*** how to use this

# Compliance Development Environment Image
FROM debian

# UPDATE / UPGRADE
RUN apt update

# INSTALL
RUN apt install -y git gawk make texinfo bison flex build-essential python libz-
dev libexpat-dev autoconf device-tree-compiler ninja-build libpixman-1-dev build
-essential ncurses-base ncurses-bin libncurses5-dev dialog curl wget ftp libgmp-
dev python3-pip pkg-config libglib2.0-dev opam  build-essential z3 pkg-config zl
ib1g-dev verilator cpio bc vim emacs gedit nano

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
    # [Optional] Add sudo support. Omit if you don't need to install software af
ter connecting.
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
    ./configure --prefix=${RISCV} --enable-multilib --with-multilib-generator="r
v32e-ilp32e--;rv32i-ilp32--;rv32im-ilp32--;rv32iac-ilp32--;rv32imac-ilp32--;rv32
imafc-ilp32f--;rv32imafdc-ilp32d--;rv64i-lp64--;rv64ic-lp64--;rv64iac-lp64--;rv6
4imac-lp64--;rv64imafdc-lp64d--;rv64im-lp64--;" && \
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
 ln -s $RISCV/sail-riscv/c_emulator/riscv_sim_RV64 $RISCV/bin/riscv_sim_RV64 &&
\
 ln -s $RISCV/sail-riscv/c_emulator/riscv_sim_RV32 $RISCV/bin/riscv_sim_RV32

# Buildroot
WORKDIR /opt/riscv
RUN git clone --recurse-submodules https://stineje:ghp_kXIHqiMSv4tFec2BCAvrhSrIh
3KNUD06IejU@github.com/davidharrishmc/riscv-wally.git
ENV export WALLY=/opt/riscv/riscv-wally
RUN git clone https://github.com/buildroot/buildroot.git && \
  cd buildroot && \
  git checkout 2021.05 && \
  cp -r /opt/riscv/riscv-wally/linux/buildroot-config-src/wally ./board && \
  cp ./board/wally/main.config .config && \
  make --jobs

# change to cad's hometown
WORKDIR /home/cad


D.3.7 Integrating Commercial CAD Tools into a Local Docker Container



RISC-V System-on-Chip Design Lecture Notes
© 2023 D. Harris, J. Stine, , R. Thompson, and S. Harris
These notes may be used and modified for educational and/or non-commercial purposes so long as the source is attributed.
