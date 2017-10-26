
import macros, macro_utils
import strutils, sequtils
import opencl_generator
import math

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

#
# Primitive
#

var currentGlobalID = @[0]
var currentLocalID = @[0]

proc getGlobalID*(index: int): int =
  openclproc("get_global_id")
  return currentGlobalID[index]
proc getLocalID*(index: int): int =
  openclproc("get_global_id")
  return currentLocalID[index]

proc printfCLProc*(s: cstring) {.importc: "printf", header: "stdio.h", varargs.}
    
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

template rangeCLProc*(a, b: untyped): auto = a..b
template rangelessCLProc*(a, b: untyped): auto = a..<b

proc incCLProc*(x: var int) = x.inc
proc decCLProc*(x: var int) = x.dec
proc incCLProc*(x: var int, y: int) = x += y
proc decCLProc*(x: var int, y: int) = x -= y

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

template implPrimitive*(name: string, e: untyped): auto =
  openclproc(name)
  e
template implPrimitiveCLProc*(name: string, e: untyped) = implPrimitive(name, e)

implCLType(float32)
implCLType(int32)
implCLType(int)
implCLType(char)
implCLType(byte)

implCLType(float2)
implCLType(float3)
implCLType(float4)

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
