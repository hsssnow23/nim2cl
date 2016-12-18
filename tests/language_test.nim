
import unittest
import nim2cl
import re

proc formatSrc(src: string): string =
  return src[0..^3]

proc vartest() =
  var x = 1
  x = 5
const vartestSrc = """
__kernel void vartest() {
  int x = 1;
  x = 5;
}
"""
defProgram vartestProgram:
  vartest

proc infixtest(width: int, height: int) =
  var x = getGlobalID(0)
  var y = getGlobalID(1)
  var index = x + y*width
const infixtestSrc = """
__kernel void infixtest(int width, int height) {
  int x = get_global_id(0);
  int y = get_global_id(1);
  int index = (x + (y * width));
}
"""
defProgram infixtestProgram:
  infixtest

proc booltest(): void =
  var x = true
const booltestSrc = """
__kernel void booltest() {
  int x = 1;
}
"""
defProgram booltestProgram:
  booltest

proc newFloat4Test() =
  var f = newFloat4(1.0, 2.0, 3.0, 4.0)
const newFloat4TestSrc = """
__kernel void newFloat4Test() {
  float4 f = (float4)(1.0f, 2.0f, 3.0f, 4.0f);
}
"""
defProgram newFloat4TestProgram:
  newFloat4Test

proc iftest() =
  if true:
    var f = 1.0'f32
  else:
    var f = 2.0'f32
const iftestSrc = """
__kernel void iftest() {
  if (1) {
    float f = 1.0f;
  } else {
    float f = 2.0f;
  };
}
"""
defProgram iftestProgram:
  iftest

proc whiletest() =
  var i = 0
  while i < 10:
    var a = i
    i += 1
const whiletestSrc = """
__kernel void whiletest() {
  int i = 0;
  {
    while ((i < 10)) {
      int a = i;
      (i += 1);
    };
  };
}
"""
defProgram whiletestProgram:
  whiletest

proc fortest() =
  for i in 0..<10:
    var a = i
const fortestSrc = """
__kernel void fortest() {
  {
    int i_gensym_0 = 0;
    {
      while ((i_gensym_0 < 10)) {
        int i = i_gensym_0;
        int a = i;

        i_gensym_0 += 1;
      };
    };
  };
}
"""
defProgram fortestProgram:
  fortest

proc echotest() =
  var x = 1
  var f = 1.0'f32
  echo "x:", x, "f:", f
const echotestSrc = """
__kernel void echotest() {
  int x = 1;
  float f = 1.0f;
  printf("x:%if:%f", x, f);
}
"""
defProgram echotestProgram:
  echotest

proc add5(x: float32): float32 =
  return x + 5.0
proc proctest() =
  echo add5(1.0)
const proctestSrc = """
float add5_gensym_0(float x) {
  float result;
  result = (x + 5.0f);
  return result;
}
__kernel void proctest() {
  printf("%f", add5_gensym_0(1.0f));
}
"""
defProgram proctestProgram:
  proctest

type
  MyInt = object
    x: int
    y: int
proc add5(mi: MyInt): MyInt =
  return MyInt(x: mi.x + 5, y: mi.y + 5)
proc objecttest() =
  var a = 1
  var mi = MyInt(x: a, y: 2)
  var mi2 = add5(mi)
  echo "x:", mi2.x, "y:", mi2.y
const objecttestSrc = """
typedef struct {
  int x;
  int y;
} MyInt;
MyInt add5_gensym_1(MyInt mi) {
  MyInt result;
  MyInt tmp_gensym_2;
  tmp_gensym_2.x = (mi.x + 5);
  tmp_gensym_2.y = (mi.y + 5);
  result = tmp_gensym_2;
  return result;
}
__kernel void objecttest() {
  int a = 1;
  MyInt tmp_gensym_0;
  tmp_gensym_0.x = a;
  tmp_gensym_0.y = 2;
  MyInt mi = tmp_gensym_0;
  MyInt mi2 = add5_gensym_1(mi);
  printf("x:%iy:%i", mi2.x, mi2.y);
}
"""
defProgram objecttestProgram:
  objecttest

proc echox(mi: MyInt) =
  echo mi.x
proc objectCallTest() =
  echox(MyInt(x: 1, y: 2))
const objectCallTestSrc = """
typedef struct {
  int x;
  int y;
} MyInt;
void echox_gensym_1(MyInt mi) {
  printf("%i", mi.x);
}
__kernel void objectCallTest() {
  MyInt tmp_gensym_0;
  tmp_gensym_0.x = 1;
  tmp_gensym_0.y = 2;
  echox_gensym_1(tmp_gensym_0);
}
"""
defProgram objectCallTestProgram:
  objectCallTest

type
  Matrix = object
    data: array[16, float32]
proc matrixtest() =
  var m = Matrix(data: [1.0'f32, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0])
  echo m.data[0]
const matrixtestSrc = """
typedef struct {
  float data[16];
} Matrix;
__kernel void matrixtest() {
  Matrix tmp_gensym_0;
  tmp_gensym_0.data = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  Matrix m = tmp_gensym_0;
  printf("%f", m.data[0]);
}
"""
defProgram matrixtestProgram:
  matrixtest

proc commandtest() =
  echo "test", 1
  echo("test", 1)
const commandtestSrc = """
__kernel void commandtest() {
  printf("test1");
  printf("test1");
}
"""
defProgram commandtestProgram:
  commandtest

proc attrtest(a: Global[int], b: Local[int], c: Private[int], d: Constant[int]) =
  discard
const attrtestSrc = """
__kernel void attrtest(__global int a, __local int b, __private int c, __constant int d) {
}
"""
defProgram attrtestProgram:
  attrtest

proc isZero*(vec: float3): bool =
  if abs(vec.x) < 0.001 and abs(vec.y) < 0.001 and abs(vec.z) < 0.001:
    return true
  else:
    return false
template newV(): float3 =
  var v = newFloat3(0.0, 0.0, 0.0)
  if not v.isZero:
    v = v.normalize()
  v
proc templatetest() =
  var f = newV()
defProgram templateProgram:
  templatetest
const templateSrc = """
bool isZero_gensym_0(float3 vec) {
  bool result;
  if ((((fabs(vec.x) < 0.001f) && (fabs(vec.y) < 0.001f)) && (fabs(vec.z) < 0.001f))) {
    result = 1;
    return result;
  } else {
    result = 0;
    return result;
  };
}
__kernel void templatetest() {
  float3 v = (float3)(0.0f, 0.0f, 0.0f);
  if (!(isZero_gensym_0(v))) {
    v = normalize(v);
  };
  float3 f = v;
}
"""

suite "gpgpu language test":
  test "variable":
    check getProgram(vartestProgram) == formatSrc(vartestSrc)
  test "infix":
    check getProgram(infixtestProgram) == formatSrc(infixtestSrc)
  test "bool":
    check getProgram(booltestProgram) == formatSrc(booltestSrc)
  test "newFloat4":
    check getProgram(newFloat4TestProgram) == formatSrc(newFloat4TestSrc)
  test "if":
    check getProgram(iftestProgram) == formatSrc(iftestSrc)
  test "while":
    check getProgram(whiletestProgram) == formatSrc(whiletestSrc)
  test "for":
    check getProgram(fortestProgram) == formatSrc(fortestSrc)
  test "echo":
    check getProgram(echotestProgram) == formatSrc(echotestSrc)
  test "external proc":
    check getProgram(proctestProgram) == formatSrc(proctestSrc)
  test "object":
    check getProgram(objecttestProgram) == formatSrc(objecttestSrc)
  test "object call":
    check getProgram(objectCallTestProgram) == formatSrc(objectCallTestSrc)
  test "matrix":
    check getProgram(matrixtestProgram) == formatSrc(matrixtestSrc)
  test "command":
    check getProgram(commandtestProgram) == formatSrc(commandtestSrc)
  test "attribute":
    check getProgram(attrtestProgram) == formatSrc(attrtestSrc)
  test "template":
    check getProgram(templateProgram) == formatSrc(templateSrc)
