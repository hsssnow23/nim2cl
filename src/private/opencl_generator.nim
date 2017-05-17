
import macros
import strutils, sequtils
import tables, hashes

export macros
export strutils
export sequtils

proc openclproc*(name: string = nil) = discard
proc openclinfix*() = discard

type
  ManglingIndex* = object
    procname*: string
    argtypes*: seq[string]
    isbuiltin*: bool
  Generator* = ref object
    indentwidth*: int
    currentindentnum*: int
    isFormat*: bool
    objects*: Table[string, bool]
    manglingprocs*: Table[ManglingIndex, string]
    manglingcount*: int
    dependsrcs*: seq[string]
  CompSrc* = object
    generator: Generator
    src: string

type
  ProcType* = enum
    procNormal
    procInfix
    procBuiltin

proc newManglingIndex*(procname: string, argtypes: seq[string]): ManglingIndex =
  result.procname = procname
  result.argtypes = argtypes

proc hash*(manglingindex: ManglingIndex): Hash =
  var arr = @[manglingindex.procname]
  for t in manglingindex.argtypes:
    arr.add(t)
  result = hash(arr)

let primitiveprocs* = [
  (name: "abs", args: @["float"], raw: "fabs"),
  (name: "abs", args: @["int"], raw: "abs"),
]

proc newGenerator*(isFormat = true, indentwidth = 2): Generator =
  new result
  result.indentwidth = indentwidth
  result.currentindentnum = 0
  result.isFormat = isFormat
  result.objects = initTable[string, bool]()
  result.manglingprocs = initTable[ManglingIndex, string]()
  result.manglingcount = 0
  result.dependsrcs = @[]

  for primitive in primitiveprocs:
    result.manglingprocs[newManglingIndex(primitive.name, primitive.args)] = primitive.raw

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

proc format*(generator: Generator, s: string): string =
  result = s
  if generator.isFormat:
    result = result.replace("$i", genIndent(generator))
    result = result.replace("$n", "\n")
  else:
    result = result.replace("$i", "")
    result = result.replace("$n", "")

proc genManglingName*(generator: Generator, manglingindex: ManglingIndex): string =
  if generator.manglingprocs.hasKey(manglingindex):
    result = generator.manglingprocs[manglingindex]
  else:
    let name = case manglingindex.procname
      of "+", "-", "*", "/", "%", "<", ">", "<=", ">=", "==":
        "infix"
      else:
        manglingindex.procname
    result = name & "_" & manglingindex.argtypes.join("_") & "_" & $generator.manglingcount
    generator.manglingprocs[manglingindex] = result
    generator.manglingcount += 1

proc newCompSrc*(generator: Generator): CompSrc =
  result.generator = generator
  result.src = ""

proc `&=`*(comp: var CompSrc, s: string) =
  comp.src &= comp.generator.format(s)

proc `$`*(comp: CompSrc): string = comp.src

proc semicolon*(comp: var CompSrc) =
  let last = comp.src[^1]
  if comp.src.len > 0 and last != ';' and last != '}' and last != '{':
    comp &= ";"

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

proc genTypeDef*(generator: Generator, n: NimNode, r: var CompSrc) =
  let name = $n[0]
  if generator.objects.hasKey(name):
    r &= $n[0]
    return

  let objty = n[2]
  if objty.kind != nnkObjectTy:
    error("($#) is unsupported type def" % $objty.kind, n)

  var typesrc = newCompSrc(generator)
  typesrc &= "typedef struct {$n"
  generator.indent:
    for field in objty[2]:
      typesrc &= "$i"
      genType(generator, field[1], typesrc)
      typesrc &= " "
      typesrc &= $field[0]
      typesrc &= ";$n"
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
    else:
      r &= t.repr
  elif t.kind == nnkSym:
    let typeimpl = t.symbol.getImpl()
    if typeimpl.kind == nnkTypeDef:
      generator.reset:
        genTypeDef(generator, typeimpl, r)
    else:
      r &= t.repr
  else:
    r &= t.repr
proc genTypeFromVal*(generator: Generator, t: NimNode, r: var CompSrc) =
  genType(generator, getTypeInst(t), r)

proc genLetSection*(generator: Generator, n: NimNode, r: var CompSrc) =
  var letsrcs = newSeq[string]()
  for e in n.children:
    let name = e[0]
    let typ = e[1]
    let val = e[2]
    if typ.kind == nnkEmpty and val.kind == nnkEmpty:
      discard
    elif val.kind == nnkEmpty:
      letsrcs.add("$# $#" % [getSrc(genType, generator, typ), $name])
    else:
      letsrcs.add("$# $# = $#" % [getSrc(genTypeFromVal, generator, val), $name, getSrc(gen, generator, val)])
  r &= letsrcs.join(";$n$i")

proc genAsgn*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)
  r &= " = "
  gen(generator, n[1], r)

proc isPrimitiveInfix*(generator: Generator, n: NimNode, r: var CompSrc): bool =
  let
    name = $n[0]
    lefttype = getSrc(genTypeFromVal, generator, n[1])
    righttype = getSrc(genTypeFromVal, generator, n[2])
  case name
  of "+", "-", "*", "/", "%", "<", ">", "<=", ">=", "==":
    if lefttype == "float" and righttype == "float":
      return true
    elif lefttype == "float" and righttype == "float64":
      return true
    elif lefttype == "float64" and righttype == "float":
      return true
    elif lefttype == "float64" and righttype == "float64":
      return true
    elif lefttype == "int" and righttype == "int":
      return true
    else:
      return false
  else:
    return false

proc genInfix*(generator: Generator, n: NimNode, r: var CompSrc) =
  if isPrimitiveInfix(generator, n, r):
    r &= "("
    gen(generator, n[1], r)
    r &= " $# " % $n[0]
    gen(generator, n[2], r)
    r &= ")"
  else:
    gen(generator, n[0], r)
    r &= "("
    gen(generator, n[1], r)
    r &= ", "
    gen(generator, n[2], r)
    r &= ")"

proc genDotExpr*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)
  r &= "."
  gen(generator, n[1], r)

proc isPrimitiveCall*(n: NimNode): bool =
  let name = $n[0]
  if name == "inc" or name == "dec":
    return true
  else:
    return false

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
  else:
    error "unknown primitive call", n

proc genCall*(generator: Generator, n: NimNode, r: var CompSrc) =
  if isPrimitiveCall(n):
    genPrimitiveCall(generator, n, r)
  else:
    gen(generator, n[0], r)
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
  r &= $condcomp
  r &= ") {$n"
  gen(generator, n[1], r)
  r &= "$i}$n"

proc genBlockStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= "{$n"
  generator.indent:
    if n[1].kind == nnkStmtList:
      genStmtListInside(generator, n[1], r)
    else:
      r &= "$i"
      gen(generator, n[1], r)
  r &= "$i}"

proc genStmtListInside*(generator: Generator, n: NimNode, r: var CompSrc) =
  for e in n.children:
    if e.kind == nnkStmtList:
      genStmtListInside(generator, e, r)
    else:
      var comp = newCompSrc(generator)
      gen(generator, e, comp)
      if $comp != "":
        r &= "$i"
        r &= $comp
        r.semicolon()
        r &= "$n"

proc genStmtList*(generator: Generator, n: NimNode, r: var CompSrc) =
  generator.indent:
    genStmtListInside(generator, n, r)

proc genReturnStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[0], r)

proc genIntLit*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= $n.intVal

proc genFloatLit*(generator: Generator, n: NimNode, r: var CompSrc) =
  r &= $n.floatVal

proc getManglingIndex*(n: NimNode): ManglingIndex =
  result.procname = $n[0]
  result.argtypes = @[]
  let argtypes = n[3]
  for i in 1..<argtypes.len:
    if argtypes[i].len == 3:
      result.argtypes.add($argtypes[i][1])
    else:
      for j in 0..<argtypes.len-2:
        result.argtypes.add($argtypes[i][^2])

proc genSym*(generator: Generator, n: NimNode, r: var CompSrc) =
  let impl = n.symbol.getImpl()
  if impl.kind == nnkProcDef:
    let manglingindex = getManglingIndex(impl)
    if generator.manglingprocs.hasKey(manglingindex):
      r &= generator.manglingprocs[manglingindex]
    else:
      generator.reset:
        var proccomp = newCompSrc(generator)
        genProcDef(generator, impl, proccomp, mangling = true)
        if $proccomp != "":
          generator.dependsrcs.add($proccomp)
        r &= genManglingName(generator, manglingindex)
  else:
    r &= $n

proc genConv*(generator: Generator, n: NimNode, r: var CompSrc) =
  gen(generator, n[1], r)

proc genDiscardStmt*(generator: Generator, n: NimNode, r: var CompSrc) =
  if n.len == 1:
    gen(generator, n[0], r)

proc gen*(generator: Generator, n: NimNode, r: var CompSrc) =
  case n.kind
  of nnkLetSection, nnkVarSection: genLetSection(generator, n, r)
  of nnkAsgn, nnkFastAsgn: genAsgn(generator, n, r)
  of nnkInfix: genInfix(generator, n, r)
  of nnkDotExpr: genDotExpr(generator, n, r)
  of nnkCall, nnkCommand: genCall(generator, n, r)
  of nnkWhileStmt: genWhileStmt(generator, n, r)
  of nnkBlockStmt: genBlockStmt(generator, n, r)
  of nnkStmtList: genStmtList(generator, n, r)
  of nnkReturnStmt: genReturnStmt(generator, n, r)
  of nnkIntLit: genIntLit(generator, n, r)
  of nnkFloatLit, nnkFloat64Lit: genFloatLit(generator, n, r)
  of nnkSym: genSym(generator, n, r)
  of nnkConv, nnkHiddenStdConv: genConv(generator, n, r)
  of nnkDiscardStmt: genDiscardStmt(generator, n, r)
  of nnkCommentStmt, nnkEmpty: discard
  else:
    error("($#) is unsupported NimNode" % $n.kind, n)

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
      r &= "$i"
      r &= "$# result;" % t
      r &= "$n"
proc genResultEnd*(generator: Generator, n: NimNode, r: var CompSrc) =
  let t = getSrc(genType, generator, n)
  if t != "void":
    generator.indent:
      r &= "$ireturn result;$n"

proc genBuiltinProc*(generator: Generator, n: NimNode, r: var CompSrc) =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  let builtinname = if first.len == 1: $n[0] else: first[1].strval
  var manglingindex = getManglingIndex(n)
  generator.manglingprocs[manglingindex] = builtinname

proc genBuiltinInfix*(generator: Generator, n: NimNode, r: var CompSrc) =
  var manglingindex = getManglingIndex(n)
  generator.manglingprocs[manglingindex] = $n[0]

proc getProcType*(n: NimNode): ProcType =
  let first = if n.body.kind == nnkStmtList: n.body[0] else: n.body
  if first.kind == nnkCall and $first[0] == "openclproc":
    return procBuiltin
  elif first.kind == nnkCall and $first[0] == "openclinfix":
    return procInfix
  else:
    return procNormal

proc genProcDef*(generator: Generator, n: NimNode, r: var CompSrc, isKernel = false, mangling = false) =
  case getProcType(n)
  of procBuiltin:
    genBuiltinProc(generator, n, r)
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
  r &= ") {$n"
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

macro genCLKernelSource*(procname: typed): untyped =
  # echo procname.symbol.getImpl().treerepr
  let generator = newGenerator()
  var comp = newCompSrc(generator)
  genProcDef(generator, procname.symbol.getImpl(), comp, isKernel = true)
  var srcs = generator.dependsrcs
  srcs.add($comp)
  result = newStrLitNode(srcs.join("\n"))

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

  echo genmacro.repr

  return genmacro

template genProgram*(programname: untyped): string =
  `gen programname`()
