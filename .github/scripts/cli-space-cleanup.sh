#!/bin/bash
###########################################
## GitHub runner space cleanup
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: 30 June 2024
## Modified:
##
## Purpose: Remove unnecessary packages/directories from GitHub Actions runner

## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

# Remove unnecessary packages
removePacks=( '^llvm-.*' 'php.*' '^mongodb-.*' '^mysql-.*' '^dotnet-sdk-.*' 'azure-cli' 'google-cloud-cli' 'google-chrome-stable' 'firefox' '^powershell*' 'microsoft-edge-stable' 'mono-devel' 'hhvm' )
for pack in "${removePacks[@]}"; do
  sudo apt-get purge -y "$pack" || true
done
sudo apt-get autoremove -y || true
sudo apt-get clean || true

# Remove unnecessary directories
sudo rm -rf /usr/local/lib/android
sudo rm -rf /usr/share/dotnet
sudo rm -rf /usr/share/swift
sudo rm -rf /usr/share/miniconda
sudo rm -rf /usr/share/az*
sudo rm -rf /usr/share/gradle-*
sudo rm -rf /usr/share/sbt
sudo rm -rf /opt/ghc
sudo rm -rf /usr/local/.ghcup
sudo rm -rf /usr/local/share/powershell
sudo rm -rf /usr/local/lib/node_modules
sudo rm -rf /usr/local/julia*
sudo rm -rf /usr/local/share/chromium
sudo rm -rf /usr/local/share/vcpkg
sudo rm -rf /usr/local/games
sudo rm -rf /usr/local/sqlpackage
sudo rm -rf /usr/lib/google-cloud-sdk
sudo rm -rf /usr/lib/jvm
sudo rm -rf /usr/lib/mono
sudo rm -rf /usr/lib/R
sudo rm -rf /usr/lib/postgresql
sudo rm -rf /usr/lib/heroku
sudo rm -rf /usr/lib/firefox
sudo rm -rf /opt/hostedtoolcache

# Clean up docker images
sudo docker image prune --all --force
