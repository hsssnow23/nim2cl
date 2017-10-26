
import nim2cl
import nim2cl.math
import nim2cl.print
import nim2cl.matrix

proc matrixkernel(m: global[ptr Matrix]) {.clkernel.} =
  prints m[getGlobalID(0)], "\n"

var m = [idMatrix, idMatrix, idMatrix]
execKernel(matrixkernel, [m.len], [1], m[0].addr)
