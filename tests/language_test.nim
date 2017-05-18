
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

proc casttest() =
  let xf = 1.0
  let xi = cast[int](xf)
const casttestSrc = """
__kernel void casttest() {
  float xf = 1.0;
  int xi = ((int)xf);
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

proc `+`(left, right: MyInt): MyInt =
  result.x = left.x + right.x
  result.y = left.y + right.y
proc externalinfixtest() =
  var left: MyInt
  var right: MyInt
  discard left + right
const externalinfixSrc = """
typedef struct {
  int x;
  int y;
} MyInt;
MyInt infix__0(MyInt left, MyInt right) {
  MyInt result;
  result.x = (left.x + right.x);
  result.y = (left.y + right.y);
  return result;
}
__kernel void externalinfixtest() {
  MyInt left;
  MyInt right;
  infix__0(left, right);
}"""

defineProgram forandvar:
  vartest
  fortest
const forandvarSrc = """
__kernel void vartest() {
  int x = 1;
  x = 5;
}
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
  test "cast":
    check genCLKernelSource(casttest) == casttestSrc
  test "builtin":
    check genCLKernelSource(builtintest) == builtintestSrc
  test "object":
    check genCLKernelSource(objecttest) == objecttestSrc
  test "external infix":
    check genCLKernelSource(externalinfixtest) == externalinfixSrc
  test "defineProgram":
    check genProgram(forandvar) == forandvarSrc
