
import unittest
import nim2cl

proc formatSrc(src: string): string =
  return src[0..^3]

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
      ;
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
  add5_float_1(1.0);
}"""

suite "nim2cl basic test":
  test "var":
    check genCLKernelSource(vartest) == vartestSrc
  test "for":
    check genCLKernelSource(fortest) == fortestSrc
  test "external proc":
    check genCLKernelSource(proctest) == proctestSrc
