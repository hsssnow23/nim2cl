
import unittest
import nim2cl

proc vartest() =
  var x = 1
  x = 5
const vartestSrc = """
__kernel void vartest() {
  int x = 1;
  x = 5;
}"""

proc fortest() =
  for i in 0..<10:
    var a = i
const fortestSrc = """
__kernel void fortest() {
  {
    int i = 0;
    {
      while ((i < 10)) {
        i = i;
        int a = i;
        i += 1;
      }
    }
  }
}"""

proc add5(x: float): float =
  return x + 5.0
proc proctest() =
  discard add5(1.0)
const proctestSrc = """
float add5_float_0(float x) {
  float result;
  result = (x + 5.0);
  return result;
}
__kernel void proctest() {
  add5_float_0(1.0);
}"""

proc convtest() =
  discard add5(1.0).float32
const convtestSrc = """
float add5_float_0(float x) {
  float result;
  result = (x + 5.0);
  return result;
}
__kernel void convtest() {
  add5_float_0(1.0);
}"""

proc ptrtest(vals: global[ptr float]) =
  discard
const ptrtestSrc = """
__kernel void ptrtest(__global float* vals) {
}"""

proc builtintest() =
  let i = getGlobalID(0)
const builtintestSrc = """
__kernel void builtintest() {
  int i = get_global_id(0);
}"""

type MyInt = object
  x: int
  y: int
proc objecttest() =
  var mi: MyInt
  mi.x = 1
  mi.y = 2
const objecttestSrc = """
typedef struct {
  int x;
  int y;
} MyInt;
__kernel void objecttest() {
  MyInt mi;
  mi.x = 1;
  mi.y = 2;
}"""

suite "nim2cl basic test":
  test "var":
    check genCLKernelSource(vartest) == vartestSrc
  test "for":
    check genCLKernelSource(fortest) == fortestSrc
  test "external proc":
    check genCLKernelSource(proctest) == proctestSrc
  test "conv":
    check genCLKernelSource(convtest) == convtestSrc
  test "ptr":
    check genCLKernelSource(ptrtest) == ptrtestSrc
  test "builtin":
    check genCLKernelSource(builtintest) == builtintestSrc
  test "object":
    check genCLKernelSource(objecttest) == objecttestSrc
