
import ../nim2cl

proc dot*(left: float3, right: float3): float =
  openclproc("dot") # TODO: dot in gpgpu emulator
proc normalize*(vec: float3): float3 =
  openclproc("normalize") # TODO: normalize in gpgpu emulator

proc abs*(x: int): float =
  openclproc("abs") # TODO: abs in gpgpu emulator
proc abs*(x: float): float =
  openclproc("fabs") # TODO: abs in gpgpu emulator
proc abs*(x: float32): float32 =
  openclproc("fabs") # TODO: abs in gpgpu emulator
proc abs*(x: float3): float3 =
  openclproc("fabs") # TODO: abs in gpgpu emulator

proc exp*(x: float): float =
  openclproc("exp") # TODO: exp in gpgpu emulator
proc exp*(x: float32): float32 =
  openclproc("exp") # TODO: exp in gpgpu emulator

proc min*(x: float, y: float): float =
  openclproc("min")
  return system.min(x, y)
proc max*(x: float, y: float): float =
  openclproc("max")
  return system.max(x, y)
proc min*(x: float32, y: float32): float32 =
  openclproc("min")
  return system.min(x, y)
proc max*(x: float32, y: float32): float32 =
  openclproc("max")
  return system.max(x, y)
proc min*(v: float3, s: float): float3 =
  openclproc("min")
  return newFloat3(system.min(v.x, s), system.min(v.y, s), system.min(v.z, s))
proc max*(v: float3, s: float): float3 =
  openclproc("max")
  return newFloat3(system.max(v.x, s), system.max(v.y, s), system.max(v.z, s))

proc sqrt*(x: float): float =
  openclproc("sqrt") # TODO: sqrt in gpgpu emulator
proc sqrt*(x: float32): float32 =
  openclproc("sqrt") # TODO: sqrt in gpgpu emulator

proc log*(x: float): float =
  openclproc("log") # TODO: log in gpgpu emulator
proc log*(x: float32): float32 =
  openclproc("log") # TODO: log in gpgpu emulator
