# Building AIR Tools and Runtime

## Prerequisites

**mlir-air** is built and tested on Ubuntu 20.04 with the following packages installed:
```
  cmake 3.20.6
  clang/llvm 10+
  lld
  python 3.8.x
  ninja 1.10.0
  Xilinx Vitis 2021.2 
```

In addition the following packages maybe useful: 

```

  Xilinx Vivado 2021.2/2022.1
  Xilinx Vitis 2021.2/2022.1
  Xilinx aienginev2 library from https://github.com/Xilinx/embeddedsw

```
Vivado and Vitis are used to build the platforms for available Xilinx cards with AIEs (VCK190 and VCK5000). Vitis also contains the AIE single core compiler xchesscc. The aienginev2 library is a driver backend used to configure the AIE array and used in building the AIR runtime. The aietools single core compiler and aienginev2 library are required to build binaries that run on AIE hardware.

NOTE: using the Vitis recommended settings64.sh script to set up your environement can cause tool conflicts. Setup your environment in the following order for aietools and Vitis:

```
export PATH=$PATH:<Vitis_install_path>/Vitis/2022.2/aietools/bin:<Vitis_install_path>/Vitis/2022.2/bin
```

NOTE: that you do not need the above additional Xilinx packages to make use of the AIR compiler passes. 

Building mlir-air requires several other open source packages:
  - [mlir](https://github.com/llvm/llvm-project/tree/main/mlir)
  - [mlir-aie](https://github.com/Xilinx/mlir-aie)
  - [Xilinx cmakeModules](https://github.com/Xilinx/cmakeModules)

## Building external projects on X86

The mlir-air repository should be cloned locally before beginning. 

First, run utils/setup_python_packages.sh to setup the prerequisite python packages. This script creates and installs the python packages listed in utils/requirements.txt in a virtual python environment called 'sandbox'.

```
source utils/setup_python_packages.sh
```

Next, clone and build LLVM, with the ability to target AArch64 as a cross-compiler, and with MLIR enabled. In addition, we make some common build optimizations to use a linker ('lld' or 'gold') other than 'ld' (which tends to be quite slow on large link jobs) and to link against libLLVM.so and libClang so. You may find that other options are also useful. Note that due to changing MLIR APIs, only a particular revision is expected to work.

To clone llvm and cmakeModules, see utils/clone-llvm.sh for the correct commithash. We point LLVM and subsequent tools to a common installation directory. 

```
cd utils
./clone-llvm.sh
./build-llvm-local.sh llvm build ../../install
```

Next, clone and build MLIR-AIE with paths to llvm, aienginev2, and cmakeModules repositories. Again, we use a common installation directory. Note that in the following commands, we assume that the aienginev2 library is installed in /opt/xaiengine as directed in the `Building on x86 with runtime for PCIe` section. If the aienginev2 library was installed elsewhere, be sure that the 4th argument to build mlir-aie points to that location. 
```
./clone-mlir-aie.sh
./build-mlir-aie-local.sh llvm mlir-aie/cmake/modulesXilinx /opt/xaiengine mlir-aie build ../../install
```

The MLIR-AIE tools will be able to generate binaries targetting AIEngines.

Finally, build the MLIR-AIR tools for your desired use case: 

- Building on x86
- Building on x86 for deployment on a PCIe platform with AIEs
- Building on x86 for deployment on an embedded platform with AIEs
- Building on ARM for deployment on an embedded platform with AIEs

## Building on x86

Use the following command to build the AIR tools to compile on x86:

```
./build-mlir-air.sh $SYSROOT /full/path/to/mlir-air/utils/llvm /full/path/to/mlir-air/utils/cmakeModules /full/path/to/mlir-air/utils/mlir-aie build install
```

## Building on x86 with runtime for PCIe 

In order to build and run on PCIe cards, you first have to build and install the aienginev2 library. We chose to install the library in /opt/xaiengine but it is not required for the tools to be installed there. Just ensure that when building mlir-aie and mlir-air, that you point to the directory in which the aienginev2 library was installed.

```
git clone https://github.com/jnider/aie-rt
cd aie-rt
git checkout joel-aie
cd driver/src
make -f Makefile.Linux
sudo cp -r ../include /opt/aiengine/
sudo cp libxaiengine.so* /opt/xaiengine/lib/
export LD_LIBRARY_PATH=/opt/xaiengine/lib:${LD_LIBRARY_PATH}
```

Use the following command to build the AIR tools to compile on x86 for PCIe cards (VCK5000):

```
./utils/build-mlir-air-pcie.sh utils/llvm/ utils/mlir-aie/cmake/modulesXilinx/ utils/mlir-aie/ /opt/xaiengine
```

The PCIe AIR runtime requires the use of the [AIR PCIe kernel driver](driver). The driver directory contains documentation on how to compile and load the AIR PCIe kernel driver.

Note that building a sysroot and the cross-compilation instructions are not necessary when running on x86 with the PCIe runtime.

## Environment setup

Set up your environment to use the tools you just built with the following commands:

```
export PATH=/path/to/mlir-air/install/bin:${PATH}
export PYTHONPATH=/path/to/mlir-air/install/python:${PYTHONPATH}
export LD_LIBRARY_PATH=/path/to/install/mlir-air/lib:/opt/xaiengine/lib:${LD_LIBRARY_PATH}
```

Note that if you are running on x86 with the PCIe runtime, the following path should be added to your path rather than `/path/to/mlir-air/install/bin`. 
```
export PATH=/path/to/mlir-air/install-pcie/bin:${PATH}
```

## Building hardware platforms

The instructions for building the hardware platform designs are found in the mlir-air/platforms directory:

- [xilinx_vck190_air](platforms/xilinx_vck190_air)
- [xilinx_vck5000_air](platforms/xilinx_vck5000_air)
- [xilinx_vck5000_air_scale_out](platforms/xilinx_vck5000_air_scale_out)

## Building a Sysroot

Since the MLIR-AIE tools are cross-compiling, in order to actually compile code, we need a 'sysroot' directory,
containing an ARM rootfs.  This rootfs must match what will be available in the runtime environment.
Note that copying the rootfs is often insufficient, since many root file systems include absolute links.
Absolute symbolic links can be converted to relative symbolic links using [symlinks](https://github.com/brandt/symlinks).

```sh
cd /
sudo symlinks -rc .
```
Following the VCK190 platform build steps will also create a sysroot.

## Compiling Runtime for AArch64 (partial cross-compile)

Use the following command to build the AIR tools to build on x86 and cross-compile host code for ARM:

```
???
```

## Compiling Tools and Runtime for AArch64 (full cross-compile)

Use the following command to cross-compile the AIR tools for ARM:

```
cd utils
./cross-build-llvm.sh /full/path/to/mlir-air/install-aarch64
./cross-build-mlir-aie.sh ../cmake/modules/toolchain_crosscomp_aarch64.cmake $SYSROOT /full/path/to/mlir-air/utils/cmakeModules /full/path/to/mlir-air/utils/llvm /full/path/to/mlir-air/install-aarch64 
./cross-build-mlir-air.sh ../cmake/modules/toolchain_crosscomp_aarch64.cmake $SYSROOT /full/path/to/mlir-air/utils/cmakeModules /full/path/to/mlir-air/utils/llvm /full/path/to/mlir-air/utils/mlir-aie /full/path/to/mlir-air/install-aarch64
cd ..
tar -cvf air_tools.tar.gz install-aarch64
```

## Running on the VCK5000

The first step required for running on the VCK5000 is building the hardware platform and loading it on your device. [Here](platforms/xilinx_vck5000_air) we provide documentation on how to do that. Then, the AIR tools must be installed by running the [Building external projects on X86](#building-external-projects-on-X86) followed by the [Building on x86 with runtime for PCIe](#building-on-x86-with-runtime-for-PCIe) and [Environment setup](#environment-setup). Then, the [AIR PCIe driver](driver) must be compiled and installed. Now you are ready to run tests using AIR on the VCK5000! For example, go to [Test 13](test/13_mb_add_one) and run `make` followed by `sudo ./test.elf` to run the application.



-----

<p align="center">Copyright&copy; 2022 Advanced Micro Devices, Inc.</p>
