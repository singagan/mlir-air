# Copyright (C) 2022, Xilinx Inc. All rights reserved.
# Copyright (C) 2022, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

add_air_library(AIRConversionPasses
ConvertToAIRPass.cpp
AIRLoweringPass.cpp
AIRRtToLLVMPass.cpp
AIRToAIEPass.cpp
AIRToAsyncPass.cpp
AIRPipeline.cpp
Passes.cpp

DEPENDS
AIRConversionPassIncGen
AIRDialect
AIRRtDialect

LINK_COMPONENTS
Core

LINK_LIBS
AIRDialect
AIRRtDialect
AIRUtil
AIE
MLIRIR
MLIRLinalgUtils
MLIRLinalgTransforms
MLIRSupport
MLIRTransforms
)