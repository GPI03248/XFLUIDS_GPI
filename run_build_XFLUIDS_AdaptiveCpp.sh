#!/bin/bash
set -e  # Stop on error
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
EXTERNAL_DIR="$PROJECT_ROOT/external"
INSTALL_DIR="$EXTERNAL_DIR/install"
LOG_DIR="$EXTERNAL_DIR/logs"

DIR_BOOST="$INSTALL_DIR/boost"
DIR_ACPP="$INSTALL_DIR/AdaptiveCpp"
DIR_CONDA="$INSTALL_DIR/miniconda"

SETVARS_FILE="$PROJECT_ROOT/XFLUIDS_AdaptiveCpp_setvars.sh"
ENV_NAME="XFLUIDS"

# ================= Build XFLUIDS =================
echo "[1/1] Compiling XFLUIDS..."

# Load setvars
source "$SETVARS_FILE"

BUILD_DIR="$PROJECT_ROOT/build"
echo "Entering directory: $BUILD_DIR"

rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

source "$DIR_CONDA/bin/activate"
conda activate "$ENV_NAME"

CMAKE_LOG="$LOG_DIR/5_xfluids_cmake.log"
MAKE_LOG="$LOG_DIR/5_xfluids_build.log"

# ================= cmake XFLUIDS =================
echo "      Running CMake..."

if ! cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DACPP_PATH="$DIR_ACPP" \
    -DBOOST_ROOT="$DIR_BOOST" \
    -DCOMPILER_PATH="$CONDA_PREFIX" \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/clang++" \
    -DCMAKE_INSTALL_RPATH="$CONDA_PREFIX/lib;$DIR_BOOST/lib" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    > "$CMAKE_LOG" 2>&1; then
    
    echo -e "${RED}Error: CMake configuration failed!${NC}"
    echo -e "${RED}Check log: $CMAKE_LOG${NC}"
    echo "------------------ Log Tail ------------------"
    tail -n 20 "$CMAKE_LOG"
    exit 1
fi

# ================= make XFLUIDS =================
echo "      Building XFLUIDS..."

if ! make -j$(nproc) > "$MAKE_LOG" 2>&1; then
    echo -e "${RED}Error: Compilation (Make) failed!${NC}"
    echo -e "${RED}Check log: $MAKE_LOG${NC}"
    echo "------------------ Log Tail ------------------"
    tail -n 20 "$MAKE_LOG"
    exit 1
fi

echo "      XFLUIDS based on AdaptiveCpp compilation completed."
echo ">>> Please run XFLUIDS on $PROJECT_ROOT/build"