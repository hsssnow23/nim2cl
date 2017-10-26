
import ../nim2cl
import ../nim2cl/matrix
import macros

macro echoCLProc*(args: varargs[untyped]): untyped =
  result = newStmtList()
  for arg in args:
    result.add(parseExpr("printCLProc($#)" % arg.repr))
# implCLMacro(prints)

proc print*(s: string) =
  when inKernel:
    printf(s)
  else:
    stdout.write(s)
proc print*(s: float32) =
  when inKernel:
    printf("%f", s)
  else:
    stdout.write($s)

proc print*(vec: float2) =
  echo "(x", vec.x, ", y: ", vec.y, ")"
proc print*(vec: float3) =
  echo "(x", vec.x, ", y: ", vec.y, ", z:", vec.z, ")"
proc print*(vec: float4) =
  echo "(x", vec.x, ", y: ", vec.y, ", z:", vec.z, ", w:", vec.w, ")"

proc print*(m: Matrix) =
  echo(
    "matrix[",
    m.ax, " ", m.ay, " ", m.az, " ", m.aw, ", ",
    m.bx, " ", m.by, " ", m.bz, " ", m.bw, ", ",
    m.cx, " ", m.cy, " ", m.cz, " ", m.cw, ", ",
    m.tx, " ", m.ty, " ", m.tz, " ", m.tw,
    "]"
  )
