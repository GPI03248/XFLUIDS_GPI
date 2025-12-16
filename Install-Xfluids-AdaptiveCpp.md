# 安装AdaptiveCpp

## 相关要求：

### 	版本要求为github.com/AdaptiveCpp的7677cf6 commit

### 	需要指定clang++作为安装AdaptiveCpp的编译器

cmake指令如下：

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/path/to/install_dir/AdaptiveCpp \
	-DBOOST_ROOT=/path/to/boost_dir/boost \
	-DLLVM_DIR=/path/to/llvm_dir/llvm-16/cmake \
	-DCMAKE_C_COMPILER=/path/to/llvm_dir/llvm-16/bin/clang \
    -DCMAKE_CXX_COMPILER=/path/to/llvm_dir/llvm-16/bin/clang++ \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=ON \
    -DWITH_LEVEL_ZERO_BACKEND=ON \
    -DCUDA_TOOLKIT_ROOT_DIR=/path/to/cuda_dir/cuda
```

```bash
make -j
make install
```

# 安装cantera

## 创建conda虚拟环境

```bash
conda create -n cantera-3.1.0 python=3.10
```

## 安装所需依赖

```bash
conda install scons packaging numpy cython typing_extensions ruamel.yaml jinja2
```

## 创建scons脚本配置文件cantera.conf

```bash
prefix = '/path/to/cantera_install_dir/cantera'
system_eigen = 'n'
system_fmt = 'n'
system_highfive = 'n'
system_yamlcpp = 'n'
system_sundials = 'n'
system_blas_lapack = 'n'
```

## build&&install

```bash
scons build
scons install
```

