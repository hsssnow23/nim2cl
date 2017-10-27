
import ../nim2cl/core

type Atomic*[T] = distinct global[ptr T]
type AtomicArray*[T] = distinct global[ptr T]

proc `[]`*(a: Atomic[uint]): uint = cast[ptr uint](a)[]
proc `[]`*(a: Atomic[float]): float = cast[ptr float](a)[]
proc `[]=`*(a: Atomic[uint], value: uint) = openclproc("atomic_xchg")
proc `[]=`*(a: Atomic[float], value: float) =
  cast[Atomic[uint]](a)[] = cast[uint](value)

proc `+=`*(a: Atomic[uint], value: uint) = openclproc("atomic_add")
proc `+=`*(a: Atomic[float], value: float) =
  let oldval = a[]
  a[] = oldval + value
