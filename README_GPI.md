### 在gpi主机重新部署，ubuntu 24.04, platform: i7 12700kf + 3070ti + b580

### AdaptiveCpp安装

cmake指令

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/home/gpi-2404/code/XFLUIDS_GPI/external/install/AdaptiveCpp \
	-DBOOST_ROOT=/home/gpi-2404/Apps/boost-1.85.0 \
	-DLLVM_DIR=/usr/lib/llvm-16/cmake \
	-DCMAKE_C_COMPILER=/usr/lib/llvm-16/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/lib/llvm-16/bin/clang++ \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=ON \
    -DWITH_LEVEL_ZERO_BACKEND=ON \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
```

在打开针对level_zero后端的支持后，需要在github上下载新的第三方库，网络问题git clone失败，暂时不针对intel gpu编译，使用如下的cmake指令：

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/home/gpi-2404/code/XFLUIDS_GPI/external/install/AdaptiveCpp \
	-DBOOST_ROOT=/home/gpi-2404/Apps/boost-1.85.0 \
	-DLLVM_DIR=/usr/lib/llvm-16/cmake \
	-DCMAKE_C_COMPILER=/usr/lib/llvm-16/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/lib/llvm-16/bin/clang++ \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=OFF \
    -DWITH_LEVEL_ZERO_BACKEND=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
```

如果没有打开针对level_zero后端的支持，不需要在github上git clone额外的依赖，可以直接安装完成，acpp-info只有cpu与3070ti的信息，如下：

```bash
=================Backend information===================
Loaded backend 0: CUDA
  Found device: NVIDIA GeForce RTX 3070 Ti
Loaded backend 1: OpenMP
  Found device: AdaptiveCpp OpenMP host device
```

```bash
make -j
make install
```

### cantera安装

#### 创建conda虚拟环境

```bash
conda create -n cantera-3.1.0 python=3.10
```

#### 安装所需依赖

```bash
conda install scons packaging numpy cython typing_extensions ruamel.yaml jinja2
```

#### 创建scons脚本配置文件cantera.conf

```bash
prefix = '/home/gpi-2404/code/XFLUIDS_GPI/external/install/cantera'
system_eigen = 'n'
system_fmt = 'n'
system_highfive = 'n'
system_yamlcpp = 'n'
system_sundials = 'n'
system_blas_lapack = 'n'
```

#### build&&install

```bash
scons build
scons install
```

### 编译XFLUIDS

```bash
cmake .. \
	-DCANTERA_ROOT=/home/gpi-2404/code/XFLUIDS_GPI/external/install/cantera \
	-DACPP_PATH=/home/gpi-2404/code/XFLUIDS_GPI/external/install/AdaptiveCpp
```

