
import emulator
import basic3d, colors

#
# vector float types
#

const ZERO_FLOAT2* = newFloat2(0.0, 0.0)
const ZERO_FLOAT3* = newFloat3(0.0, 0.0, 0.0)
const ZERO_FLOAT4* = newFloat4(0.0, 0.0, 0.0, 0.0)

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

proc `+`*(vec: float3, scalar: float32): float3 =
  return newFloat3(vec.x + scalar, vec.y + scalar, vec.z + scalar)
proc `-`*(vec: float3, scalar: float32): float3 =
  return newFloat3(vec.x - scalar, vec.y - scalar, vec.z - scalar)
proc `*`*(vec: float3, scalar: float32): float3 =
  return newFloat3(vec.x * scalar, vec.y * scalar, vec.z * scalar)
proc `/`*(vec: float3, scalar: float32): float3 =
  return newFloat3(vec.x / scalar, vec.y / scalar, vec.z / scalar)

proc `+`*(vec: float4, scalar: float32): float4 =
  return newFloat4(vec.x + scalar, vec.y + scalar, vec.z + scalar, vec.w + scalar)
proc `-`*(vec: float4, scalar: float32): float4 =
  return newFloat4(vec.x - scalar, vec.y - scalar, vec.z - scalar, vec.w - scalar)
proc `*`*(vec: float4, scalar: float32): float4 =
  return newFloat4(vec.x * scalar, vec.y * scalar, vec.z * scalar, vec.w * scalar)
proc `/`*(vec: float4, scalar: float32): float4 =
  return newFloat4(vec.x / scalar, vec.y / scalar, vec.z / scalar, vec.w / scalar)

proc cross*(left: float3, right: float3): float3 =
  return newFloat3(
    (left.y * right.z) - (left.z * right.y),
    (left.z * right.x) - (left.x * right.z),
    (left.x * right.y) - (left.y * right.x)
  )

proc print*(vec: float3) =
  echo "x:", vec.x, ",y:", vec.y, ",z:", vec.z

proc print*(vec: float4) =
  echo "x:", vec.x, ",y:", vec.y, ",z:", vec.z, ",w:", vec.w

proc toFloat3*(color: Color): float3 =
  let (r, g, b) = color.extractRGB()
  return newFloat3(r.float32 / 255.0'f32, g.float32 / 255.0'f32, b.float32 / 255.0'f32)

proc toFloat3*(vec: Vector3d): float3 =
  return newFloat3(vec.x.float32, vec.y.float32, vec.z.float32)

proc toFloat3Array*(data: seq[Color]): seq[float3] =
  result = @[]
  for c in data:
    result.add(c.toFloat3)

proc toFloat3Array*(data: seq[Vector3d]): seq[float3] =
  result = @[]
  for v in data:
    result.add(v.toFloat3)

#
# Matrix
#

type
  Matrix* = ptr float32
  CPUMatrix* = array[16, float32]

let ID_MAT* = [
  1.0'f32, 0.0, 0.0, 0.0,
  0.0,     1.0, 0.0, 0.0,
  0.0,     0.0, 1.0, 0.0,
  0.0,     0.0, 0.0, 1.0,
]

proc `*`*(mat: Global[Matrix], vec: float3): float3 =
  result.x = mat[0]*vec.x + mat[4]*vec.y + mat[8]*vec.z + mat[12]
  result.y = mat[1]*vec.x + mat[5]*vec.y + mat[9]*vec.z + mat[13]
  result.z = mat[2]*vec.x + mat[6]*vec.y + mat[10]*vec.z + mat[14]

proc toCPUMatrix*(mat: Matrix3d): CPUMatrix =
  return [
    mat.ax.float32, mat.bx.float32, mat.cx.float32, mat.tx.float32,
    mat.ay.float32, mat.by.float32, mat.cy.float32, mat.ty.float32,
    mat.az.float32, mat.bz.float32, mat.cz.float32, mat.tz.float32,
    mat.aw.float32, mat.bw.float32, mat.cw.float32, mat.tw.float32,
  ]

proc toMatrix*(mat: var CPUMatrix): Matrix =
  return mat[0].addr

implGPGPUType(Matrix)
