#!/bin/bash
set -e  # Stop on error

# ================= Configuration =================
PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
EXTERNAL_DIR="$PROJECT_ROOT/external"
PKG_DIR="$EXTERNAL_DIR/pkgs"
INSTALL_DIR="$EXTERNAL_DIR/install"
LOG_DIR="$EXTERNAL_DIR/logs"
SRC_ACPP="$EXTERNAL_DIR/AdaptiveCpp"
SRC_CANTERA="$EXTERNAL_DIR/cantera"

PKG_BOOST_TAR="$PKG_DIR/boost-1.83.0.tar.xz"
PKG_CONDA_SH="$PKG_DIR/Miniconda3-latest-Linux-x86_64.sh"

DIR_CONDA="$INSTALL_DIR/miniconda"
DIR_BOOST="$INSTALL_DIR/boost"
DIR_ACPP="$INSTALL_DIR/AdaptiveCpp"
DIR_CANTERA="$INSTALL_DIR/cantera"

ENV_NAME="XFLUIDS"

# ================ Initialize Directories =================
rm -rf "$INSTALL_DIR" "$LOG_DIR"
mkdir -p "$INSTALL_DIR" "$LOG_DIR"

echo ">>> Start installation (log_dir: $LOG_DIR)"

# ================= 1. Find CUDA =================
echo "[0/5] Checking CUDA..."
CUDA_PATH=""
if [ -n "$CUDA_HOME" ]; then 
    CUDA_PATH="$CUDA_HOME"
elif command -v nvcc >/dev/null; then
    CUDA_PATH=$(dirname $(dirname $(readlink -f $(command -v nvcc))))
elif [ -d "/usr/local/cuda" ]; then
    CUDA_PATH="/usr/local/cuda"
fi

if [ -z "$CUDA_PATH" ] || [ ! -x "$CUDA_PATH/bin/nvcc" ]; then
    echo "Error: Valid CUDA not found. Please install CUDA or set CUDA_HOME."
    exit 1
fi
echo "      CUDA detected at: $CUDA_PATH"

# ================= 2. Install Miniconda and configure environment (LLVM) =================
echo "[1/5] Installing Miniconda & LLVM Environment..."
if [ ! -f "$PKG_CONDA_SH" ]; then
    echo "Error: $PKG_CONDA_SH not found."
    exit 1
fi

# Install Miniconda
bash "$PKG_CONDA_SH" -b -p "$DIR_CONDA" -f > "$LOG_DIR/1_conda_install.log" 2>&1

# Activate Conda
source "$DIR_CONDA/bin/activate"

# Create Conda environment with LLVM 
echo "      Creating conda env '$ENV_NAME' (using conda-forge)..."
conda create -n "$ENV_NAME" python=3.10 -c conda-forge --override-channels -y > "$LOG_DIR/1_conda_create.log" 2>&1

conda activate "$ENV_NAME"

# install LLVM dependencies
echo "      Installing LLVM packages..."
conda install clang=16 clangxx=16 clangdev=16 llvmdev=16 llvm=16 llvm-tools=16 llvm-openmp \
    libstdcxx-ng cmake make ninja pkg-config ncurses zlib zstd libffi libxml2 \
    -c conda-forge --override-channels -y > "$LOG_DIR/1_conda_pkgs.log" 2>&1

echo "      LLVM installed in Conda environment."
echo "      Miniconda and LLVM environment setup completed."
echo "      Miniconda path: $DIR_CONDA"

# ================= 3. Install Boost =================
echo "[2/5] Installing Boost 1.83.0..."
# unzip install
tar -xf "$PKG_BOOST_TAR" -C "$INSTALL_DIR"

# find boost source directory 
BOOST_SRC_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "boost*" | head -n 1)

if [ -z "$BOOST_SRC_DIR" ]; then 
    echo "Error: Failed to find unpacked boost directory in $INSTALL_DIR"
    exit 1
fi

cd "$BOOST_SRC_DIR"

CLANG_BIN="$CONDA_PREFIX/bin/clang++"

./bootstrap.sh --prefix="$DIR_BOOST" > "$LOG_DIR/2_boost_bootstrap.log" 2>&1

# set user-config.jam
echo "using clang : local : $CLANG_BIN : <cxxflags>\"-std=c++14 -fPIC -I$BOOST_SRC_DIR\" ;" > user-config.jam

echo "      Installing Boost..."
./b2 install -j$(nproc) -q \
    --user-config=user-config.jam \
    toolset=clang-local \
    link=shared,static \
    threading=multi \
    --with-fiber --with-context --with-thread --with-system --with-atomic \
    --with-chrono --with-filesystem --with-program_options --with-serialization \
    --with-iostreams --with-regex --with-date_time --with-random --with-container \
    > "$LOG_DIR/2_boost_install.log" 2>&1

# Cleanup
cd "$INSTALL_DIR"
rm -rf "$BOOST_SRC_DIR"

echo "      Boost 1.83.0 completed."
echo "      Boost path: $DIR_BOOST"

# ================= 4. Install AdaptiveCpp =================
echo "[3/5] Installing AdaptiveCpp..."
BUILD_ACPP="$SRC_ACPP/build"
rm -rf "$BUILD_ACPP" && mkdir -p "$BUILD_ACPP"
cd "$BUILD_ACPP"

export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:$LD_LIBRARY_PATH"

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$DIR_ACPP" \
    -DBOOST_ROOT="$DIR_BOOST" \
    -DLLVM_DIR="$CONDA_PREFIX/lib/cmake/llvm" \
    -DCMAKE_C_COMPILER="$CONDA_PREFIX/bin/clang" \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/clang++" \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_C_FLAGS="-I$CONDA_PREFIX/include" \
    -DCMAKE_CXX_FLAGS="-I$CONDA_PREFIX/include" \
    -DCMAKE_INSTALL_RPATH="$CONDA_PREFIX/lib" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_BUILD_RPATH="$CONDA_PREFIX/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,$CONDA_PREFIX/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$CONDA_PREFIX/lib" \
    -DWITH_CUDA_BACKEND=ON \
    -DCUDA_TOOLKIT_ROOT_DIR="$CUDA_PATH" \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=OFF \
    -DWITH_LEVEL_ZERO_BACKEND=OFF \
    > "$LOG_DIR/3_acpp_cmake.log" 2>&1

make -j$(nproc) > "$LOG_DIR/3_acpp_build.log" 2>&1
make install > "$LOG_DIR/3_acpp_install.log" 2>&1

echo "      AdaptiveCpp completed."
echo "      AdaptiveCpp path: $DIR_ACPP"

# ================= 5. Install Cantera =================
echo "[4/5] Installing Cantera..."
# install Cantera dependencies
conda install scons packaging numpy cython typing_extensions ruamel.yaml jinja2 \
    -c conda-forge --override-channels -y > "$LOG_DIR/4_cantera_deps.log" 2>&1

cd "$SRC_CANTERA"
scons clean > /dev/null 2>&1 || true

# set cantera.conf
cat > cantera.conf <<EOF
prefix = '$DIR_CANTERA'
python_cmd = '$(which python)'
hdf_support = 'n'
system_eigen = 'n'
system_fmt = 'n'
system_highfive = 'n'
system_yamlcpp = 'n'
system_sundials = 'n'
system_blas_lapack = 'n'
boost_inc_dir = '$DIR_BOOST/include'
boost_lib_dir = '$DIR_BOOST/lib'
EOF

echo "      Compiling Cantera..."
scons build > "$LOG_DIR/4_cantera_build.log" 2>&1
scons install > "$LOG_DIR/4_cantera_install.log" 2>&1

echo "      Cantera completed."
echo "      Cantera path: $DIR_CANTERA"
echo ">>> All dependencies completed!"

# ================= 6. Generate setvars script =================
echo "[0/1] Generating XFLUIDS_setvars.sh..."
SETVARS_FILE="$PROJECT_ROOT/XFLUIDS_setvars.sh"

cat > "$SETVARS_FILE" <<EOF
#!/bin/bash
# Generated by install.sh

# Boost
export BOOST_ROOT=$DIR_BOOST
export LD_LIBRARY_PATH=\$BOOST_ROOT/lib:\$LD_LIBRARY_PATH
export CPLUS_INCLUDE_PATH=\$BOOST_ROOT/include:\$CPLUS_INCLUDE_PATH

# AdaptiveCpp
export ADAPTIVECPP_ROOT=$DIR_ACPP
export PATH=\$ADAPTIVECPP_ROOT/bin:\$PATH
export CPATH=\$ADAPTIVECPP_ROOT/include/AdaptiveCpp:\$CPATH
export LD_LIBRARY_PATH=\$ADAPTIVECPP_ROOT/lib:\$LD_LIBRARY_PATH

# Cantera
export CANTERA_ROOT=$DIR_CANTERA
export CPATH=\$CANTERA_ROOT/include:\$CPATH
export LD_LIBRARY_PATH=\$CANTERA_ROOT/lib:\$LD_LIBRARY_PATH

echo "XFLUIDS environment variables loaded."
EOF

chmod +x "$SETVARS_FILE"

echo "      XFLUIDS_setvars.sh completed."
echo "      XFLUIDS_setvars.sh path: $SETVARS_FILE"

# ================= 7. Build XFLUIDS =================
echo "[1/1] Compiling XFLUIDS..."

# Load setvars
source "$SETVARS_FILE"

BUILD_DIR="$PROJECT_ROOT/build"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCANTERA_ROOT="$DIR_CANTERA" \
    -DACPP_PATH="$DIR_ACPP" \
    -DBOOST_ROOT="$DIR_BOOST" \
    -DCOMPILER_PATH="$CONDA_PREFIX" \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/clang++" \
    -DCMAKE_INSTALL_RPATH="$CONDA_PREFIX/lib;$DIR_CANTERA/lib;$DIR_BOOST/lib" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    > "$LOG_DIR/5_xfluids_cmake.log" 2>&1

make -j$(nproc) > "$LOG_DIR/5_xfluids_build.log" 2>&1

echo "      XFLUIDS compilation completed."
echo ">>> Please run XFLUIDS on $PROJECT_ROOT/build"