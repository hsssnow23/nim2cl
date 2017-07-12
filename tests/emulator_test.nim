
import nim2cl
import unittest

proc addkernel(dist: global[ptr float32], src: global[ptr float32]) =
  dist[getGlobalID(0)] += src[getGlobalID(0)]
const addkernelSrc = """
__kernel void addkernel(__global float* dist, __global float* src) {
  (dist[get_global_id(0)] += src[get_global_id(0)]);
}"""

proc subkernel(dist: global[ptr float32], src: global[ptr float32]) =
  dist[getGlobalID(0)] -= src[getGlobalID(0)]
const subkernelSrc = """
__kernel void subkernel(__global float* dist, __global float* src) {
  (dist[get_global_id(0)] -= src[get_global_id(0)]);
}"""

suite "nim2cl cpu emulator test":
  test "addkernel":
    var dist = [0.0'f32, 1.0'f32, 2.0'f32, 3.0'f32, 4.0'f32, 5.0'f32]
    var src = [0.0'f32, 1.0'f32, 2.0'f32, 3.0'f32, 4.0'f32, 5.0'f32]
    execKernel(addkernel, [dist.len], [1], dist[0].addr, src[0].addr)
    check dist == [0.0'f32, 2.0'f32, 4.0'f32, 6.0'f32, 8.0'f32, 10.0'f32]
  test "addkernel src":
    check genCLKernelSource(addkernel) == addkernelSrc
  test "subkernel":
    var dist = [0.0'f32, 1.0'f32, 2.0'f32, 3.0'f32, 4.0'f32, 5.0'f32]
    var src = [0.0'f32, 1.0'f32, 2.0'f32, 3.0'f32, 4.0'f32, 5.0'f32]
    execKernel(subkernel, [dist.len], [1], dist[0].addr, src[0].addr)
    check dist == [0.0'f32, 0.0'f32, 0.0'f32, 0.0'f32, 0.0'f32, 0.0'f32]
  test "subkernel src":
    check genCLKernelSource(subkernel) == subkernelSrc
