
import nim2cl
import nim2cl.math
import nim2cl.print

proc printkernel(v: global[ptr float3]) {.clkernel.} =
  prints v[getGlobalID(0)], "\n"

var v = [newFloat3(1.0, 1.0, 1.0), newFloat3(2.0, 2.0, 2.0), newFloat3(3.0, 3.0, 3.0)]
execKernel(printkernel, [v.len], [1], v[0].addr)
assert genCLKernelSource(printkernel) == """
void print_string_1(char* s) {
  printf(s);
}
void print_float32_2(float s) {
  printf("%f", s);
}
void print_float3_0(float3 vec) {
  print_string_1("(x");
  print_float32_2(vec.x);
  print_string_1(", y: ");
  print_float32_2(vec.y);
  print_string_1(", z:");
  print_float32_2(vec.z);
  print_string_1(")");
}
__kernel void printkernel(__global float3* v) {
  print_float3_0(v[get_global_id(0)]);
  print_string_1("\n");
}"""
