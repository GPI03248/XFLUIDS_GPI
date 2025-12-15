# XFLUIDS相关问题记录

## 2025.12.8，论文反修，需要在本地重新部署XFLUIDS，修改相关内容

### 之前gpibashrc中的记录

*for compile XFLUIDS-Latest*

`cmake -DACPP_PATH=/home/gpi/Apps/AdaptiveCpp-for-intel/OpenSYCL-for-intel ..`

`make -j`

尝试之后发现会报错，我进入到之前安装的OpenSYCL-for-intel/bin中运行acpp-info，确实是可以同时时别到b580和3070 ti

问题应该出在编译器选择，之前安装的OpenSYCL-for-intel，在安装的时候是需要去指定llvm的路径的，当初指定的路径应该是当时的/usr/lib/llvm-16，在更新系统后，修改了很多路径，虽然在之前安装好的opensycl-for-intel文件夹下面的acpp-info还是可以运行并且识别到b580和3070ti，但是他指定的clang路径不再正确。

上述的思考是正确的，在安装完成之后会有一些内容是通过绝对路径硬编码写入的，所以很多东西会找不到。

### 在ubuntu24.04上重新部署AdaptiveCpp

`github.com:AdaptiveCpp`下载develop分支最新的源码

创建build并进入

之前的cmake完整指令如下：

```bash
cmake -DLLVM_DIR=/usr/lib/llvm-16/cmake \
      -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
      -DWITH_CUDA_BACKEND=ON \
      -DWITH_LEVEL_ZERO_BACKEND=ON \
      -DCMAKE_INSTALL_PREFIX=/home/gpi-2404/Apps/AdaptiveCpp \
      ..
```

cmake时会报错，报错信息如下：

```bash
[ 22%] Performing download step (git clone) for 'ocl-headers-populate'
Cloning into 'ocl-headers-src'...
fatal: unable to access 'https://github.com/KhronosGroup/OpenCL-Headers/': Failed to connect to github.com port 443 after 133732 ms: Couldn't connect to server
Cloning into 'ocl-headers-src'...
fatal: unable to access 'https://github.com/KhronosGroup/OpenCL-Headers/': GnuTLS recv error (-110): The TLS connection was non-properly terminated.
Cloning into 'ocl-headers-src'...
fatal: unable to access 'https://github.com/KhronosGroup/OpenCL-Headers/': Failed to connect to github.com port 443 after 134926 ms: Couldn't connect to server
-- Had to git clone more than once: 3 times.
CMake Error at ocl-headers-subbuild/ocl-headers-populate-prefix/tmp/ocl-headers-populate-gitclone.cmake:39 (message):
  Failed to clone repository:
  'https://github.com/KhronosGroup/OpenCL-Headers'


gmake[2]: *** [CMakeFiles/ocl-headers-populate.dir/build.make:102: ocl-headers-populate-prefix/src/ocl-headers-populate-stamp/ocl-headers-populate-download] Error 1
gmake[1]: *** [CMakeFiles/Makefile2:83: CMakeFiles/ocl-headers-populate.dir/all] Error 2
gmake: *** [Makefile:91: all] Error 2

CMake Error at /usr/share/cmake-3.28/Modules/FetchContent.cmake:1679 (message):
  Build step for ocl-headers failed: 2
Call Stack (most recent call first):
  /usr/share/cmake-3.28/Modules/FetchContent.cmake:1819:EVAL:2 (__FetchContent_directPopulate)
  /usr/share/cmake-3.28/Modules/FetchContent.cmake:1819 (cmake_language)
  /usr/share/cmake-3.28/Modules/FetchContent.cmake:2033 (FetchContent_Populate)
  src/runtime/CMakeLists.txt:246 (FetchContent_MakeAvailable)


-- Configuring incomplete, errors occurred!
```

网络问题，AdaptiveCpp尝试通过git clone指令下载ocl-headers依赖，但是失败。

自行下载ocl-headers，并放入AdaptiveCpp根目录下新建的deps文件夹，保持AdaptiveCpp结构不被破坏。

第二次尝试cmake编译，完整的cmake编译指令如下：

```bash
cmake 	-DLLVM_DIR=/usr/lib/llvm-16/cmake \
		-DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
        -DWITH_CUDA_BACKEND=ON \
        -DWITH_LEVEL_ZERO_BACKEND=ON \
        -DCMAKE_INSTALL_PREFIX=/home/gpi-2404/Apps/AdaptiveCpp \
        -Docl-headers_SOURCE_DIR=/home/gpi-2404/Documents/AdaptiveCpp/AdaptiveCpp/deps/OpenCL-Headers \
        ..
```

但是仍然报错，且与之前报错信息相同。

检查AdaptiveCpp源码与ocl-header相关的内容如下

```c++
  include(FetchContent)
  FetchContent_Declare(ocl-headers
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenCL-Headers
    GIT_TAG 265df85aec478d14a5c5880d7bb92d7dd52714ef
  )
  
  FetchContent_MakeAvailable(ocl-headers)
  
  add_library(ocl-headers INTERFACE)
  target_include_directories(ocl-headers INTERFACE ${ocl-headers_SOURCE_DIR})
  
  FetchContent_Declare(ocl-cxx-headers
    GIT_REPOSITORY https://github.com/KhronosGroup/OpenCL-CLHPP
    GIT_TAG 67d100e70612341707725b6648ccca4c10b0dc31
  )
  FetchContent_MakeAvailable(ocl-cxx-headers)
  
  add_library(ocl-cxx-headers INTERFACE)
  target_include_directories(ocl-cxx-headers INTERFACE ${ocl-cxx-headers_SOURCE_DIR}/include)
```

源码暴露两个问题，第一个问题是***“FetchContent”***机制问题，之前使用的变量名（***“-Docl-headers_SOURCE_DIR”***）不符合CMAKELIST的***“FetchContent”***的强制覆盖规则，在Cmake的***“FetchContent”***模块中，***ocl-headers_SOURCE_DIR***通常是***FetchContent_MakeAvailable***执行后生成的结果变量，用来告诉后续代码源码在哪里，如果想要在执行前强制指定使用本地路径，从而跳过***GIT_REPOSITORY***的下载步骤，需要使用特定的变量命名格式：***FETCHCONTENT_SOURCE_DIR<大写库名>***；

第二个问题是紧贴***ocl-headers***之后还有一个***ocl-cxx-header***，所以除了OpenCL-Headers，还需要下载OpenCL-CLHPP。

完整的cmake指令如下

```bash
cmake -DLLVM_DIR=/usr/lib/llvm-16/cmake \
      -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
      -DWITH_CUDA_BACKEND=ON \
      -DWITH_LEVEL_ZERO_BACKEND=ON \
      -DCMAKE_INSTALL_PREFIX=/home/gpi-2404/Apps/AdaptiveCpp \
      -DFETCHCONTENT_SOURCE_DIR_OCL-HEADERS=/home/gpi-2404/Documents/AdaptiveCpp/AdaptiveCpp/deps/OpenCL-Headers \
      -DFETCHCONTENT_SOURCE_DIR_OCL-CXX-HEADERS=/home/gpi-2404/Documents/AdaptiveCpp/AdaptiveCpp/deps/OpenCL-CLHPP \
      ..
```

cmake完成后，执行`make -j, make install`

### 和ljl主机环境的对比情况

本地之前的版本，在cmake时，cxx compiler指向有问题

检查ljl主机环境，在加在opensycl时，不是直接在bashrc中添加export，自定义了setvars.sh，在setvars.sh里面添加了cxx的export

按照ljl主机环境，自定义setvars.sh，再做尝试。

### 目前的情况来看，应该是cantera没有安装成功的问题。

cmake在编译时去找cantera的地方是$XFLUIDS_PATH/external/install/cantera，之前放在$XFLUIDS_PATH/external下的cantera文件夹是cantera的源码文件，需要再通过cantera官方提供的SCONS脚本文件去完成install，但是SCONS脚本运行时会报错缺少python的库，现在已知的是缺少一个packaging库。

貌似不是缺少packaging库，而是conda的python找不到系统的scons，通过conda install sconc

### 在ljl主机中创建新的虚拟环境zrf_env，重头开始构建cantera的环境

```bash
conda create -n zrf_env python=3.10
cd $CANTERA_PATH
scons build
```

报错提示：

```bash
scons: Reading SConscript files ...
Python 3.10 or greater required, but you have Python 3.8.10
```

和之前的问题一样，这是因为scons调用的是系统默认的sonc，而不是当前conda虚拟环境下的scons

通过指令：

```bash
which scons
```

可以发现现在的scons指向的是

```bash
/usr/bin/scons
```

所以需要在当前虚拟环境下安装scons

```bash
conda install scons
```

再次执行`scons build`指令后报错提示：

```bash
ModuleNotFoundError: No module named 'packaging':
```

执行`conda install packaging`后正常运行

`conda install scons, packaging, numpy, cython,  typing_extensions, ruamel.yaml, jinja2`

`sudo apt-get install doxygen`

`cmake .. -DCMAKE_PREFIX_PATH=/home/ljl/Apps/anaconda3/envs/zrf_env`

修改了cmake文件，在camke的输出中可以看到确实指向了安装在anaconda/envs中的cantera，但是make -j的编译仍然报错了，

glm 4.6给出的问题是xfluids是针对cantera 2.x版本写的，安装的cantera是3.x版本，一些api接口变了，所以报错了。

### XFLUIDS在cmake时出现sudo的提示：

因为XFLUIDScmake文件中关于cantera是默认/else分支是通过`sudo apt-get install cantera*`去安装cantera。

### 源码安装cantera-3.1.0

`git clone -b v3.1.0 --recurse-submodules https://github.com/Cantera/cantera.git`

构建conda虚拟环境cantera-3.1.0，下载安装cantera所需的库：

```bash
conda create -n cantera-3.1.0 python=3.10
conda install scons packaging numpy cython typing_extensions ruamel.yaml jinja2
sudo apt-get install doxygen
conda activate cantera-3.1.0
```

在cantera根目录下创建，cantera.conf文件，并写入对应内容

```bash
prefix = '/home/ljl/zrf/Apps/cantera'
system_eigen = 'n'
system_fmt = 'n'
system_highfive = 'n'
system_yamlcpp = 'n'
system_sundials = 'n'
system_blas_lapack = 'n'
```

`prefix=/path/to/install_dir/`自定义指定cantera的安装路径，默认安装路径为conda虚拟环境的路径下

`system_xxx = 'n'`表示xxx的安装强制使用cantera根目录下ext文件夹下的源码安装，而不是使用系统的xxx

cantera.conf文件，在执行类似`scons build/clean/install/uninstall`的执行时，会生成新的空白文件，逻辑为`scon build/clean/install/uninstall`指令需要通过cantera.conf文件，即便使用默认方式，也需要cantera.conf文件存在。

如果写入cantera文件的内容包含相关注释，在执行过`scons build/clean/install/uninstall`后，会被删掉，逻辑为scons的文件SConstruct文件中的`opts.Save('cantera.conf', env)`，其作用是将当前所有生效的配置选项（即 `env` 中的变量），以键值对的形式，重新写入 `cantera.conf` 文件，最终得到一个干净的、只包含有效配置的conf文件。

### 安装好cantera-3.1.0后，XFLUIDS编译通过cantera相关内容

编译通过cantera相关内容之后，仍然出现报错，glm 4.6分析是adaptiveCpp接口不一致的问题。

XFLUIDS根目录下的script文件夹中的build_adaptivecpp.sh文件中cmake的选项：

```bash
  cmake -S $ACPP_SRC -B $ACPP_BUILD -DCMAKE_BUILD_TYPE=Release -DBOOST_ROOT=${BOOST_ROOT} -DCMAKE_INSTALL_PREFIX=$ACPP_INSTALL \
        -DWITH_ROCM_BACKEND=ON \
        -DWITH_CUDA_BACKEND=OFF -DWITH_OPENCL_BACKEND=OFF -DWITH_LEVEL_ZERO_BACKEND=OFF \
        -DROCM_PATH=$ROCM_PATH -DLLVM_DIR=$ROCM_PATH/llvm/lib/cmake/llvm \
        -DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang -DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++ \
        -DDEFAULT_TARGETS=$4:$5 \
        -DACPP_COMPILER_FEATURE_PROFILE=minimal
```

但是直接运行build_adaptivecpp.sh文件的话，会报错，在log文件中的信息如下：
```bash
make: *** No rule to make target 'install'.  Stop.
```

查看.sh文件后发现，这貌似是针对ROCm的adaptivecpp安装，所以再去检查cmake选项：

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/home/ljl/zrf/Apps/AdaptiveCpp \
    -DBOOST_ROOT=/home/ljl/Apps/OpenSYCL/boost \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=OFF \
    -DWITH_LEVEL_ZERO_BACKEND=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
    -DDEFAULT_TARGETS=cuda:sm_86 \
    -DACPP_COMPILER_FEATURE_PROFILE=minimal
```

这样安装的AdaptiveCpp仍然会报错，因为这是针对cuda编译的AdaptiveCpp，与CMakelist.txt的ACPP冲突，也可能是没有使用clang++编译AdaptiveCpp的问题，再次执行上述的cmake之后，查看cmake的输出如下：

```bash
HEAD detached at 7677cf6e
nothing to commit, working tree clean
-- The C compiler identification is GNU 9.4.0
-- The CXX compiler identification is GNU 9.4.0
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/bin/cc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/bin/c++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
CMake Warning (dev) at CMakeLists.txt:101 (find_package):
  Policy CMP0144 is not set: find_package uses upper-case <PACKAGENAME>_ROOT
  variables.  Run "cmake --help-policy CMP0144" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.

  CMake variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  Environment variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  For compatibility, find_package is ignoring the variable, but code in a
  .cmake module might still use it.
This warning is for project developers.  Use -Wno-dev to suppress it.

-- Found Boost: /home/ljl/Apps/OpenSYCL/boost/lib/cmake/Boost-1.83.0/BoostConfig.cmake (found version "1.83.0") found components: context fiber
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Failed
-- Looking for pthread_create in pthreads
-- Looking for pthread_create in pthreads - not found
-- Looking for pthread_create in pthread
-- Looking for pthread_create in pthread - found
-- Found Threads: TRUE
-- Found CUDA version 12.0.76 in /usr/local/cuda
-- Building with compiler feature profile: minimal
-- Could not find HIP cmake integration, falling back to finding hipcc
-- Could not find ROCm installation by looking for hipcc. ROCm support unavailable.
-- Performing Test HAVE_FFI_CALL
-- Performing Test HAVE_FFI_CALL - Success
-- Found FFI: /usr/lib/x86_64-linux-gnu/libffi.so
-- Performing Test Terminfo_LINKABLE
-- Performing Test Terminfo_LINKABLE - Success
-- Found Terminfo: /usr/lib/x86_64-linux-gnu/libtinfo.so
-- Found ZLIB: /usr/lib/x86_64-linux-gnu/libz.so (found version "1.2.11")
-- Found LibXml2: /usr/lib/x86_64-linux-gnu/libxml2.so (found version "2.9.10")
-- Found CURL: /usr/lib/x86_64-linux-gnu/libcurl.so (found version "7.68.0")
-- Building AdaptiveCpp against LLVM configured from /usr/lib/llvm-16/cmake
-- Selecting clang: /usr/lib/llvm-16/bin/clang++
-- Using clang include directory: /usr/lib/llvm-16/lib/clang/16/include/..
-- Looking for C++ include filesystem
-- Looking for C++ include filesystem - found
-- Performing Test CXX_FILESYSTEM_NO_LINK_NEEDED
-- Performing Test CXX_FILESYSTEM_NO_LINK_NEEDED - Success
-- Found OpenMP_C: -fopenmp (found version "4.5")
-- Found OpenMP_CXX: -fopenmp (found version "4.5")
-- Found OpenMP: TRUE (found version "4.5")
-- Default compilation target(s): cuda:sm_86
-- Configuring done (2.1s)
-- Generating done (0.0s)
-- Build files have been written to: /home/ljl/zrf/code/AdaptiveCpp/build
```

glm 4.6检查cmake输出信息给出的诊断是，AdaptiveCpp选择g++作为C++编译器来构建AdaptiveCpp库本身，AdaptiveCpp在构建时，检测到了系统中的clang++ 16，并计划在运行时时用它。

更新后的cmake指令：

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/home/ljl/zrf/Apps/AdaptiveCpp \
	-DBOOST_ROOT=/home/ljl/Apps/OpenSYCL/boost \
	-DLLVM_DIR=/usr/lib/llvm-16 \
	-DCMAKE_C_COMPILER=/usr/lib/llvm-16/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/lib/llvm-16/bin/clang++ \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=OFF \
    -DWITH_LEVEL_ZERO_BACKEND=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
```

这次的cmake指令的输出如下：

```bash
HEAD detached at 7677cf6e
nothing to commit, working tree clean
-- The C compiler identification is Clang 16.0.6
-- The CXX compiler identification is Clang 16.0.6
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/lib/llvm-16/bin/clang - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/lib/llvm-16/bin/clang++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
CMake Warning (dev) at CMakeLists.txt:101 (find_package):
  Policy CMP0144 is not set: find_package uses upper-case <PACKAGENAME>_ROOT
  variables.  Run "cmake --help-policy CMP0144" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.

  CMake variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  Environment variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  For compatibility, find_package is ignoring the variable, but code in a
  .cmake module might still use it.
This warning is for project developers.  Use -Wno-dev to suppress it.

-- Found Boost: /home/ljl/Apps/OpenSYCL/boost/lib/cmake/Boost-1.83.0/BoostConfig.cmake (found version "1.83.0") found components: context fiber
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Failed
-- Looking for pthread_create in pthreads
-- Looking for pthread_create in pthreads - not found
-- Looking for pthread_create in pthread
-- Looking for pthread_create in pthread - found
-- Found Threads: TRUE
-- Found CUDA version 12.0.76 in /usr/local/cuda
-- Building with compiler feature profile: full
-- Could not find HIP cmake integration, falling back to finding hipcc
-- Could not find ROCm installation by looking for hipcc. ROCm support unavailable.
-- Performing Test HAVE_FFI_CALL
-- Performing Test HAVE_FFI_CALL - Success
-- Found FFI: /usr/lib/x86_64-linux-gnu/libffi.so
-- Performing Test Terminfo_LINKABLE
-- Performing Test Terminfo_LINKABLE - Success
-- Found Terminfo: /usr/lib/x86_64-linux-gnu/libtinfo.so
-- Found ZLIB: /usr/lib/x86_64-linux-gnu/libz.so (found version "1.2.11")
-- Found LibXml2: /usr/lib/x86_64-linux-gnu/libxml2.so (found version "2.9.10")
-- Found CURL: /usr/lib/x86_64-linux-gnu/libcurl.so (found version "7.68.0")
CMake Warning at CMakeLists.txt:283 (message):
  Could not find LLVM in the requested location LLVM_DIR=/usr/lib/llvm-16;
  using /usr/lib/llvm-16/cmake.


-- Building AdaptiveCpp against LLVM configured from /usr/lib/llvm-16/cmake
-- Selecting clang: /usr/lib/llvm-16/bin/clang++
-- Using clang include directory: /usr/lib/llvm-16/lib/clang/16/include/..
-- Looking for C++ include filesystem
-- Looking for C++ include filesystem - found
-- Performing Test CXX_FILESYSTEM_NO_LINK_NEEDED
-- Performing Test CXX_FILESYSTEM_NO_LINK_NEEDED - Success
-- Performing Test HAS_MCPU_NATIVE
-- Performing Test HAS_MCPU_NATIVE - Success
-- Performing Test HAS_MARCH_NATIVE
-- Performing Test HAS_MARCH_NATIVE - Success
-- Found OpenMP_C: -fopenmp=libomp (found version "5.0")
-- Found OpenMP_CXX: -fopenmp=libomp (found version "5.0")
-- Found OpenMP: TRUE (found version "5.0")
-- Default compilation target(s): generic
-- Configuring done (2.9s)
-- Generating done (0.0s)
-- Build files have been written to: /home/ljl/zrf/code/AdaptiveCpp/build

```

其中的warning如下：

```bash
CMake Warning (dev) at CMakeLists.txt:101 (find_package):
  Policy CMP0144 is not set: find_package uses upper-case <PACKAGENAME>_ROOT
  variables.  Run "cmake --help-policy CMP0144" for policy details.  Use the
  cmake_policy command to set the policy and suppress this warning.

  CMake variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  Environment variable BOOST_ROOT is set to:

    /home/ljl/Apps/OpenSYCL/boost

  For compatibility, find_package is ignoring the variable, but code in a
  .cmake module might still use it.
This warning is for project developers.  Use -Wno-dev to suppress it.

CMake Warning at CMakeLists.txt:283 (message):
  Could not find LLVM in the requested location LLVM_DIR=/usr/lib/llvm-16;
  using /usr/lib/llvm-16/cmake.
```

关于boost的warning，是cmake选项中添加了`-DBOOST_ROOT=`指向的路径和系统环境路径一样，不需要去管；

关于llvm的warning，是让`-DLLVM_DIR`指向路径下的cmake，所以更新后的cmake指令如下：

```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/home/ljl/zrf/Apps/AdaptiveCpp \
	-DBOOST_ROOT=/home/ljl/Apps/OpenSYCL/boost \
	-DLLVM_DIR=/usr/lib/llvm-16/cmake \
	-DCMAKE_C_COMPILER=/usr/lib/llvm-16/bin/clang \
    -DCMAKE_CXX_COMPILER=/usr/lib/llvm-16/bin/clang++ \
    -DWITH_CUDA_BACKEND=ON \
    -DWITH_ROCM_BACKEND=OFF \
    -DWITH_OPENCL_BACKEND=OFF \
    -DWITH_LEVEL_ZERO_BACKEND=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda
```

AdaptiveCpp后续安装指令：

```bash
make -j
make install
```

完成安装后，在XFLUIDS/build路径下编译：

```bash
cmake .. \
	-DCANTERA_ROOT=/home/ljl/zrf/Apps/cantera \
	-DACPP_PATH=/home/ljl/zrf/Apps/AdaptiveCpp
```

cmake后make -j可以正确完成编译，运行时有一些新的warning：

```bash
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
'+ptx86' is not a recognized feature for this target (ignoring feature)
```

除此之外，还有一个疑问，XFLUIDS cmake的输出如下：

```bash
> -DCANTERA_ROOT=/home/ljl/zrf/Apps/cantera \
> -DACPP_PATH=/home/ljl/zrf/Apps/AdaptiveCpp
-- The CXX compiler identification is GNU 9.4.0
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/bin/c++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Find boost libs located: /home/ljl/Apps/OpenSYCL/boost/
-- Find cantera headers located: /home/ljl/zrf/Apps/cantera/include/cantera
-- Find cantera libs: /home/ljl/zrf/Apps/cantera/lib/libcantera_shared.so
CMake Warning at cmake/init_compile.cmake:67 (message):
  May occur errors without sundials against with cantera
Call Stack (most recent call first):
  cmake/init_options.cmake:12 (include)
  CMakeLists.txt:62 (include)


CMake Warning at cmake/init_compile.cmake:72 (message):
  May occur errors without fmt against with cantera
Call Stack (most recent call first):
  cmake/init_options.cmake:12 (include)
  CMakeLists.txt:62 (include)


Found ACPP_TARGETS from environment: generic
-- Find Installed Package "AdaptiveCpp"
-- CMAKE STATUS:
--   CMAKE_BUILD_TYPE: Release
--   CMAKE_CXX_COMPILER: /usr/bin/c++
--   CMAKE_CXX_FLAGS_DEBUG: -g -O0 -DDEBUG
--   CMAKE_CXX_FLAGS_RELEASE: -O3 -DNDEBUG
--   CMAKE_CXX_FLAGS:  -Wno-pass-failed -Wno-format
-- Solvers' settings: 
--   Double Precision running
--   Multi-Component: ON
--     Species' Thermo Fit: NASA
--   Capture unexpected errors: ON
--   Convention term scheme: WENO5
--     Discretization method: FDM
--     Artificial  viscosity: GLF
--     Positivity Preserving: OFF
--   Viscous Flux term: OFF
-- Sample select: 1d-reactive-st
--   Sample COP  header path: /runtime.dat/Reaction/H2O_18_reaction
--   Sample init sample path: /src/solver_Ini/sample/1D-X-Y-Z/reactive-st
--   Sample ini  file   path: /home/ljl/zrf/code/XFluids/settings/1d-reactive-st.json
-- Configuring done (0.2s)
-- Generating done (0.0s)
-- Build files have been written to: /home/ljl/zrf/code/XFluids/build
```

c++编译器指向的是/usr/bin/c++，而不是/usr/lib/llvm-16/clang++

更新一下XFLUIDS的cmake指令，尝试指向clang++：

```bash
cmake .. \
	-DCANTERA_ROOT=/home/ljl/zrf/Apps/cantera \
	-DACPP_PATH=/home/ljl/zrf/Apps/AdaptiveCpp \
	-DCOMPILER_PATH=/usr/lib/llvm-16
```

glm4.6的解释：

CMake 在配置阶段最开始时，会检测系统默认的 C++ 编译器。在您的系统上，它找到了 `/usr/bin/c++`，所以它输出了 `-- The CXX compiler identification is GNU 9.4.0`。这只是 CMake 的一个初始状态报告。

当 `find_package(AdaptiveCpp)` 被执行并成功后，`hipSYCL::hipSYCL` 这个导入目标会**强制覆盖**编译器的选择。它会告诉 CMake：“不要用你之前找到的 `g++`，请用我提供的编译器来编译这个目标。”

**`acpp`**：AdaptiveCpp 提供的编译器是 `/home/ljl/zrf/Apps/AdaptiveCpp/bin/acpp`。这个 `acpp` 本身不是一个完整的编译器，而是一个**包装器**。当您调用它时，它会用 AdaptiveCpp 在**安装时**指定的那个 Clang（在您之前的安装中，是 `clang++-16`），自动添加所有必要的 SYCL 编译标志，比如 `-fsycl`，自动链接 AdaptiveCpp 的运行时库。

`-DCOMPILER_PATH`是XFLUIDS在cmake文件中自定义的变量，其作用是在调用build_adaptivecpp.sh脚本文件去安装adaptivecpp时，告诉脚本文件，应该使用`COMPILER_PATH`指定的路径下的c++编译器（也就是clang++）去安装AdaptiveCpp，所以，之前在XFLUIDS的build文件夹下去cmake时，出现`/usr/lib/llvm-16`，是因为项目没有找到安装好的AdaptiveCpp，项目尝试通过build_adaptivecpp.sh去从源码安装AdaptiveCpp，所以才会出现`/usr/lib/llvm-16`。

### 配置XFLUIDS的oneAPI版本

XFLUIDS匹配的oneapi版本为2024.0.0，安装codeplay时，自定义的oneapi路径需要`export ONEAPI_ROOT=/home/ljl/zrf/Apps/intel/oneapi`，再运行codeplay.sh。

XFLUIDS的oneapi版本也需要指定cantera的路径，cmake指令如下：

```bash
cmake .. \
	-DCANTERA_ROOT=/home/ljl/zrf/Apps/cantera
```

