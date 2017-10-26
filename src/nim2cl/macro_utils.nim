
import strutils
import macros

type
  Member = object
    name*: NimNode
    typ*: NimNode

proc typeMembers*(node: NimNode): seq[Member] {.compileTime.} =
  var obj: NimNode
  if node[2].kind == nnkRefTy:
    obj = node[2][0]
  elif node[2].kind == nnkPtrTy:
    obj = node[2][0]
  else:
    obj = node[2]
  result = newSeq[Member]()
  for id in obj[2].children:
    result.add(Member(name: id[0], typ: id[1]))

#
# NimStr
#

type
  NimStr* = object
    s*: string
    indentNum*: int

proc newNimStr*(): NimStr =
  return NimStr(s: "")

proc genIndent*(nimstr: NimStr): string =
  return repeat("  ", nimstr.indentNum)

template indent*(nimstr: var NimStr, body: untyped) =
  nimstr.indentNum += 1
  body
  nimstr.indentNum -= 1

proc add*(nimstr: var NimStr, s: string) =
  nimstr.s &= nimstr.genIndent() & s & "\n"

proc parseExpr*(nimstr: NimStr): NimNode {.compileTime.} =
  return nimstr.s.parseExpr()
proc parseStmt*(nimstr: NimStr): NimNode {.compileTime.} =
  return nimstr.s.parseStmt()