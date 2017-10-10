
import nim2cl
import nim2cl.math
import nim2cl.print

proc printkernel(v: global[ptr float3]) {.kernel.} =
  prints v[getGlobalID(0)], "\n"

var v = [newFloat3(1.0, 1.0, 1.0), newFloat3(2.0, 2.0, 2.0), newFloat3(3.0, 3.0, 3.0)]
execKernel(printkernel, [v.len], [1], v[0].addr)
assert genCLKernelSource(printkernel) == """
void printCLProc_string_1(char* s) {
  printf(s);
}
void printCLProc_float32_2(float s) {
  printf("%f", s);
}
void printCLProc_float3_0(float3 vec) {
  printCLProc_string_1("(x");
  printCLProc_float32_2(vec.x);
  printCLProc_string_1(", y: ");
  printCLProc_float32_2(vec.y);
  printCLProc_string_1(", z:");
  printCLProc_float32_2(vec.z);
  printCLProc_string_1(")");
}
__kernel void printkernelKernel(__global float3* v) {
  printCLProc_float3_0(v[get_global_id(0)]);
  printCLProc_string_1("\n");
}"""
