
import unittest
include nim2cl

proc vartest() =
  var x = 1
  x = 5
const vartestSrc = """
__kernel void vartest() {
  int x = 1;
  x = 5;
}"""

proc builtintest() =
  var x = 1
  discard addr x
const builtintestSrc = """
__kernel void builtintest() {
  int x = 1;
  (&x);
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
    };
  };
}"""

proc fortest2() =
  var n = 10
  for i in -n..n:
    var a = i
const fortest2Src = """
__kernel void fortest2() {
  int n = 10;
  {
    int i;
    int tmp = (-n);
    int res = ((int)tmp);
    {
      while ((res <= ((int)n))) {
        i = res;
        int a = i;
        res += 1;
      }
    };
  };
}"""

proc fortest3() =
  var n = 10
  for i in -n..n:
    for j in -n..n:
      discard
const fortest3Src = """
__kernel void fortest3() {
  int n = 10;
  {
    int i;
    int tmp = (-n);
    int res = ((int)tmp);
    {
      while ((res <= ((int)n))) {
        i = res;
        {
          int j;
          int tmp = (-n);
          int res = ((int)tmp);
          {
            while ((res <= ((int)n))) {
              j = res;
              res += 1;
            }
          };
        };
        res += 1;
      }
    };
  };
}"""

proc iftest() =
  let x = true
  if x:
    var a = 1
  else:
    var a = 2
  let y = if x:
            1
          else:
            2                                                         
const iftestSrc = """
__kernel void iftest() {
  int x = 1;
  if (x) {
    int a = 1;
  } else {
    int a = 2;
  };
  int _nim2cl_tmp0;
  if (x) {
    _nim2cl_tmp0 = 1;
  } else {
    _nim2cl_tmp0 = 2;
  }
  int y = _nim2cl_tmp0;
}"""

proc add5(x: float): float=
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
  ((float)add5_float_0(1.0));
}"""

proc ptrtest(vals: global[ptr float]) =
  discard vals[0]
  vals[0] = 1.0
const ptrtestSrc = """
__kernel void ptrtest(__global float* vals) {
  vals[0];
  vals[0] = 1.0;
}"""

proc ptrvectest(vals: global[ptr float4]) =
  discard vals[0]
  vals[0] = newFloat4(1.0, 1.0, 1.0, 1.0)
const ptrvectestSrc = """
float4 newFloat4__0(float x, float y, float z, float w) {
  float4 result;
  result.x = x;
  result.y = y;
  result.z = z;
  result.w = w;
  return result;
}
__kernel void ptrvectest(__global float4* vals) {
  vals[0];
  vals[0] = newFloat4__0(1.0, 1.0, 1.0, 1.0);
}"""

proc casttest() =
  let xf = 1.0
  let xi = cast[int](xf)
const casttestSrc = """
__kernel void casttest() {
  double xf = 1.0;
  int xi = ((int)xf);
}"""

proc brackettest() =
  var xs: global[ptr int]
  var first = xs[0]
  xs[0] = 9
const brackettestSrc = """
__kernel void brackettest() {
  __global int* xs;
  int first = xs[0];
  xs[0] = 9;
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
MyInt add__0(MyInt left, MyInt right) {
  MyInt result;
  result.x = (left.x + right.x);
  result.y = (left.y + right.y);
  return result;
}
__kernel void externalinfixtest() {
  MyInt left;
  MyInt right;
  add__0(left, right);
}"""

proc modtest() =
  discard 1.0 mod 0.1
const modtestSrc = """
__kernel void modtest() {
  fmod(1.0, 0.1);
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
    };
  };
}"""

proc primitivetest() =
  discard getGlobalID(0)
  discard min(1.0, 2.0)
  discard max(1.0'f32, 2.0'f32)
  discard min(1.0, 2.0)
  discard max(1.0'f32, 2.0'f32)
  discard abs(1)
  discard abs(1.0)
  discard abs(1.0'f32)
const primitiveSrc = """
__kernel void primitivetest() {
  get_global_id(0);
  min(1.0, 2.0);
  max(1.0, 2.0);
  min(1.0, 2.0);
  max(1.0, 2.0);
  abs(1);
  fabs(1.0);
  fabs(1.0);
}"""

proc atomictest(dest: Atomic[float]) =
  dest[] = 1.0
const atomictestSrc = """
void ptrset_Atomicfloat_float_0(__global float* a, float value) {
  atomic_xchg(((__global uint*)a), ((uint)value));
}
__kernel void atomictest(__global float* dest) {
  ptrset_Atomicfloat_float_0(dest, 1.0);
}"""

suite "nim2cl basic test":
  test "var":
    check genCLKernelSource(vartest) == vartestSrc
  test "builtin":
    check genCLKernelSource(builtintest) == builtintestSrc
  test "for":
    check genCLKernelSource(fortest) == fortestSrc
  test "for2":
    check genCLKernelSource(fortest2) == fortest2Src
  test "for3":
    check genCLKernelSource(fortest3) == fortest3Src
  test "if":
    check genCLKernelSource(iftest) == iftestSrc
  test "external proc":
    check genCLKernelSource(proctest) == proctestSrc
  test "conv":
    check genCLKernelSource(convtest) == convtestSrc
  test "ptr":
    check genCLKernelSource(ptrtest) == ptrtestSrc
  test "ptrvec":
    check genCLKernelSource(ptrvectest) == ptrvectestSrc
  test "cast":
    check genCLKernelSource(casttest) == casttestSrc
  test "bracket expr":
    check genCLKernelSource(brackettest) == brackettestSrc
  test "object":
    check genCLKernelSource(objecttest) == objecttestSrc
  test "external infix":
    check genCLKernelSource(externalinfixtest) == externalinfixSrc
  test "mod infix":
    check genCLKernelSource(modtest) == modtestSrc
  test "defineProgram":
    check genProgram(forandvar) == forandvarSrc
  test "primitive":
    check genCLKernelSource(primitivetest) == primitiveSrc
  test "atomic":
    check genCLKernelSource(atomictest) == atomictestSrc
