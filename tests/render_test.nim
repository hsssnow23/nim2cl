
proc render*(
  dest: Global[ptr float4], width: int, height: int
) =
  let indexX = getGlobalID(0)
  let indexY = getGlobalID(1)
  let index = indexX + indexY*width

  let camPos = newFloat3(0.0, 0.0, 3.0)
  let camDir = newFloat3(0.0, 0.0, -1.0)
  let camUp = newFloat3(0.0, 1.0, 0.0)
  let camSide = cross(camDir, camUp)
  let focus = 1.8

  let rayDir = normalize(camSide*indexX.float32 + camUp*indexY.float32 + camDir*focus)

  var t = 0.0'f32
  var d = 0.0'f32
  var posOnRay = camPos
  
  for i in 1..16:
    t += d
    posOnRay = camPos + rayDir*t

defProgram renderProgram:
  render

const renderSrc = """

"""

suite "gpgpu render test":
  test "render":
    check getProgram(renderProgram) == formatSrc(renderSrc)