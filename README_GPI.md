### 部署在ubuntu24.04, oneapi-2024.0.0, platform: i7-12700kf+3070ti+b580，仅oneAPI版本可以运行
### 该版本极老，在cmake时，需要删除根目录下的lib文件，再进行cmake，且该版本仍然使用"OpenSYCL"，且该版本没有cantera的相关内容
### 将1d-diffusion算例的初始化函数替换为了eulerVortex算例的初始化，相关cmake的宏开关修改为eulerVortex算例的设置，但是文件名没有更换
