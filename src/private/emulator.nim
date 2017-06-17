
import macros, macro_utils
import strutils
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
  discard # TODO: dot in gpgpu emulator
proc normalize*(vec: float3): float3 =
  discard # TODO: normalize in gpgpu emulator
proc abs*(x: int): float =
  discard # TODO: fabs in gpgpu emulator
proc abs*(x: float3): float3 =
  discard # TODO: fabs in gpgpu emulator
proc max*(x: float3, y: float): float3 =
  discard # TODO: fabs in gpgpu emulator
proc sqrt*(x: float): float =
  discard # TODO: sqrt in gpgpu emulator
proc log*(x: float): float =
  discard # TODO: sqrt in gpgpu emulator

proc printf*(s: string, args: varargs[string, `$`]) = discard

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
    proc `accessop`*(parray: ptr `T`, index: int): `T` =
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
