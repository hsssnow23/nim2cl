
import ../nim2cl
import macros

macro prints*(args: varargs[untyped]): untyped =
  result = newStmtList()
  for arg in args:
    result.add(parseExpr("print($#)" % arg.repr))
macro printsCLProc*(args: varargs[untyped]): untyped =
  result = newStmtList()
  for arg in args:
    result.add(parseExpr("printCLProc($#)" % arg.repr))
# implCLMacro(prints)

proc print*(s: string) {.clproc.} =
  when inKernel:
    printf(s)
  else:
    stdout.write(s)
proc print*(s: float32) {.clproc.} =
  when inKernel:
    printf("%f", s)
  else:
    stdout.write($s)

proc print*(vec: float2) {.clproc.} =
  prints("(x", vec.x, ", y: ", vec.y, ")")
proc print*(vec: float3) {.clproc.} =
  prints("(x", vec.x, ", y: ", vec.y, ", z:", vec.z, ")")
proc print*(vec: float4) {.clproc.} =
  prints("(x", vec.x, ", y: ", vec.y, ", z:", vec.z, ", w:", vec.w, ")")
