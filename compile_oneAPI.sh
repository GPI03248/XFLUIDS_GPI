#!/bin/bash

set -e

rm -rf build
mkdir build
cd build
cmake .. -DBOOST_ROOT="$DIR_BOOST" -DCMAKE_EXE_LINKER_FLAGS="-L$DIR_BOOST/lib -lboost_filesystem -lboost_system"


cmake .. \
  -DCMAKE_EXE_LINKER_FLAGS="-L/home/gpi-2404/Apps/boost-1.85.0/lib -lboost_filesystem -lboost_system" \
  -DROCM_PATH="/data/gpi/Apps/rocm-6.4.3"