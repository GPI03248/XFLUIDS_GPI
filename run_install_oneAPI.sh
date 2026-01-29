#!/bin/bash
set -e  # Stop on error

# ================= Configuration =================
# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT=$(cd "$(dirname "$0")" && pwd)
EXTERNAL_DIR="$PROJECT_ROOT/external"
ONEAPI_SRC_DIR="$EXTERNAL_DIR/oneAPI"
PKG_DIR="$EXTERNAL_DIR/pkgs"
INSTALL_DIR="$EXTERNAL_DIR/install"
LOG_DIR="$EXTERNAL_DIR/logs"

# 目标安装路径
DIR_ONEAPI="$INSTALL_DIR/oneapi"
DIR_BOOST="$INSTALL_DIR/boost"
FAKE_ROOT="$INSTALL_DIR/fake_root"

# 源文件名定义
FILE_ONEAPI_BASE="l_BaseKit_p_2024.0.0.49564_offline.sh"
FILE_PLUGIN_CUDA="oneapi-for-nvidia-gpus-2024.0.0-cuda-12.0-linux.sh"
FILE_PLUGIN_ROCM5="oneapi-for-amd-gpus-2024.0.0-rocm-5.4.3-linux.sh"
FILE_PLUGIN_ROCM4="oneapi-for-amd-gpus-2024.0.0-rocm-4.5.2-linux.sh"
PKG_BOOST_TAR="$PKG_DIR/boost-1.83.0.tar.xz"

# 初始化目录
rm -rf "$INSTALL_DIR" "$LOG_DIR"
mkdir -p "$INSTALL_DIR" "$LOG_DIR"
mkdir -p "$DIR_ONEAPI"
mkdir -p "$FAKE_ROOT"

echo ">>> Start installation (log_dir: $LOG_DIR)"

# 定义隔离运行函数
run_isolated() {
    env -i \
        HOME="$FAKE_ROOT" \
        XDG_CONFIG_HOME="$FAKE_ROOT/.config" \
        XDG_CACHE_HOME="$FAKE_ROOT/.cache" \
        XDG_DATA_HOME="$FAKE_ROOT/.local/share" \
        PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
        USER="$(whoami)" \
        "$@"
}

# ================= 1. GPU Detection =================
echo "[1/4] Detecting System GPU..."

TARGET_VENDOR="INTEL"
PLUGIN_SCRIPT=""

# 1.1 Check for NVIDIA
if command -v nvcc >/dev/null 2>&1 || command -v nvidia-smi >/dev/null 2>&1; then
    echo -e "      ${GREEN}NVIDIA CUDA detected.${NC}"
    TARGET_VENDOR="NVIDIA"
    PLUGIN_SCRIPT="$ONEAPI_SRC_DIR/$FILE_PLUGIN_CUDA"
    
    if command -v nvcc >/dev/null 2>&1; then
        CUDA_VER=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
        echo "      System CUDA Version: $CUDA_VER"
    else
        echo "      Warning: nvcc not found, assuming CUDA 12.0 compatible driver exists."
    fi

# 1.2 Check for AMD ROCm
elif [ -d "/opt/rocm" ] || command -v hipcc >/dev/null 2>&1; then
    echo -e "      ${GREEN}AMD ROCm detected.${NC}"
    TARGET_VENDOR="AMD"
    
    ROCM_VER=""
    if [ -f "/opt/rocm/.info/version" ]; then
        ROCM_VER=$(cat /opt/rocm/.info/version)
    elif [ -d "/opt/rocm" ]; then
        ROCM_PATH=$(readlink -f /opt/rocm)
        ROCM_VER=$(basename "$ROCM_PATH")
    fi
    echo "      System ROCm Version: $ROCM_VER"
    
    if [[ "$ROCM_VER" == 5.* ]]; then
        PLUGIN_SCRIPT="$ONEAPI_SRC_DIR/$FILE_PLUGIN_ROCM5"
        echo "      Selected Plugin: ROCm 5.4.3"
    elif [[ "$ROCM_VER" == 4.* ]]; then
        PLUGIN_SCRIPT="$ONEAPI_SRC_DIR/$FILE_PLUGIN_ROCM4"
        echo "      Selected Plugin: ROCm 4.5.2"
    else
        echo -e "      ${YELLOW}Warning: ROCm version $ROCM_VER not strictly matched.${NC}"
        echo "      Defaulting to ROCm 5.4.3 plugin..."
        PLUGIN_SCRIPT="$ONEAPI_SRC_DIR/$FILE_PLUGIN_ROCM5"
    fi
else
    echo -e "      ${YELLOW}No NVIDIA or AMD GPU dev environment detected.${NC}"
    TARGET_VENDOR="INTEL"
fi

if [ "$TARGET_VENDOR" != "INTEL" ]; then
    if [ ! -f "$PLUGIN_SCRIPT" ]; then
        echo -e "${RED}Error: Plugin installer not found at $PLUGIN_SCRIPT${NC}"
        exit 1
    fi
fi

# ================= 2. Install oneAPI Base Kit =================
echo "[2/4] Installing Intel oneAPI Base Toolkit..."
LOG_ONEAPI="$LOG_DIR/2_oneapi_install.log"
INSTALLER_ONEAPI="$ONEAPI_SRC_DIR/$FILE_ONEAPI_BASE"

if [ ! -f "$INSTALLER_ONEAPI" ]; then
    echo -e "${RED}Error: oneAPI installer not found at $INSTALLER_ONEAPI${NC}"
    exit 1
fi

echo "      Running oneAPI Silent Installer (Strict Isolation)..."

if ! run_isolated bash "$INSTALLER_ONEAPI" -a -s --action install --components default --eula accept --install-dir "$DIR_ONEAPI" > "$LOG_ONEAPI" 2>&1; then
    echo -e "${RED}Error: oneAPI installation failed!${NC}"
    echo -e "${RED}Check log: $LOG_ONEAPI${NC}"
    tail -n 20 "$LOG_ONEAPI"
    exit 1
fi

echo "      oneAPI Base Toolkit installed."

# ================= 3. Install Codeplay Plugin =================
echo "[3/4] Processing Codeplay Plugin..."

if [ "$TARGET_VENDOR" == "INTEL" ]; then
    echo "      Intel GPU detected. Skipping Codeplay plugin."
elif [ -n "$PLUGIN_SCRIPT" ]; then
    LOG_PLUGIN="$LOG_DIR/3_plugin_install.log"
    echo "      Installing Codeplay Plugin for $TARGET_VENDOR..."
    
    if ! run_isolated bash "$PLUGIN_SCRIPT" -y --install-dir "$DIR_ONEAPI" > "$LOG_PLUGIN" 2>&1; then
        echo -e "${RED}Error: Codeplay Plugin installation failed!${NC}"
        echo -e "${RED}Check log: $LOG_PLUGIN${NC}"
        tail -n 20 "$LOG_PLUGIN"
        exit 1
    fi
    echo "      Codeplay Plugin installed successfully."
fi

# ================= 4. Install Boost (Using oneAPI Clang Wrapper) =================
echo "[4/4] Installing Boost 1.83.0 (using oneAPI clang++)..."

LOG_SETVARS="$LOG_DIR/4_setvars_source.log"
ONEAPI_SETVARS="$DIR_ONEAPI/setvars.sh"

echo "      Activating oneAPI environment (Log: $LOG_SETVARS)..."

if [ ! -f "$ONEAPI_SETVARS" ]; then
    echo -e "${RED}Error: oneAPI setvars.sh not found at $ONEAPI_SETVARS${NC}"
    exit 1
fi

# [修正] 添加 --include-intel-llvm 参数
set +e
source "$ONEAPI_SETVARS" --include-intel-llvm --force > "$LOG_SETVARS" 2>&1
SETVARS_RET=$?
set -e

if [ $SETVARS_RET -ne 0 ]; then
    echo -e "${YELLOW}Warning: setvars.sh returned exit code $SETVARS_RET.${NC}"
fi

# Find Clang
REAL_CLANG=$(command -v clang++ || true)
if [[ -z "$REAL_CLANG" ]]; then
    echo -e "${RED}Error: 'clang++' not found even with --include-intel-llvm!${NC}"
    tail -n 20 "$LOG_SETVARS"
    exit 1
fi
echo "      Real Compiler found: $REAL_CLANG"

# 4.2 Prepare Boost
LOG_BOOST_BOOT="$LOG_DIR/4_boost_bootstrap.log"
LOG_BOOST_INSTALL="$LOG_DIR/4_boost_install.log"

if [ ! -f "$PKG_BOOST_TAR" ]; then
    echo -e "${RED}Error: Boost package not found at $PKG_BOOST_TAR${NC}"
    exit 1
fi

tar -xf "$PKG_BOOST_TAR" -C "$INSTALL_DIR"
BOOST_SRC_DIR=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "boost*" | head -n 1)
cd "$BOOST_SRC_DIR"

# 4.3 Create Compiler Wrapper
# [关键修复] 创建一个欺骗脚本，让 Boost 以为这是标准的 Clang
WRAPPER_SCRIPT="$INSTALL_DIR/clang_wrapper.sh"
cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
if [[ "\$@" == *"--version"* ]]; then
    # Return a fake standard clang version string to satisfy Boost's regex
    echo "clang version 16.0.0 (Intel oneAPI Compatibility)"
else
    # Pass all other commands to the real Intel clang++
    exec "$REAL_CLANG" "\$@"
fi
EOF
chmod +x "$WRAPPER_SCRIPT"
echo "      Created compiler wrapper at: $WRAPPER_SCRIPT"

# 4.4 Bootstrap
echo "      Bootstrapping Boost..."
# 依然指定 toolset=clang，后续在 user-config.jam 里把 clang 指向 wrapper
if ! ./bootstrap.sh --prefix="$DIR_BOOST" --with-toolset=clang > "$LOG_BOOST_BOOT" 2>&1; then
    echo -e "${RED}Error: Boost bootstrap failed!${NC}"
    tail -n 20 "$LOG_BOOST_BOOT"
    exit 1
fi

# 4.5 Create user-config.jam
# 指向 wrapper 脚本
echo "      Configuring build to use wrapper..."
echo "using clang : : $WRAPPER_SCRIPT ;" > user-config.jam

# 4.6 Install
echo "      Building and Installing Boost..."
if ! ./b2 install -j$(nproc) -q \
    --user-config=user-config.jam \
    toolset=clang \
    link=shared,static \
    threading=multi \
    --with-fiber --with-context --with-thread --with-system --with-atomic \
    --with-chrono --with-filesystem --with-program_options --with-serialization \
    --with-iostreams --with-regex --with-date_time --with-random --with-container \
    > "$LOG_BOOST_INSTALL" 2>&1; then
    
    echo -e "${RED}Error: Boost installation failed!${NC}"
    echo -e "${RED}Check log: $LOG_BOOST_INSTALL${NC}"
    tail -n 20 "$LOG_BOOST_INSTALL"
    exit 1
fi

# Cleanup
cd "$INSTALL_DIR"
rm -rf "$BOOST_SRC_DIR"
rm -rf "$FAKE_ROOT"
rm -f "$WRAPPER_SCRIPT" # 安装完成后删除 wrapper
echo "      Boost installation completed."

# ================= 5. Generate Environment File =================
echo "[-] Generating XFLUIDS_setvars.sh..."
SETVARS_FILE="$PROJECT_ROOT/XFLUIDS_oneAPI_setvars.sh"

cat > "$SETVARS_FILE" <<EOF
#!/bin/bash
# Generated by install.sh on $(date)

# 1. Intel oneAPI Environment
ONEAPI_SETVARS="$DIR_ONEAPI/setvars.sh"
if [ -f "\$ONEAPI_SETVARS" ]; then
    # Apply the same fix: --include-intel-llvm
    source "\$ONEAPI_SETVARS" --include-intel-llvm --force > /dev/null 2>&1 || true
else
    echo "WARNING: oneAPI setvars.sh not found."
fi

# 2. Boost Environment
export BOOST_ROOT="$DIR_BOOST"
export LD_LIBRARY_PATH="\$BOOST_ROOT/lib:\$LD_LIBRARY_PATH"
export CPLUS_INCLUDE_PATH="\$BOOST_ROOT/include:\$CPLUS_INCLUDE_PATH"

echo "XFLUIDS environment variables loaded (oneAPI + Boost)."
EOF

chmod +x "$SETVARS_FILE"

echo -e "${GREEN}>>> Installation All Completed Successfully!${NC}"
echo "    Environment script: $SETVARS_FILE"
echo "    Log directory: $LOG_DIR"