
import macros, macro_utils
import strutils

type
  float2* = object
    x*: float32
    y*: float32
    space1: float32
    space2: float32
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
  Global*[T] = T
  Local*[T] = T
  Private*[T] = T
  Constant*[T] = T

var currentGlobalID = @[0]
var currentLocalID = @[0]

proc getGlobalID*(index: int): int =
  return currentGlobalID[index]
proc getLocalID*(index: int): int =
  return currentLocalID[index]
proc dot*(left: float3, right: float3): float =
  discard # TODO: dot in gpgpu emulator
proc normalize*(vec: float3): float3 =
  discard # TODO: normalize in gpgpu emulator

proc newFloat2*(x, y: float32): float2 =
  return float2(x: x, y: y)
proc newFloat3*(x, y, z: float32): float3 =
  return float3(x: x, y: y, z: z)
proc newFloat4*(x, y, z, w: float32): float4 =
  return float4(x: x, y: y, z: z, w: w)

#
# GPGPU Type Generator
#

macro implCLType*(T: typed): untyped =
  result = newStmtList()

  let setop = !"[]="
  let accessop = !"[]"
  result.add quote do:
    proc `setop`*(parray: ptr `T`, index: int, value: `T`) =
      cast[ptr array[0, `T`]](parray)[index] = value
    proc `accessop`*(parray: ptr `T`, index: int): `T` =
      return cast[ptr array[0, `T`]](parray)[index]

implGPGPUType(float32)
implGPGPUType(float2)
implGPGPUType(float3)
implGPGPUType(float4)
implGPGPUType(int32)
implGPGPUType(int)
implGPGPUType(char)
implGPGPUType(byte)
