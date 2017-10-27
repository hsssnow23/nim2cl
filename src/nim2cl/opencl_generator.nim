
import macros
import strutils, sequtils
import tables, hashes

export macros
export strutils
export sequtils

type
  PrimitiveError* = object of Exception

proc primerror*(name: string) =
  raise newException(PrimitiveError, "shouldn't be call opencl primitive proc by CPU: $#" % name)

proc openclonly*(name: string) = primerror(name) # TODO: openclonly
proc openclproc*(name: string) = primerror(name)
proc openclvarargs*(name: string) = primerror(name)
proc openclprefix*(name: string) = primerror(name)
proc openclinfix*(name: string) = primerror(name)

type
  ProcType* = enum
    procBuiltin
    procPrefix
    procInfix
    procNormal

type
  ManglingIndex* = object
    procname*: string
    argtypes*: seq[string]
  ManglingData* = object
    s*: string
    prockind*: ProcType
  Generator* = ref object
    indentwidth*: int
    currentindentnum*: int
    isFormat*: bool
    objects*: Table[string, bool]
    manglingprocs*: Table[ManglingIndex, ManglingData]
    manglingcount*: int
    dependsrcs*: seq[string]
    tmpcount*: int
    currenttmp*: CompSrc
    currentresname*: string
    rescount*: int
  CompSrc* = object
    generator: Generator
    before: string
    src: string
    after: string

proc removePostfix*(n: NimNode): NimNode =
  if n.kind == nnkPostfix:
    n[1]
  else:
    n
    
proc toPrimName*(s: string): string =
  case s
  of "+":
    "add"
  of "-":
    "sub"
  of "*":
    "mul"
  of "/":
    "div"
  of "%":
    "perc"
  of "+=":
    "addset"
  of "-=":
    "subset"
  of "*=":
    "mulset"
  of "/=":
    "divset"
  of "<":
    "less"
  of ">":
    "greater"
  of "<=":
    "lesseq"
  of ">=":
    "greatereq"
  of "==":
    "equal"
  of "!=":
    "notequal"
  of "..":
    "range"
  of "..<":
    "rangeless"
  of "[]":
    "ptrget"
  of "[]=":
    "ptrset"
  else:
    s

proc newManglingIndex*(procname: string, argtypes: seq[string]): ManglingIndex =
  result.procname = procname
  result.argtypes = argtypes
proc initManglingData*(name: string, prockind: ProcType): ManglingData =
  result.s = name
  result.prockind = prockind

proc hash*(manglingindex: ManglingIndex): Hash =
  var arr = @[manglingindex.procname]
  for t in manglingindex.argtypes:
    arr.add(t)
  result = hash(arr)

proc newGenerator*(isFormat = true, indentwidth = 2): Generator =
  new result
  result.indentwidth = indentwidth
  result.currentindentnum = 0
  result.isFormat = isFormat
  result.objects = initTable[string, bool]()
  result.manglingprocs = initTable[ManglingIndex, ManglingData]()
  result.manglingcount = 0
  result.dependsrcs = @[]
  result.tmpcount = 0
  result.currentresname = ""
  result.rescount = 0

proc genTmpSym*(generator: Generator): string =
  result = "_nim2cl_tmp" & $generator.tmpcount
  generator.tmpcount += 1

proc genIndent*(generator: Generator): string =
  repeat(" ", generator.indentwidth*generator.currentindentnum)

template indent*(generator: Generator, body: untyped) =
  generator.currentindentnum += 1
  body
  generator.currentindentnum -= 1

template reset*(generator: Generator, body: untyped) =
  let tmpinum = generator.currentindentnum
  generator.currentindentnum = 0
  body
  generator.currentindentnum = tmpinum
template withRes*(generator: Generator, body: untyped) =
  let prevresname = $generator.currentresname
  let prevrescount = generator.rescount
  generator.currentresname = "res" & $generator.rescount
  generator.rescount += 1
  body
  generator.currentresname = prevresname
  generator.rescount = prevrescount

proc genManglingName*(generator: Generator, manglingindex: ManglingIndex): string =
  if generator.manglingprocs.hasKey(manglingindex):
    result = generator.manglingprocs[manglingindex].s
  else:
    let name = manglingindex.procname.toPrimName
    result = name & "_" & manglingindex.argtypes.join("_") & "_" & $generator.manglingcount
    generator.manglingprocs[manglingindex] = initManglingData(result, procNormal)
    generator.manglingcount += 1

proc newCompSrc*(generator: Generator): CompSrc =
  result.generator = generator
  result.before = ""
  result.src = ""
  result.after = ""

proc `&=`*(comp: var CompSrc, s: string) =
  comp.src &= s
proc addBefore*(comp: var CompSrc, s: string) =
  comp.before &= s
proc addAfter*(comp: var CompSrc, s: string) =
  comp.after &= s

proc `&=`*(comp: var CompSrc, c: CompSrc) =
  comp.before &= c.before
  comp.src &= c.src
  comp.after &= c.after

proc `$`*(comp: CompSrc): string = comp.before & comp.src & comp.after

template getSrc*(procname: typed, generator: Generator, n: NimNode): string =
  var comp = newCompSrc(generator)
  procname(generator, n, comp)
  $comp

#
# generate object from type
#

#
# generate from NimNode
#

proc gen*(generator: Generator, n: NimNode, r: var CompSrc)
proc genStmtListInside*(generator: Generator, n: NimNode, r: var CompSrc)
proc genStmtList*(generator: Generator, n: NimNode, r: var CompSrc)
proc genProcDef*(generator: Generator, n: NimNode, r: var CompSrc, isKernel = false, mangling = false)
proc genType*(generator: Generator, t: NimNode, r: var CompSrc)
proc genTypeFromVal*(generator: Generator, t: NimNode, r: var CompSrc)
proc genCall*(generator: Generator, n: NimNode, r: var CompSrc)
proc genSym*(generator: Generator, n: NimNode, r: var CompSrc)
proc genProcSym*(generator: Generator, n: NimNode): ManglingData

proc isPrimitiveType(name: string): bool =
  case name
  of "float2", "float3", "float4":
    true
  else:
    false

proc genTypeDef*(generator: Generator, n: NimNode, r: var CompSrc) =
  let name = $n[0]

  if name.isPrimitiveType():
    r &= name
    return

  if generator.objects.hasKey(name):
    r &= name
    return

  let objty = n[2]
  if objty.kind != nnkObjectTy:
    error("($#) is unsupported type def: $#" % [$objty.kind, n.repr], n)

  var typesrc = newCompSrc(generator)
  typesrc &= "typedef struct {\n"
  generator.indent:
    for field in objty[2]:
      typesrc &= generator.genIndent()
      genType(generator, field[1], typesrc)
      typesrc &= " "
      typesrc &= $(field[0].removePostfix())
      typesrc &= ";\n"
  typesrc &= "} $#;" % $n[0]

  generator.dependsrcs.add($typesrc)
  generator.objects[name] = true
  r &= name

proc genType*(generator: Generator, t: NimNode, r: var CompSrc) =
  if t.kind == nnkEmpty:
    r &= "void"
  elif t.kind == nnkPtrTy:
    genType(generator, t[0], r)
    r &= "*"
  elif t.kind == nnkBracketExpr:
    case $t[0]
    of "Atomic":
      r &= "__global "
      genType(generator, t[1], r)
      r &= "*"
    of "global":
      r &= "__global "
      genType(generator, t[1], r)
    of "local":
      r &= "__local "
      genType(generator, t[1], r)
    of "private":
      r &= "__private "
      genType(generator, t[1], r)
    of "constant":
      r &= "__constant "
      genType(generator, t[1], r)
    of "var":
      genType(generator, t[1], r)
    else:
      r &= $t[0]
  elif t.kind == nnkSym:
    let typeimpl = t.symbol.getImpl()
    if $t == "float64":
      r &= "double"
    elif $t == "float32":
      r &= "float"
    elif $t == "string":
      r &= "char*"
    elif $t == "bool":
      r &= "int"
    elif typeimpl.kind == nnkTypeDef:
      generator.reset:
        genTypeDef(generator, typeimpl, r)
    else:
      r &= t.repr
  elif t.kind == nnkIdent:
    r &= $t
  else:
    error "($#) $# is unsupported type: $#" % [t.lineinfo, $t.kind, t.repr], t
proc genTypeFromVal*(generator: Generator, t: NimNode, r: var CompSrc) =
  genType(generator, getTypeInst(t), r)

proc genLetElem*(generator: Generator, e: NimNode, r: var CompSrc) =
  let name = $e[0]
  let typ = e[1]
  let val = e[2]

  if typ.kind == nnkEmpty and val.kind == nnkEmpty:
    discard
  elif val.kind == nnkEmpty:
    genType(generator, typ, r)
    r &= " "
    r &= name
  else:
    genTypeFromVal(generator, val, r)
    r &= " "
    r &= name
    r &= " = "
    gen(generator, val, r)

proc genLetSection*(generator: Generator, n: NimNode, r: var CompSrc) =
  genLetElem(generator, n[0], r)
  for i in 1..<n.len:
    var letcomp = newCompSrc(generator)
    genLetElem(generator, n[i], letcomp)
    if $letcomp != "":
      r &= ";\n" & generator.genIndent()
      r &= letcomp

proc genAsgn*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)
  r &= " = "
  gen(generator, n[1], r)

proc genFastAsgn*(generator: Generator, n: NimNode, r: var CompSrc) =
  if n[0].repr == ":tmp":
    genType(generator, getTypeInst(n[1]), r)
    r &= " "
    gen(generator, n[0], r)
    r &= " = "
    gen(generator, n[1], r)
  else:
    gen(generator, n[0], r)
    r &= " = "
    gen(generator, n[1], r)

proc isPrimitiveType*(generator: Generator, n: NimNode): bool =
  let t = getTypeInst(n)
  let primt = case t.kind
              of nnkBracketExpr:
                t[1]
              else:
                t
  case primt.repr
  of "int", "int32", "int64", "float", "float32", "float64":
    return true
  else:
    return false
proc isPrimitiveVec*(generator: Generator, n: NimNode): bool =
  let t = getTypeInst(n)
  let primt = case t.kind
              of nnkBracketExpr:
                t[1]
              else:
                t
  case primt.repr
  of "float2", "float3", "float4":
    return true
  else:
    return false
proc isPrimitiveTypeWithVec*(generator: Generator, n: NimNode): bool =
  isPrimitiveType(generator, n) or isPrimitiveVec(generator, n)
proc isPrimitivePointer*(generator: Generator, n: NimNode): bool =
  let t = getTypeInst(n)
  if t.kind == nnkBracketExpr and $t[0] == "global" and t[1].kind == nnkPtrTy and isPrimitiveTypeWithVec(generator, t[1][0]):
    return true
  else:
    return false
    
proc isPrimitiveCall*(generator: Generator, n: NimNode): bool =
  case $n[0]
  of "+", "-", "*", "/", "+=", "-=", "*=", "/=", "<", ">", "<=", ">=", "==":
    return isPrimitiveType(generator, n[1]) and isPrimitiveType(generator, n[2])
  of "mod":
    if getTypeInst(n[1]).repr == "int" and getTypeInst(n[2]).repr == "int":
      return true
    else:
      return false
  of "and", "or":
    if getTypeInst(n[1]).repr == "bool" and getTypeInst(n[2]).repr == "bool":
      return true
    else:
      return false
  of "inc", "dec":
    return isPrimitiveType(generator, n[1])
  of "[]":
    return isPrimitivePointer(generator, n[1])
  of "[]=":
    return isPrimitivePointer(generator, n[1]) and isPrimitiveType(generator, n[2])
  else:
    return false

proc genInfix*(generator: Generator, n: NimNode, r: var CompSrc) =
  if isPrimitiveCall(generator, n):
    r &= "("
    gen(generator, n[1], r)
    if $n[0] == "mod":
      r &= " % "
    elif $n[0] == "and":
      r &= " && "
    elif $n[0] == "or":
      r &= " || "
    else:
      r &= " $# " % $n[0]
    gen(generator, n[2], r)
    r &= ")"
  else:
    genCall(generator, n, r)

proc genPrefix*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "("
  case $n[0]
  of "not":
    r &= "!"
    gen(generator, n[1], r)
  of "-":
    r &= "-"
    gen(generator, n[1], r)
  else:
    error "$# is unsupported prefix" % [$n[0]], n
  r &= ")"

proc genDotExpr*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)
  r &= "."
  gen(generator, n[1], r)

proc genPrimitiveCall*(generator: Generator, n: NimNode, r: var CompSrc) =
  let name = $n[0]
  if name == "inc":
    gen(generator, n[1], r)
    r &= " += "
    gen(generator, n[2], r)
  elif name == "dec":
    gen(generator, n[1], r)
    r &= " -= "
    gen(generator, n[2], r)
  elif name == "[]":
    gen(generator, n[1], r)
    r &= "["
    gen(generator, n[2], r)
    r &= "]"
  elif name == "[]=":
    gen(generator, n[1], r)
    r &= "["
    gen(generator, n[2], r)
    r &= "] = "
    gen(generator, n[3], r)
  else:
    error "unknown primitive call", n

proc getManglingIndexFromCall*(generator: Generator, n: NimNode): ManglingIndex =
  result.procname = $n[0]
  result.argtypes = @[]
  for i in 1..<n.len:
    var typecomp = newCompSrc(generator)
    genTypeFromVal(generator, n[i], typecomp)
    result.argtypes.add(($typecomp).replace(" ", ""))

proc genCall*(generator: Generator, n: NimNode, r: var CompSrc) =
  if $n[0] == "printfCLProc":
    r &= "printf"
    r &= "("
    gen(generator, n[1], r)
    for i in 0..<n[2].len:
      r &= ", "
      if n[2][i].kind == nnkStrLit:
        r &= $n[2][i]
      else:
        gen(generator, n[2][i], r)
    r &= ")"
    return

  if isPrimitiveCall(generator, n):
    genPrimitiveCall(generator, n, r)
  else:
    let data = genProcSym(generator, n[0])
    case data.prockind
    of procPrefix:
      r &= "("
      r &= data.s
      r &= "("
      gen(generator, n[1], r)
      r &= ")"
      r &= ")"
    of procInfix:
      r &= "("
      gen(generator, n[1], r)
      r &= " "
      r &= data.s
      r &= " "
      gen(generator, n[2], r)
      r &= ")"
    else:
      r &= data.s
      r &= "("
      var args = newSeq[string]()
      for i in 1..<n.len:
        var comp = newCompSrc(generator)
        gen(generator, n[i], comp)
        args.add($comp)
      r &= args.join(", ")
      r &= ")"

proc genWhileStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  var condcomp = newCompSrc(generator)
  gen(generator, n[0], condcomp)
  r &= "while ("
  r &= condcomp
  r &= ") {\n"
  gen(generator, n[1], r)
  r &= generator.genIndent() & "}\n"

proc genIfStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "if ("
  gen(generator, n[0][0], r)
  r &= ") {\n"
  let body = newStmtList(n[0][1])
  gen(generator, body, r)
  r &= generator.genIndent() & "}"
  for i in 1..<n.len:
    if n[i].kind == nnkElifBranch:
      r &= " else if ("
      gen(generator, n[i][0], r)
      r &= ") {\n"
      let body = newStmtList(n[i][1])
      gen(generator, body, r)
      r &= generator.genIndent() & "}"
    else:
      r &= " else {\n"
      let body = newStmtList(n[i][0])
      gen(generator, body, r)
      r &= generator.genIndent() & "}"

proc removeLastExpr*(n: NimNode): NimNode =
  result = newStmtList()
  for i in 0..<n.len-1:
    result.add(n[i])
proc genLastExpr*(generator: Generator, n: NimNode, r: var CompSrc, rettmpname: string) =
  generator.indent:
    r &= generator.genIndent()
    r &= rettmpname & " = "
    gen(generator, n, r)
    r &= ";\n"
proc genTmpVar*(generator: Generator, n: NimNode, r: var CompSrc, rettmpname: string) =
  var typecomp = newCompSrc(generator)
  genTypeFromVal(generator, n, typecomp)
  r.addBefore(generator.genIndent() & $typecomp & " " & rettmpname & ";\n")
proc genExpr*(generator: Generator, n: NimNode, r: var CompSrc, rettmpname: string) =
  if n.kind == nnkStmtList or n.kind == nnkStmtListExpr:
    gen(generator, n.removeLastExpr, r)
    genLastExpr(generator, n[^1], r, rettmpname)
  else:
    genLastExpr(generator, n, r, rettmpname)

proc genIfExprInside*(generator: Generator, n: NimNode, r: var CompSrc): string =
  let rettmpname = genTmpSym(generator)
  genTmpVar(generator, n[0][1], r, rettmpname)
  r &= generator.genIndent() & "if ("
  gen(generator, n[0][0], r)
  r &= ") {\n"
  genExpr(generator, n[0][1], r, rettmpname)
  r &= generator.genIndent() & "}"
  for i in 1..<n.len:
    if n[i].kind == nnkElifBranch:
      r &= " else if ("
      gen(generator, n[i][0], r)
      r &= ") {\n"
      genExpr(generator, n[i][1], r, rettmpname)
      r &= generator.genIndent() & "}"
    else:
      r &= " else {\n"
      genExpr(generator, n[i][0], r, rettmpname)
      r &= generator.genIndent() & "}\n"
  return rettmpname

proc genIfExpr*(generator: Generator, n: NimNode, r: var CompSrc) =
  var ifcomp = newCompSrc(generator)
  r &= genIfExprInside(generator, n, ifcomp)
  r.addBefore($ifcomp)

proc genBlockStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "{\n"
  generator.indent:
    if n[1].kind == nnkStmtList and n[1][0].kind == nnkVarSection and n[1][0].len == 2:
      r &= generator.genIndent() & "int " & $n[1][0][0][0] & ";\n"

    if n[1].kind == nnkStmtList:
      genStmtListInside(generator, n[1], r)
    else:
      r &= generator.genIndent()
      gen(generator, n[1], r)
  r &= generator.genIndent() & "}"

proc genBreakStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "break"

proc genStmtListBody*(generator: Generator, n: NimNode, r: var CompSrc) =
  for e in n.children:
    if e.kind == nnkStmtList:
      genStmtListInside(generator, e, r)
    else:
      var comp = newCompSrc(generator)
      gen(generator, e, comp)
      r &= comp.before
      if comp.src != "":
        r &= generator.genIndent()
        r &= comp.src
        r &= ";"
        r &= "\n"
      r &= comp.after

proc genStmtListInside*(generator: Generator, n: NimNode, r: var CompSrc) =
  if n.len >= 2 and n[0].kind == nnkVarSection and n[1].kind == nnkBlockStmt and n[1].len >= 2 and n[1][1].kind == nnkWhileStmt:
    generator.withRes:
      genStmtListBody(generator, n, r)
  else:
    genStmtListBody(generator, n, r)

proc genStmtList*(generator: Generator, n: NimNode, r: var CompSrc) =
  generator.indent:
    genStmtListInside(generator, n, r)

proc genStmtListExprInside*(generator: Generator, n: NimNode, r: var CompSrc): string =
  let rettmpname = genTmpSym(generator)
  genTmpVar(generator, n, r, rettmpname)
  genExpr(generator, n, r, rettmpname)
  return rettmpname
proc genStmtListExpr*(generator: Generator, n: NimNode, r: var CompSrc) =
  var stmtcomp = newCompSrc(generator)
  r &= genStmtListExprInside(generator, n, stmtcomp)
  r.addBefore($stmtcomp)

proc genReturnStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)

proc genIntLit*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= $n.intVal

proc genFloatLit*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= $n.floatVal

proc genStrLit*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "\"" & ($n.strVal).replace("\n", "\\n") & "\""

proc genBracket*(generator: Generator, n: NimNode, r: var CompSrc) =
  var args = newSeq[string]()
  for e in n.children:
    var comp = newCompSrc(generator)
    gen(generator, e, comp)
    args.add($comp)
  r &= args.join(", ")

proc getManglingIndex*(n: NimNode): ManglingIndex =
  result.procname = $n[0]
  result.argtypes = @[]
  let argtypes = n[3]
  for i in 1..<argtypes.len:
    if argtypes[i].len == 3:
      result.argtypes.add(argtypes[i][1].repr.replace(" ", "").replace("[").replace("]"))
    else:
      for j in 0..<argtypes.len-2:
        result.argtypes.add(argtypes[i][^2].repr.replace(" ", "").replace("[").replace("]"))

proc genProcSym*(generator: Generator, n: NimNode): ManglingData =
  n.expectKind(nnkSym)
  let impl = n.symbol.getImpl()
  impl.expectKind(nnkProcDef)

  let manglingindex = getManglingIndex(impl)
  if generator.manglingprocs.hasKey(manglingindex):
    result = generator.manglingprocs[manglingindex]
  else:
    generator.reset:
      var proccomp = newCompSrc(generator)
      genProcDef(generator, impl, proccomp, mangling = true)
      if $proccomp != "":
        generator.dependsrcs.add($proccomp)
      result = generator.manglingprocs[manglingindex]

proc genSym*(generator: Generator, n: NimNode, r: var CompSrc) =
  if $n == ":tmp":
    r &= "tmp"
  else:
    r &= $n

proc genConv*(generator: Generator, n: NimNode, r: var CompSrc) =
  if n[0].repr != "T":
    r &= "(("
    genType(generator, n[0], r)
    r &= ")"
  gen(generator, n[1], r)
  if n[0].repr != "T":
    r &= ")"

proc genHiddenStdConv*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[1], r)

proc genHiddenDeref*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)

proc genHiddenCallConv*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[1], r)

proc genDiscardStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  if n.len == 1:
    gen(generator, n[0], r)

proc genCast*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "(("
  genType(generator, n[0], r)
  r &= ")"
  gen(generator, n[1], r)
  r &= ")"

proc genAddr*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "(&"
  genType(generator, n[0], r)
  r &= ")"

proc gen*(generator: Generator, n: NimNode, r: var CompSrc) =
  case n.kind
  of nnkLetSection, nnkVarSection: genLetSection(generator, n, r)
  of nnkAsgn: genAsgn(generator, n, r)
  of nnkFastAsgn: genFastAsgn(generator, n, r)
  of nnkInfix: genInfix(generator, n, r)
  of nnkPrefix: genPrefix(generator, n, r)
  of nnkDotExpr: genDotExpr(generator, n, r)
  of nnkCall, nnkCommand: genCall(generator, n, r)
  of nnkWhileStmt: genWhileStmt(generator, n, r)
  of nnkIfStmt: genIfStmt(generator, n, r)
  of nnkIfExpr: genIfExpr(generator, n, r)
  of nnkBlockStmt: genBlockStmt(generator, n, r)
  of nnkBreakStmt: genBreakStmt(generator, n, r)
  of nnkStmtList: genStmtList(generator, n, r)
  of nnkStmtListExpr: genStmtListExpr(generator, n, r)
  of nnkReturnStmt: genReturnStmt(generator, n, r)
  of nnkIntLit: genIntLit(generator, n, r)
  of nnkFloatLit, nnkFloat32Lit, nnkFloat64Lit: genFloatLit(generator, n, r)
  of nnkStrLit: genStrLit(generator, n, r)
  of nnkBracket: genBracket(generator, n, r)
  of nnkSym: genSym(generator, n, r)
  of nnkConv: genConv(generator, n, r)
  of nnkHiddenStdConv: genHiddenStdConv(generator, n, r)
  of nnkHiddenDeref, nnkHiddenAddr: genHiddenDeref(generator, n, r)
  of nnkHiddenCallConv: genHiddenCallConv(generator, n, r)
  of nnkDiscardStmt: genDiscardStmt(generator, n, r)
  of nnkCast: genCast(generator, n, r)
  of nnkAddr: genAddr(generator, n, r)
  of nnkCommentStmt, nnkEmpty: discard
  else:
    error("($#) $# is unsupported NimNode: $#" % [n.lineinfo, $n.kind, n.repr], n)

#
# ProcDef
#

proc genRetType*(generator: Generator, n: NimNode, r: var CompSrc) =
  genType(generator, n[0], r)

proc genArgTypes*(generator: Generator, n: NimNode, r: var CompSrc) =
  var argsrcs = newSeq[string]()
  for i in 1..<n.len:
    if n[i].len == 3:
      argsrcs.add("$# $#" % [getSrc(genType, generator, n[i][1]), $n[i][0]])
    else:
      let typ = n[i][^2]
      for j in 0..<n[i].len-2:
        let name = n[i][j]
        argsrcs.add("$# $#" % [getSrc(genType, generator, typ), $name])
  r &= argsrcs.join(", ")

proc genResultStart*(generator: Generator, n: NimNode, r: var CompSrc) =
  let t = getSrc(genType, generator, n)
  if t != "void":
    generator.indent:
      r &= generator.genIndent()
      r &= "$# result;" % t
      r &= "\n"
proc genResultEnd*(generator: Generator, n: NimNode, r: var CompSrc) =
  let t = getSrc(genType, generator, n)
  if t != "void":
    generator.indent:
      r &= generator.genIndent() & "return result;\n"

proc genBuiltinProc*(generator: Generator, n: NimNode, r: var CompSrc) =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  let builtinname = if first.len == 1: $n[0] else: first[1].strval
  var manglingindex = getManglingIndex(n)
  generator.manglingprocs[manglingindex] = initManglingData(builtinname, procBuiltin)

proc genBuiltinPrefix*(generator: Generator, n: NimNode, r: var CompSrc) =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  let builtinname = if first.len == 1: $n[0] else: first[1].strval
  var manglingindex = getManglingIndex(n)
  generator.manglingprocs[manglingindex] = initManglingData(builtinname, procPrefix)

proc genBuiltinInfix*(generator: Generator, n: NimNode, r: var CompSrc) =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  let builtinname = if first.len == 1: $n[0] else: first[1].strval
  var manglingindex = getManglingIndex(n)
  generator.manglingprocs[manglingindex] = initManglingData(builtinname, procInfix)

proc getProcType*(n: NimNode): ProcType =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  if first.kind in nnkCallKinds and $first[0] == "openclproc":
    return procBuiltin
  elif first.kind in nnkCallKinds and $first[0] == "openclprefix":
    return procPrefix
  elif first.kind in nnkCallKinds and $first[0] == "openclinfix":
    return procInfix
  else:
    return procNormal

proc genProcDef*(generator: Generator, n: NimNode, r: var CompSrc, isKernel = false, mangling = false) =
  case getProcType(n)
  of procBuiltin:
    genBuiltinProc(generator, n, r)
    return
  of procPrefix:
    genBuiltinPrefix(generator, n, r)
    return
  of procInfix:
    genBuiltinInfix(generator, n, r)
    return
  of procNormal:
    discard

  if isKernel:
    r &= "__kernel "
  genRetType(generator, n[3], r)
  r &= " "
  if mangling:
    let manglingindex = getManglingIndex(n)
    r &= genManglingName(generator, manglingindex)
  else:
    r &= $n[0]
  r &= "("
  genArgTypes(generator, n[3], r)
  r &= ") {\n"
  genResultStart(generator, n[3][0], r)
  if n.body.kind == nnkStmtList:
    genStmtList(generator, n.body, r)
  else:
    let newbody = newStmtList(n.body)
    genStmtList(generator, newbody, r)
  genResultEnd(generator, n[3][0], r)
  r &= "}"

#
# macros
#

macro genCLKernelSourceMacro*(procname: typed): untyped =
  let generator = newGenerator()
  var comp = newCompSrc(generator)
  genProcDef(generator, procname.symbol.getImpl(), comp, isKernel = true)
  var srcs = generator.dependsrcs
  srcs.add($comp)
  result = newStrLitNode(srcs.join("\n"))
template genCLKernelSource*(procname: untyped): untyped =
  genCLKernelSourceMacro(procname)

macro defineProgram*(name: untyped, body: untyped): untyped =
  name.expectKind(nnkIdent)
  for kernel in body:
    kernel.expectKind(nnkIdent)
  
  var genmacro = parseExpr("macro gen$#*(): untyped = discard" % $name)
  genmacro[6] = newStmtList()
  genmacro[6].add(parseExpr("var tmpsrcs: seq[string] = @[]"))
  genmacro[6].add(parseExpr("var generator = newGenerator()"))
  for kernel in body:
    var kernelstmt = newStmtList()
    kernelstmt.add(parseExpr("var $1 = bindSym(\"$1\")" % $kernel))
    kernelstmt.add(parseExpr("var comp = newCompSrc(generator)"))
    kernelstmt.add(parseExpr("genProcDef(generator, $#.symbol.getImpl(), comp, isKernel = true)" % $kernel))
    kernelstmt.add(parseExpr("tmpsrcs.add($comp)"))
    genmacro[6].add(newBlockStmt(kernelstmt))
  genmacro[6].add(parseExpr("return newStrLitNode(concat(generator.dependsrcs, tmpsrcs).join(\"\\n\"))"))

  return genmacro

template genProgram*(programname: untyped): string =
  `gen programname`()
