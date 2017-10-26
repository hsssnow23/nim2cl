
include ../nim2cl

type
  Matrix* = object
    ax*, ay*, az*, aw*: float32
    bx*, by*, bz*, bw*: float32
    cx*, cy*, cz*, cw*: float32
    tx*, ty*, tz*, tw*: float32
  
proc matrix*(
  ax, ay, az, aw: float32,
  bx, by, bz, bw: float32,
  cx, cy, cz, cw: float32,
  tx, ty, tz, tw: float32
): Matrix =
  Matrix(
    ax: ax, ay: ay, az: az, aw: aw,
    bx: bx, by: by, bz: bz, bw: bw,
    cx: cx, cy: cy, cz: cz, cw: cw,
    tx: tx, ty: ty, tz: tz, tw: tw,
  )

let idMatrix* = matrix(
  1.0'f32, 0.0, 0.0, 0.0,
  0.0,     1.0, 0.0, 0.0,
  0.0,     0.0, 1.0, 0.0,
  0.0,     0.0, 0.0, 1.0,
)

proc `&`*(v: float3, m: Matrix): float3 =
  result.x = m.cx*v.z+m.bx*v.y+m.ax*v.x
  result.y = m.cy*v.z+m.by*v.y+m.ay*v.x
  result.z = m.cz*v.z+m.bz*v.y+m.az*v.x

implCLType(Matrix)
