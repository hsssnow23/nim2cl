
import unittest
import nim2cl
import nim2cl.math

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
    int res0 = ((int)(-n));
    {
      while ((res0 <= ((int)n))) {
        i = res0;
        int a = i;
        res0 += 1;
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
  ((float)add5_float_0(1.0));
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
  double xf = 1.0;
  int xi = ((int)xf);
}"""

proc brackettest() =
  var xs: ptr int
  var first = xs[0]
  xs[0] = 9
const brackettestSrc = """
__kernel void brackettest() {
  int* xs;
  int first = xs[0];
  xs[0] = 9;
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
    };
  };
}"""

proc primitivetest() =
  discard math.min(1.0, 2.0)
  discard math.max(1.0'f32, 2.0'f32)
  discard math.min(1.0, 2.0)
  discard math.max(1.0'f32, 2.0'f32)
  discard math.abs(1)
  discard math.abs(1.0)
  discard math.abs(1.0'f32)
  printf("Hello %d!\n", 1, 2)
  let n = 1
  printf("Hello %d!\n", n)
  discard dot(newFloat3(1.0, 1.0, 1.0), newFloat3(1.0, 1.0, 1.0))
const primitiveSrc = """
float3 newFloat3__0(float x, float y, float z) {
  float3 result;
  result.x = x;
  result.y = y;
  result.z = z;
  return result;
}
__kernel void primitivetest() {
  min(1.0, 2.0);
  max(1.0, 2.0);
  min(1.0, 2.0);
  max(1.0, 2.0);
  abs(1);
  fabs(1.0);
  fabs(1.0);
  printf("Hello %d!\n", 1, 2);
  int n = 1;
  printf("Hello %d!\n", n);
  dot(newFloat3__0(1.0, 1.0, 1.0), newFloat3__0(1.0, 1.0, 1.0));
}"""

suite "nim2cl basic test":
  test "var":
    check genCLKernelSource(vartest) == vartestSrc
  test "for":
    check genCLKernelSource(fortest) == fortestSrc
  test "for2":
    check genCLKernelSource(fortest2) == fortest2Src
  test "if":
    check genCLKernelSource(iftest) == iftestSrc
  test "external proc":
    check genCLKernelSource(proctest) == proctestSrc
  test "conv":
    check genCLKernelSource(convtest) == convtestSrc
  test "ptr":
    check genCLKernelSource(ptrtest) == ptrtestSrc
  test "cast":
    check genCLKernelSource(casttest) == casttestSrc
  test "bracket expr":
    check genCLKernelSource(brackettest) == brackettestSrc
  test "builtin":
    check genCLKernelSource(builtintest) == builtintestSrc
  test "object":
    check genCLKernelSource(objecttest) == objecttestSrc
  test "external infix":
    check genCLKernelSource(externalinfixtest) == externalinfixSrc
  test "defineProgram":
    check genProgram(forandvar) == forandvarSrc
  test "primitive":
    check genCLKernelSource(primitivetest) == primitiveSrc
