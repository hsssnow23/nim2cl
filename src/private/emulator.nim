
import macros, macro_utils
import strutils, sequtils
import opencl_generator

type
  float2* = object
    x*: float32
    y*: float32
    # space1: float32
    # space2: float32
  float3* = object
    x*: float32
    y*: float32
    z*: float32
    space1: float32
  float4* = object
    x*: float32
    y*: float32
    z*: float32
    w*: float32

type
  global*[T] = T
  local*[T] = T
  private*[T] = T
  constant*[T] = T

var currentGlobalID = @[0]
var currentLocalID = @[0]

proc getGlobalID*(index: int): int = # TODO: getGlobalID in gpgpu emulator
  openclproc("get_global_id")
  return currentGlobalID[index]
proc getLocalID*(index: int): int = # TODO: getLocalID in gpgpu emulator
  openclproc("get_global_id")
  return currentLocalID[index]

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

proc printf*(s: string, args: varargs[string, `$`]) {.importc: "printf", header: "stdio.h", varargs.}

#
# constructors
#

proc newFloat2*(x, y: float32): float2 =
  result.x = x
  result.y = y
proc newFloat3*(x, y, z: float32): float3 =
  result.x = x
  result.y = y
  result.z = z
proc newFloat4*(x, y, z, w: float32): float4 =
  result.x = x
  result.y = y
  result.z = z
  result.w = w

#
# CL Type Generator
#

macro implCLType*(T: typed): untyped =
  result = newStmtList()

  let setop = !"[]="
  let accessop = !"[]"
  result.add(quote do:
    proc `setop`*(parray: ptr `T`, index: int, value: `T`) =
      cast[ptr array[0, `T`]](parray)[index] = value
    proc `accessop`*(parray: ptr `T`, index: int): var `T` =
      return cast[ptr array[0, `T`]](parray)[index]
  )

implCLType(float32)
implCLType(float2)
implCLType(float3)
implCLType(float4)
implCLType(int32)
implCLType(int)
implCLType(char)
implCLType(byte)

#
# Emulator
#

proc execKernelProc*(gworks: array[1, int], lworks: array[1, int], closure: proc ()) =
  for x in countup(0, gworks[0]-1, lworks[0]):
    for i in 0..<lworks[0]:
      currentGlobalID = @[x]
      currentLocalID = @[i]
      closure()
proc execKernelProc*(gworks: array[2, int], lworks: array[2, int], closure: proc ()) =
  for x in countup(0, gworks[0]-1, lworks[0]):
    for y in countup(0, gworks[1]-1, lworks[1]):
      for i in 0..<lworks[0]:
        for j in 0..<lworks[1]:
          currentGlobalID = @[x, y]
          currentLocalID = @[i, j]
          closure()
proc execKernelProc*(gworks: array[3, int], lworks: array[3, int], closure: proc ()) =
  for x in countup(0, gworks[0]-1, lworks[0]):
    for y in countup(0, gworks[1]-1, lworks[1]):
      for z in countup(0, gworks[2]-1, lworks[2]):
        for i in 0..<lworks[0]:
          for j in 0..<lworks[1]:
            for k in 0..<lworks[2]:
              currentGlobalID = @[x, y, z]
              currentLocalID = @[i, j, k]
              closure()

macro execKernel*(kernel: typed, gworks: typed, lworks: typed, args: varargs[untyped]): untyped =
  result = newStmtList()
  var call = nnkCall.newTree(kernel)
  for arg in args:
    call.add(arg)
  result.add(parseExpr("execKernelProc($#, $#, proc () = $#)" % [
    gworks.repr, lworks.repr, call.repr
  ]))
