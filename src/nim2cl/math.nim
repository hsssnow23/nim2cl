
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
  openclproc("min") # TODO: min in gpgpu emulator
proc max*(x: float, y: float): float =
  openclproc("max") # TODO: max in gpgpu emulator
proc min*(x: float32, y: float32): float32 =
  openclproc("min") # TODO: min in gpgpu emulator
proc max*(x: float32, y: float32): float32 =
  openclproc("max") # TODO: max in gpgpu emulator
proc min*(x: float3, y: float): float3 =
  openclproc("min") # TODO: min in gpgpu emulator
proc max*(x: float3, y: float): float3 =
  openclproc("max") # TODO: max in gpgpu emulator

proc sqrt*(x: float): float =
  openclproc("sqrt") # TODO: sqrt in gpgpu emulator
proc sqrt*(x: float32): float32 =
  openclproc("sqrt") # TODO: sqrt in gpgpu emulator

proc log*(x: float): float =
  openclproc("log") # TODO: log in gpgpu emulator
proc log*(x: float32): float32 =
  openclproc("log") # TODO: log in gpgpu emulator
