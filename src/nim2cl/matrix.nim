
import ../nim2cl
import basic3d

type
  Matrix* = ptr float32
  CPUMatrix* = array[16, float32]

let ID_MAT* = [
  1.0'f32, 0.0, 0.0, 0.0,
  0.0,     1.0, 0.0, 0.0,
  0.0,     0.0, 1.0, 0.0,
  0.0,     0.0, 0.0, 1.0,
]

proc `*`*(mat: global[Matrix], vec: float3): float3 =
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

implCLType(Matrix)
