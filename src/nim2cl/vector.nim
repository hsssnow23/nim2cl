
include ../nim2cl
import colors

const zeroFloat2* = newFloat2(0.0, 0.0)
const zeroFloat3* = newFloat3(0.0, 0.0, 0.0)
const zeroFloat4* = newFloat4(0.0, 0.0, 0.0, 0.0)

proc `+`*(left: float2, right: float2): float2 =
  return newFloat2(left.x + right.x, left.y + right.y)
proc `-`*(left: float2, right: float2): float2 =
  return newFloat2(left.x - right.x, left.y - right.y)

proc `+`*(left: float3, right: float3): float3 =
  return newFloat3(left.x + right.x, left.y + right.y, left.z + right.z)
proc `-`*(left: float3, right: float3): float3 =
  return newFloat3(left.x - right.x, left.y - right.y, left.z - right.z)

proc `+`*(left: float4, right: float4): float4 =
  return newFloat4(left.x + right.x, left.y + right.y, left.z + right.z, left.w + right.w)
proc `-`*(left: float4, right: float4): float4 =
  return newFloat4(left.x - right.x, left.y - right.y, left.z - right.z, left.w - right.w)

proc `+`*(vec: float3, scalar: float): float3 =
  return newFloat3(vec.x + scalar, vec.y + scalar, vec.z + scalar)
proc `-`*(vec: float3, scalar: float): float3 =
  return newFloat3(vec.x - scalar, vec.y - scalar, vec.z - scalar)
proc `*`*(vec: float3, scalar: float): float3 =
  return newFloat3(vec.x * scalar, vec.y * scalar, vec.z * scalar)
proc `/`*(vec: float3, scalar: float): float3 =
  return newFloat3(vec.x / scalar, vec.y / scalar, vec.z / scalar)

proc `+`*(vec: float4, scalar: float): float4 =
  return newFloat4(vec.x + scalar, vec.y + scalar, vec.z + scalar, vec.w + scalar)
proc `-`*(vec: float4, scalar: float): float4 =
  return newFloat4(vec.x - scalar, vec.y - scalar, vec.z - scalar, vec.w - scalar)
proc `*`*(vec: float4, scalar: float): float4 =
  return newFloat4(vec.x * scalar, vec.y * scalar, vec.z * scalar, vec.w * scalar)
proc `/`*(vec: float4, scalar: float): float4 =
  return newFloat4(vec.x / scalar, vec.y / scalar, vec.z / scalar, vec.w / scalar)

proc len*(vec: float3): float =
  return sqrt(vec.x*vec.x + vec.y*vec.y + vec.z*vec.z)

proc cross*(left: float3, right: float3): float3 =
  return newFloat3(
    (left.y * right.z) - (left.z * right.y),
    (left.z * right.x) - (left.x * right.z),
    (left.x * right.y) - (left.y * right.x)
  )

proc normalize*(vec: float3): float3 =
  let mag = vec.len
  return newFloat3(vec.x/mag, vec.y/mag, vec.z/mag)

proc `mod`*(vec: float3, s: float): float3 =
  newFloat3(vec.x mod s, vec.y mod s, vec.z mod s)

#
# Accesor
#

proc xy*(vec: float3): float2 = newFloat2(vec.x, vec.y)

#
# Color and Vector3d
#

proc toFloat3*(color: Color): float3 =
  let (r, g, b) = color.extractRGB()
  return newFloat3(r.float32 / 255.0'f32, g.float32 / 255.0'f32, b.float32 / 255.0'f32)

proc toFloat3Array*(data: seq[Color]): seq[float3] =
  result = @[]
  for c in data:
    result.add(c.toFloat3)