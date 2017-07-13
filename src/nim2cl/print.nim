
import ../nim2cl

proc print*(vec: float2) =
  printf("(x:%f, y: %f)", vec.x, vec.y)
proc print*(vec: float3) =
  printf("(x:%f, y: %f, z: %f)", vec.x, vec.y, vec.z)
proc print*(vec: float4) =
  printf("(x:%f, y: %f, z: %f, w: %f)", vec.x, vec.y, vec.z, vec.w)
