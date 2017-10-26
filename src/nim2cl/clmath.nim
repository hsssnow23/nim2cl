
import ../nim2cl/opencl_generator
import ../nim2cl/emulator
import math
export math

proc `mod`*(a, b: float): float = openclproc("fmod")

proc abs*(x: int): int = openclproc("abs")
proc abs*(x: float): float = openclproc("fabs")
proc abs*(x: float32): float32 = openclproc("fabs")
proc abs*(v: float3): float3 =
  newFloat3(abs(v.x), abs(v.y), abs(v.z))
  
proc min*(x: float, y: float): float = openclproc("min")
proc max*(x: float, y: float): float = openclproc("max")
proc min*(x: float32, y: float32): float32 = openclproc("min")
proc max*(x: float32, y: float32): float32 = openclproc("max")
proc min*(v: float3, s: float): float3 = openclproc("min")
proc max*(v: float3, s: float): float3 = openclproc("max")

proc exp*(x: float): float = openclproc("exp")
proc exp*(x: float32): float32 = openclproc("exp")

proc sqrt*(x: float): float = openclproc("sqrt")
proc sqrt*(x: float32): float32 = openclproc("sqrt")

proc ln*(x: float): float = openclproc("log")
proc ln*(x: float32): float32 = openclproc("log")
