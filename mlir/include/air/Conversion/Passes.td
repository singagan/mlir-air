//===- Passes.td -------------------------------------------*- tablegen -*-===//
//
// Copyright (C) 2022, Xilinx Inc. All rights reserved.
// Copyright (C) 2022, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

#ifndef AIR_CONVERSION_PASSES
#define AIR_CONVERSION_PASSES

include "mlir/Pass/PassBase.td"

def ParallelToHerd : Pass<"air-par-to-herd", "ModuleOp"> {
  let summary = "Convert parallel loops to air.herd";
  let constructor = "xilinx::air::createParallelToHerdPass()";
  let description =  [{
    This pass converts parallel loop operations to air `herd` operations. The
    parallel loops can be `scf.parallel` or `affine.parallel` operations with 1
    or 2 dimensional iteration spaces. The iteration space of the parallel loop
    will be normalized and will become the spacial iteration space of the new
    `herd`. If nested parallel loops are present then the `depth` option can
    to used to specify which loop depth to convert.
  }];
  let options = [
    Option<"clAssignDepth", "depth", "int",
          /*default=*/"-1",
          "Given a nest of parallel for loops, which depth to map to air.herd">
  ];
}

def ParallelToLaunch : Pass<"air-par-to-launch", "ModuleOp"> {
  let summary = "Convert parallel loops to air.launch";
  let constructor = "xilinx::air::createParallelToLaunchPass()";
  let description =  [{
    This pass converts parallel loop operations to air `launch` operations. The
    parallel loops can be `scf.parallel` or `affine.parallel` operations. The
    iteration space of the parallel loops will be normalized and will become the
    iteration space of the new `launch`. If nested parallel loops are present
    then the `depth` option can to used to specify which loop depth to convert.
    An air `segment` operation can optionally be inserted at the top level of
    the generated `launch` operations with the `has-air-segment` option.
  }];
  let options = [
    Option<"clAssignDepth", "depth", "int",
          /*default=*/"-1",
          "Given a nest of parallel for loops, which depth to map to air.launch">,
    Option<"clHasSegment", "has-air-segment", "bool", /*default=*/"false",
           "Whether to create an air.segment op in generated air.launch "
           "regions">,
  ];
}

def CopyToDma : Pass<"air-copy-to-dma", "ModuleOp"> {
  let summary = "Convert memcpy to air.dma_memcpy_nd";
  let constructor = "xilinx::air::createCopyToDmaPass()";
  let description =  [{
    Convert memcpy to air.dma_memcpy_nd
  }];
}

def DmaToChannel : Pass<"air-dma-to-channel", "ModuleOp"> {
  let summary = "Convert air.dma_memcpy_nd to air.channel";
  let constructor = "xilinx::air::createDmaToChannelPass()";
  let description =  [{
    Convert air.dma_memcpy_nd to air.channel
  }];
}

def AIRToAsync : Pass<"air-to-async", "ModuleOp"> {
  let summary = "AIR dialect lowering";
  let constructor = "xilinx::air::createAIRToAsyncPass()";
  let description = [{
  }];
}

def AIRLowering : Pass<"air-to-std", "ModuleOp"> {
  let summary = "AIR dialect lowering";
  let constructor = "xilinx::air::createAIRLoweringPass()";
  let description = [{
    This pass converts AIR dialect herd launch operations into loop nests
    representing the host-side control program for the herd. It also converts
    AIR dialect memcpy operations into AIRRt memcpy operations.

    ### Example - A 1x1 herd copying a 1024xi32 vector from L3 memory into an L1 buffer

    ### Input

    ```mlir
      module {
        func.func @f(%arg0: memref<1024xi32>, %arg1: memref<1024xi32>) {
          %c1 = arith.constant 1 : index
          air.herd @herd_0  tile (%arg2, %arg3) in (%arg4=%c1, %arg5=%c1) args(%arg6=%arg0, %arg7=%arg1) : memref<1024xi32>, memref<1024xi32> attributes {x_loc = 1 : i32, y_loc = 1 : i32} {
            %alloc = memref.alloc() : memref<1024xi32, 2>
            air.dma_memcpy_nd (%alloc[] [] [], %arg6[] [] []) {id = 1 : i32} : (memref<1024xi32, 2>, memref<1024xi32>)
            memref.dealloc %alloc : memref<1024xi32, 2>
            air.herd_terminator
          }
          return
        }
      }
    ```

    #### Output

    ```mlir
      func.func @f(%arg0: memref<1024xi32>, %arg1: memref<1024xi32>) {
        %c1 = arith.constant 1 : index
        %h = airrt.herd_load "herd_0" : i64
        affine.for %arg2 = 0 to 1 {
          affine.for %arg3 = 0 to 1 {
            %alloc = memref.alloc() : memref<1024xi32, 2>
            %c1_i32 = arith.constant 1 : i32
            %0 = arith.index_cast %arg3 : index to i64
            %1 = arith.index_cast %arg2 : index to i64
            %c0_i64 = arith.constant 0 : i64
            %c1_i64 = arith.constant 1 : i64
            airrt.dma_memcpy_nd(%c1_i32, %0, %1, %arg0[%c0_i64, %c0_i64, %c0_i64, %c0_i64], [%c1_i64, %c1_i64, %c1_i64, %c1_i64], [%c0_i64, %c0_i64, %c0_i64]) : (i32, i64, i64, memref<1024xi32>, [i64, i64, i64, i64], [i64, i64, i64, i64], [i64, i64, i64])
            memref.dealloc %alloc : memref<1024xi32, 2>
          } {air.herd = "inner"}
        } {air.herd = "outer"}
        return
      }
    ```
  }];
}

def AIRToAIE : Pass<"air-to-aie", "ModuleOp"> {
  let summary = "Lower air.launch_herd to AIE dialect";
  let constructor = "xilinx::air::createAIRToAIEPass()";
  let options = [
    Option<"clRowOffset", "row-offset", "unsigned", /*default=*/"1",
           "The default start row for any herds without 'y_loc' attribute.">,
    Option<"clColOffset", "col-offset", "unsigned", /*default=*/"1",
           "The default start column for any herds without 'x_loc' attribute.">,
    Option<"clEmitWhileLoop", "emit-while-loop", "bool",
           /*default=*/"false",
           "Emit a while(1) around the herd code in generated AIR.core ops.">,
    Option<"clEmitHerdLock", "emit-herd-lock", "bool",
           /*default=*/"false",
           "Acquire and release a lock at the start and end of herd execution. "
           "The default is to acquire lock 0 with value zero and release it "
           "with value 0. "
           "There is currently no way to override the default behavior.">,
    Option<"clTestPatterns", "test-patterns", "std::string",
          /*default=*/"\"\"",
           "Test the given patterns.">,
    Option<"clDevice", "device", "std::string",
          /*default=*/"\"xcvc1902\"",
           "AIE device to target.">,
  ];
  let description = [{
    This pass converts AIR dialect `herd` and `segment` operations into AIE
    dialect modules and AIRRt dialect metadata.

    One AIE dialect module is generated for each `segment` in the input
    module. Any `herd` without a parent `segment` will will also generate
    an AIE dialect module as if the `herd` has an implicit segment.

    For each `herd` in a segment a 2d array of `AIE.tile` operations is
    generated. The physical placement of the tiles is specified using the
    `herd` operation placement attributes or with `row-offset` and `col-offset`
    options to the pass. `AIE.core` operations are generated for each `AIE.tile`
    and the `herd` body is cloned into each core. 

    After generating `AIE.core` operations, several other conversions are run:

    * `memref.alloc` operations returning L1 memory are converted into static
    allocations using `AIE.buffer` operations.

    * `dma_memcpy_nd` operations in each core are lowered to `AIE.mem`
    operations to perform the transfers and `AIE.locks` are allocated to
    synchronize between the cores and the tile DMAs. As part of this 
    conversion tile DMA schedules and channel allocations are generated
    for the `AIE.mem` bodies. L3 or L2 DMA channels are allocated for
    sending or receiving data to the tile DMAs. `AIE.flow` operations
    are allocated to connect the DMAs.

    * `affine.if` operations with tile id operands are specialized, as these
    are now constants. This allows an upstream user or transformation to
    specialize parts of each `AIE.core` according to its location in the herd.

    * `air.execute` and `air.wait_all` operations are optimized away or
    transformed into sequential code.
 
    The pass will insert AIRRt metadata into the original module to describe the
    segments, herds and DMA allocations that were generated in the AIE dialect
    output modules. Runtime code for configuration and control of segments is
    generated from the AIRRt metadata by the `air-to-std` pass.

    ### Example - A 1x1 herd copying a 1024xi32 vector from L3 memory into an L1 buffer

    ### Input

    ```mlir
      func.func @f(%arg0: memref<1024xi32>, %arg1: memref<1024xi32>) {
        %c1 = arith.constant 1 : index
        air.herd @herd_0  tile (%arg2, %arg3) in (%arg4=%c1, %arg5=%c1) args(%arg6=%arg0, %arg7=%arg1) : memref<1024xi32>, memref<1024xi32> {
          %alloc = memref.alloc() : memref<1024xi32, 2>
          air.dma_memcpy_nd (%alloc[] [] [], %arg6[] [] []) {id = 1 : i32} : (memref<1024xi32, 2>, memref<1024xi32>)
          memref.dealloc %alloc : memref<1024xi32, 2>
          air.herd_terminator
        }
        return
      }
    ```

    #### Output

    The AIE resource allocation,
    ```mlir
    module @aie.segment_0 {
      %0 = AIE.tile(1, 1)
      %1 = AIE.tile(2, 0)
      %2 = AIE.lock(%0, 0)
      %3 = AIE.buffer(%0) {sym_name = "buf0"} : memref<1024xi32, 2>
      AIE.flow(%1, DMA : 0, %0, DMA : 0)
    ```
    the AIE DMA program,
    ```mlir
    %4 = AIE.mem(%0) {
      %6 = AIE.dmaStart(S2MM, 0, ^bb1, ^bb2)
    ^bb1:  // 2 preds: ^bb0, ^bb1
      AIE.useLock(%2, Acquire, 0)
      AIE.dmaBd(<%3 : memref<1024xi32, 2>, 0, 1>, 0)
      AIE.useLock(%2, Release, 1)
      cf.br ^bb1
    ^bb2:  // pred: ^bb0
      AIE.end
    }
    ```
    the AIE Core program,
    ```mlir
    %5 = AIE.core(%0) {
      cf.br ^bb1
    ^bb1:  // pred: ^bb0
      cf.br ^bb2
    ^bb2:  // pred: ^bb1
      AIE.useLock(%2, Acquire, 1)
      AIE.useLock(%2, Release, 0)
      AIE.end
    }
    ```
    and the AIRRt metadata,
    ```mlir
    airrt.module_metadata{
      airrt.segment_metadata attributes {sym_name = "segment_0"}{
        airrt.herd_metadata {dma_allocations = [{channel = 2 : i64, col = 0 : i64, id = 1 : i64, location = 2 : i64, row = 0 : i64} ], sym_name = "herd_0"}
      }
    }
    ```
  }];
}

def AIRRtToLLVM : Pass<"airrt-to-llvm", "ModuleOp"> {
  let summary = "Lower AIRRt dialect to LLVM dialect";
  let constructor = "xilinx::airrt::createAIRRtToLLVMPass()";
  let description =  [{
    This pass lowers AIRRt dialect to function calls and data structures
    matching those found in air_host.h.

    AIRRt static metadata is transformed to LLVM dialect data structures.
    The data is generated as a number of globals with external linkage.
    The data layout is closely tied the AIR runtime and the definitions in
    air_host.h.  Any changes to this pass must be reflected there.
  }];
  let options = [];
}

def AIRSplitDevices : Pass<"air-split-devices", "ModuleOp"> {
  let summary = "Split the input into one output per AIE.device op";
  let constructor = "xilinx::air::createAIRSplitDevicesPass()";
  let options = [
    Option<"clOutputPrefix", "output-prefix", "std::string",
          /*default=*/"\"-\"",
           "File name prefix for split AIE modules. "
           "Set to \'-\' for stdout (default).">,
  ];
}

def AIRPipelineToAffine : Pass<"air-pipeline-to-affine", "ModuleOp"> {
  let summary = "Lower air.pipeline stages to affine.if";
  let constructor = "xilinx::air::createAIRPipelineToAffinePass()";
  let description =  [{
    Lower air.pipeline stages to affine.if
  }];
  let options = [
    Option<"clLoweringType", "lowering-type", "std::string", 
          /*default=*/"\"buffers\"",
          "Type of lowering to use for core-to-core communication. Can be 'buffer' or 'getput'">
  ];
}

#endif
