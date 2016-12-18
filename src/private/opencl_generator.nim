
import macros
import strutils, sequtils
import tables
import future

export macros
export strutils, sequtils

type
  Generator* = ref object
    indentNum*: int
    indentSize*: int
    isFormat*: bool

    toplevels*: seq[string] # store struct and external function

    objects*: Table[string, bool] # for object
    procs*: Table[string, seq[OverloadProc]] # for object
    variables*: Table[string, string] # for template variable

    isReturn*: bool
    prevStmts*: seq[string] # for nnkObjConstr and etc...

    count*: int # for gensym
    tmpinfo*: tuple[s: string, e: string] # for while and `for` stmts
    iinfo*: string # for while and `for` stmts
    isInTmpStmt*: bool # for while and `for` stmts

  OverloadProc* = object
    types*: seq[string]
    manglingname*: string
  TypeInfo* = ref object
    name*: string
    arraynum*: seq[int]
  
type
  GPGPULanuageError* = object of Exception

const builtinTypeNames* = @[
  "float",
  "float2",
  "float3",
  "float4",
  "int",
  "char",
  "ptr float",
  "ptr float2",
  "ptr float3",
  "ptr float4",
  "ptr int",
  "bool",
  "void",
]

const builtinFunctions* = [
  (name: "getGlobalID", args: @["int"], raw: "get_global_id"),
  (name: "getLocalID", args: @["int"], raw: "get_local_id"),
  (name: "dot", args: @["float3", "float3"], raw: "dot"),
  (name: "normalize", args: @["float3"], raw: "normalize"),
  (name: "abs", args: @["int"], raw: "abs"),
  (name: "abs", args: @["float"], raw:"fabs"),
  (name: "sqrt", args: @["float"], raw: "sqrt"),
]

#
# Generator
#

proc newGenerator*(indentSize = 2, isFormat = true): Generator =
  result = Generator()
  result.indentNum = 0
  result.indentSize = indentSize
  result.isFormat = isFormat

  result.toplevels = @[]

  result.procs = initTable[string, seq[OverloadProc]]()
  result.objects = initTable[string, bool]()
  result.variables = initTable[string, string]()

  result.isReturn = false
  result.prevStmts = @[]
  result.count = 0
  result.tmpinfo = (s: nil, e: nil)
  result.iinfo = nil
  result.isIntmpStmt = false

proc indent*(generator: Generator): string =
  if generator.isFormat:
    return repeat(" ", generator.indentSize).repeat(generator.indentNum)
  else:
    return ""
proc newline*(generator: Generator): string =
  if generator.isFormat:
    return "\n"
  else:
    return ""
proc inc*(generator: Generator) =
  generator.indentNum += 1
proc dec*(generator: Generator) =
  generator.indentNum -= 1
proc genSym*(generator: Generator, name: string): string =
  if name.isAlphaNumeric():
    result = name & "_gensym_" & $generator.count
  else:
    result = "operator_gensym_" & $generator.count
  generator.count += 1
proc expand*(generator: Generator): string =
  if generator.prevStmts.len >= 1:
    result = generator.prevStmts[^1]
    generator.prevStmts = generator.prevStmts[0..^2]
  else:
    result = ""
template newProc*(generator: Generator, body: untyped) =
  var tmpIndentNum = generator.indentNum
  var tmpReturn = generator.isReturn
  var tmpPrevStmts = generator.prevStmts
  var tmpTmpInfo = generator.tmpinfo
  var tmpiinfo = generator.iinfo
  generator.indentNum = 0
  generator.isReturn = false
  generator.prevStmts = @[]
  generator.tmpinfo = (s: nil, e: nil)
  generator.iinfo = nil
  body
  generator.indentNum = tmpIndentNum
  generator.isReturn = tmpReturn
  generator.prevStmts = tmpPrevStmts
  generator.tmpinfo = tmpTmpInfo
  generator.iinfo = tmpiinfo
template newIndent*(generator: Generator, body: untyped) =
  var tmpIndentNum = generator.indentNum
  generator.indentNum = 0
  body
  generator.indentNum = tmpIndentNum

#
# TypeInfo
#

proc newTypeInfoArray*(s: string, n: seq[int]): TypeInfo =
  return TypeInfo(name: s, arraynum: n)
converter toTypeInfo*(s: string): TypeInfo =
  return TypeInfo(name: s, arraynum: @[])
proc isArray*(tf: TypeInfo): bool =
  return tf.arraynum.len != 0
proc genTypeDecl*(tf: TypeInfo, name: string): string =
  if tf.isArray():
    result = "$# $#" % [tf.name, name]
    for n in tf.arraynum:
      result &= "[$#]" % $n
  else:
    return "$# $#" % [tf.name, name]

#
# Generate from NimNode
#

proc gen*(generator: Generator, node: NimNode): string
proc getTypeNameInside*(generator: Generator, node: NimNode): TypeInfo
proc getTypeName*(generator: Generator, node: NimNode): TypeInfo

proc genObjectTy*(generator: Generator, node: NimNode, name: string): TypeInfo =
  let objty = getType(node)
  if not generator.objects.hasKey(name):
    if objty.kind == nnkObjectTy:
      generator.newIndent:
        var res = ""
        res &= "typedef struct {" & generator.newline()
        generator.inc()
        for field in objty[2].children:
          res &= generator.indent() & getTypeName(generator, field).genTypeDecl($field) & ";" & generator.newline()
        generator.dec()
        res &= "} $#;" % name
        generator.toplevels.add(res)
        generator.objects[name] = true
      return name
    else:
      return getTypeNameInside(generator, objty)
  else:
    return name

proc getTypeNameInside*(generator: Generator, node: NimNode): TypeInfo =
  let t = node
  if t.kind == nnkSym:
    let s = $node
    for builtin in builtinTypeNames:
      if s == builtin:
        return s
      elif s == "float32":
        return "float"
      elif s == "float64":
        return "double"
      elif s == "byte":
        return "uchar"
    return genObjectTy(generator, node, s)
  elif t.kind == nnkBracketExpr:
    if t[0].repr == t[1].repr:
      return "__global " & getTypeNameInside(generator, t[1]).name

    case $t[0]
    of "array":
      var arraynum: seq[int] = @[]
      var tmpArrNode = t
      while tmpArrNode.kind == nnkBracketExpr:
        let startn = tmpArrNode[1][1].intval
        let endn = tmpArrNode[1][2].intval
        let num = endn + 1 - startn
        arraynum.add(num.int)
        tmpArrNode = tmpArrNode[2]
      return newTypeInfoArray(getTypeNameInside(generator, tmpArrNode).name, arraynum)
    of "ptr":
      return "$#*" % getTypeNameInside(generator, t[1]).name
    of "ref":
      return "$#*" % getTypeNameInside(generator, t[1]).name
    of "Global":
      return "__global " & getTypeNameInside(generator, t[1]).name
    of "Local":
      return "__local " & getTypeNameInside(generator, t[1]).name
    of "Private":
      return "__private " & getTypeNameInside(generator, t[1]).name    
    of "Constant":
      return "__constant " & getTypeNameInside(generator, t[1]).name
    of "typeDesc":
      return getTypeNameInside(generator, t[1])
    of "var":
      return getTypeNameInside(generator, t[1])
    else:
      raise newException(GPGPULanuageError, "unsupported bracket type: " & t.repr)
  elif t.kind == nnkPtrTy:
    return "$#*" % getTypeNameInside(generator, t[0]).name
  else:
    raise newException(GPGPULanuageError, "unsupported type: " & t.repr)

proc getTypeName*(generator: Generator, node: NimNode): TypeInfo =
  return getTypeNameInside(generator, getTypeInst(node))

proc genStmtListInside*(generator: Generator, body: NimNode): string =
  result = ""
  if body.kind == nnkStmtList:
    for b in body:
      var s = ""
      if b.kind == nnkStmtList:
        s &= genStmtListInside(generator, b) & generator.newline()
      elif b.kind == nnkDiscardStmt:
        discard
      elif b.kind == nnkCommentStmt:
        discard
      else:
        s &= generator.indent() & gen(generator, b) & ";" & generator.newline()
      result &= generator.expand() & s 
  elif body.kind == nnkEmpty:
    discard
  else:
    if body.kind == nnkDiscardStmt:
      discard
    else:
      let s = generator.indent() & gen(generator, body) & ";" & generator.newline()
      result = generator.expand() & s

proc genStmtList*(generator: Generator, body: NimNode): string =
  generator.inc()
  result = genStmtListInside(generator, body)
  generator.dec()

proc genPrevStmtList*(generator: Generator, node: NimNode): string =
  var body = newStmtList()
  for i in 0..<node.len-1:
    body.add(node[i])
  generator.prevStmts.add(genStmtListInside(generator, body))
  return gen(generator, node[^1])

proc genIdent*(generator: Generator, node: NimNode): string =
  return $node

proc genTmpSym*(generator: Generator, node: NimNode): string =
  if ($node).find(":tmp") != -1 or $node == "res":
    if generator.tmpinfo.s != nil:
      result = generator.tmpinfo.s
      # generator.tmpinfo.s = nil
    elif generator.tmpinfo.e != nil:
      result = generator.tmpinfo.e
      # generator.tmpinfo.e = nil
    else:
      raise newException(GPGPULanuageError, "tmp error")
  elif $node == "i":
    if generator.iinfo != nil:
      result = generator.iinfo
      # generator.iinfo = nil
    else:
      result = "i"
  else:
    result = $node

proc genSymbol*(generator: Generator, node: NimNode): string =
  if generator.isInTmpStmt:
    result = genTmpSym(generator, node)
  else:
    if generator.variables.hasKey($node):
      return generator.variables[$node]
    else:
      result = $node

proc equals*(left: seq[string], right: seq[string]): bool =
  if left.len != right.len:
    return false
  for i in 0..<left.len:
    if left[i] != right[i]:
      return false
  return true

proc genManglingCall*(generator: Generator, procname: string, argtypes: seq[string], argstrs: seq[string]): string =
  if generator.procs.hasKey(procname):
    for overloaded in generator.procs[procname]:
      if equals(argtypes, overloaded.types): 
        return overloaded.manglingname & "(" & argstrs.join(", ") & ")"
  return nil

proc genExternalProcCall*(generator: Generator, node: NimNode): string =
  let procname = $node[0]
  var argtypes: seq[string] = @[]
  var argstrs: seq[string] = @[]
  for i in 1..<node.len:
    argtypes.add(getTypeName(generator, node[i]).genTypeDecl("mangling"))
    argstrs.add(gen(generator, node[i]))
  var res = genManglingCall(generator, procname, argtypes, argstrs)
  if res != nil:
    return res
  else:
    generator.newProc:
      generator.toplevels.add(gen(generator, node[0].symbol.getImpl()))
    result = genManglingCall(generator, procname, argtypes, argstrs)
    if result == nil:
      raise newException(GPGPULanuageError, "cannot call mangling proc: " & node.repr)

proc toCLFunctionName*(name: string): string =
  var s = ""
  var isPrevLower = false
  for c in name:
    if isPrevLower and c.isUpperAscii:
      s &= "_" & $c.toLowerAscii
      isPrevLower = false
    else:
      s &= $c.toLowerAscii
      isPrevLower = true
  return s

proc genEcho*(generator: Generator, node: NimNode): string =
  result = ""
  result &= "printf(\""
  var args = ""
  for i in 0..<node[1].len:
    let curnode = node[1][i]
    case curnode.kind
    of nnkStrLit:
      result &= curnode.strval
    of nnkHiddenCallConv:
      let typ = getTypeName(generator, curnode[1])
      case typ.name
      of "float":
        result &= "%f"
      of "double":
        result &= "%f"
      of "int":
        result &= "%i"
      else:
        raise newException(GPGPULanuageError, "unsupported echo type ($#)" % typ.name)
      args &= ", " & gen(generator, curnode[1])
    else:
      raise newException(GPGPULanuageError, "unsupported echo type: $# ($#)" % [curnode.repr, $curnode.kind])
  result &= "\""
  result &= args
  result &= ")"

proc genCall*(generator: Generator, node: NimNode): string =
  case $node[0]
  of "[]=":
    result = "$#[$#] = $#" % [gen(generator, node[1]), gen(generator, node[2]), gen(generator, node[3])]
  of "[]":
    result = "$#[$#]" % [gen(generator, node[1]), gen(generator, node[2])]
  of "newFloat2":
    result = "(float2)($#, $#)" % [generator.gen(node[1]), generator.gen(node[2])]
  of "newFloat3":
    result = "(float3)($#, $#, $#)" % [generator.gen(node[1]), generator.gen(node[2]), generator.gen(node[3])]
  of "newFloat4":
    result = "(float4)($#, $#, $#, $#)" % [generator.gen(node[1]), generator.gen(node[2]), generator.gen(node[3]), generator.gen(node[4])]
  of "echo":
    result = genEcho(generator, node)
  of "inc":
    result = "$# += $#" % [genTmpSym(generator, node[1]), gen(generator, node[2])]
  else:
    for bf in builtinFunctions:
      # get arg types
      var args = newSeq[string]()
      for i in 1..<node.len:
        args.add(getTypeName(generator, node[i]).name)

      # if match builtin function
      if bf.name == $node[0] and equals(args, bf.args):
        var arggen = newSeq[string]()
        for i in 1..<node.len:
          arggen.add(gen(generator, node[i]))
        return "$#($#)" % [bf.raw, arggen.join(", ")]

    # others
    result = genExternalProcCall(generator, node)

proc genFloatLit*(generator: Generator, node: NimNode): string =
  return $node.floatval & "f"
proc genFloat32Lit*(generator: Generator, node: NimNode): string =
  return $node.floatval & "f"
proc genFloat64Lit*(generator: Generator, node: NimNode): string =
  return $node.floatval & "f"

proc genIntLit*(generator: Generator, node: NimNode): string =
  if getTypeName(generator, node).name == "bool":
    if node.boolVal == true:
      return "1"
    else:
      return "0"
  else:
    return node.repr

proc genVarSection*(generator: Generator, node: NimNode): string =
  result = ""
  var t = if node[0][1].kind == nnkEmpty: getTypeName(generator, node[0][2]) else: $node[0][1]
  if t.name == "bool":
    t.name = "int"

  if generator.variables.hasKey($node[0][0]):
    var sym = generator.genSym($node[0][0])
    result &= t.genTypeDecl(sym)
    generator.variables[$node[0][0]] = sym
  else:
    result &= t.genTypeDecl($node[0][0])
    generator.variables[$node[0][0]] = $node[0][0]

  if node[0][2].kind != nnkEmpty:
    result &= " = "
    result &= generator.gen(node[0][2])

proc genIfStmt*(generator: Generator, node: NimNode): string =
  result = ""
  result &= "if ($#)" % gen(generator, node[0][0])
  result &= " {" & generator.newline()
  result &= genStmtList(generator, node[0][1])
  result &= generator.indent() & "}"
  for i in 1..<node.len:
    if node[i].kind == nnkElifBranch:
      result &= " else if ($#) {" % gen(generator, node[i][0]) & generator.newline()
      result &= genStmtList(generator, node[i][1])
      result &= generator.indent() & "}"
    else:
      result &= " else {" & generator.newline()
      result &= genStmtList(generator, node[i][0])
      result &= generator.indent() & "}"

proc genConv*(generator: Generator, node: NimNode): string =
  let typ = node[0]
  let value = node[1]
  if typ.kind == nnkEmpty:
    return gen(generator, value)
  else:
    return "($#)($#)" % [getTypeNameInside(generator, typ).name, gen(generator, value)]

const builtinInfixTypes* = @[
  "float",
  "float2",
  "float3",
  "float4",
  "int",
]

proc isBulitinInfix*(op: string, left: TypeInfo, right: TypeInfo): bool =
  if left.isArray() or right.isArray():
    return false
  for t in builtinInfixTypes:
    if left.name == t and right.name == t:
      return true
  if left.name == "float" and right.name == "double":
    return true
  elif left.name == "double" and right.name == "float":
    return true
  else:
    return false

proc genInfix*(generator: Generator, node: NimNode): string =
  let op = node[0]
  let left = node[1]
  let right = node[2]
  for t in builtinInfixTypes:
    var lt = getTypeName(generator, left)
    var rt = getTypeName(generator, right)
    if isBulitinInfix($op, lt, rt):
      return "($# $# $#)" % [gen(generator, left), $op, gen(generator, right)]
    elif $op == "and":
      return "($# && $#)" % [gen(generator, left), gen(generator, right)]
    elif $op == "or":
      return "($# || $#)" % [gen(generator, left), gen(generator, right)]
  return genExternalProcCall(generator, node)

proc genAttributeName*(generator: Generator, typ: NimNode): string =
  if typ.kind == nnkBracketExpr:
    case $typ[0]
    of "Global":
      return "__global "
    of "Local":
      return "__local "
    of "Private":
      return "__private "
    of "Constant":
      return "__constant "
    else:
      return ""
  else:
    return ""

proc genArg*(generator: Generator, arg: NimNode): string =
  result = ""
  let name = arg[0]
  let typ = arg[1]
  # result &= genAttributeName(generator, typ)
  result &= getTypeNameInside(generator, typ).genTypeDecl($name)

proc genProcDef*(generator: Generator, node: NimNode, mangling = true): string =
  result = ""
  let procname = $node[0]
  let manglingname = if mangling: generator.genSym(procname) else: procname
  let procret = if node[3][0].kind == nnkEmpty: "void".toTypeInfo() else: getTypeName(generator, node[3][0])

  if procret.isArray():
    raise newException(GPGPULanuageError, "cannot return array in proc")

  # args
  var argsstr: seq[string] = @[]
  var argtypes: seq[string] = @[]
  for i in 1..<node[3].len:
    argsstr.add(genArg(generator, node[3][i]))
    argtypes.add(getTypeNameInside(generator, node[3][i][1]).genTypeDecl("mangling"))

  # register mangling name to generator
  if not generator.procs.hasKey(procname):
    generator.procs[procname] = @[]
  generator.procs[procname].add(OverloadProc(types: argtypes, manglingname: manglingname))

  # gen decl
  result &= "$# $#($#)" % [procret.name, manglingname, argsstr.join(", ")]
  result &= " {" & generator.newline()

  # gen result prologue
  if procret.name != "void":
    generator.inc()
    result &= generator.indent()
    result &= "$# result;" % [procret.name] 
    result &= generator.newline()
    generator.dec()

  # gen body
  result &= genStmtList(generator, node[6])

  # gen result epilogue
  if not generator.isReturn and procret.name != "void":
    generator.inc()
    result &= generator.indent() & "return result;" & generator.newline()
    generator.dec()
  result &= generator.indent() & "}"

proc genReturnStmt*(generator: Generator, node: NimNode): string =
  generator.isReturn = true
  if node[0].kind == nnkEmpty:
    result = "return"
  elif node[0].kind == nnkAsgn and $node[0][0] == "result":
    result = ""
    result &= "result = " & gen(generator, node[0][1]) & ";" & generator.newline() 
    result &= generator.indent() & "return result"
  else:
    result = "return $#" % gen(generator, node)

proc genAsgn*(generator: Generator, node: NimNode): string =
  return "$# = $#" % [gen(generator, node[0]), gen(generator, node[1])]

proc genFastAsgn*(generator: Generator, node: NimNode): string =
  let t = getTypeName(generator, node[1])
  generator.isInTmpStmt = true
  result = t.genTypeDecl($node[0]) & " = " & gen(generator, node[1])
  generator.isInTmpStmt = false

proc genSpecialBlock*(generator: Generator, node: NimNode): string =
  result = ""
  if node[1][1].kind == nnkFastAsgn and $node[1][1][0] == ":tmp":
    generator.inc()

    generator.isInTmpStmt = true

    let tmpsyms = generator.genSym("tmp")
    result &= generator.indent()
    result &= getTypeName(generator, node[1][1][1]).genTypeDecl(tmpsyms)
    result &= " = $#;" % gen(generator, node[1][1][1])
    result &= generator.newline()
    generator.tmpinfo.s = tmpsyms

    var body = node[1][2]
    if node[1][2].kind == nnkFastAsgn:
      let tmpsyme = generator.genSym("tmp")
      result &= generator.indent()
      result &= getTypeName(generator, node[1][2][1]).genTypeDecl(tmpsyme)
      result &= " = $#;" % gen(generator, node[1][2][1])
      result &= generator.newline()
      generator.tmpinfo.e = tmpsyme
      body = node[1][3]
    if body[0].kind == nnkCommentStmt:
      body = body[1]
    # echo body.treerepr
      
    var varsection = body[0]
    let tmpsymi = generator.genSym("i")
    result &= generator.indent()
    result &= getTypeName(generator, varsection[0][2]).genTypeDecl(tmpsymi)
    result &= " = $#;" % gen(generator, varsection[0][2])
    result &= generator.newline()
    generator.iinfo = tmpsymi

    generator.isInTmpStmt = false

    result &= generator.indent() & gen(generator, body[1]) & ";"

    generator.dec()
  else:
    generator.inc()
    
    let varsection = if node[1][1][0].kind == nnkCommentStmt: node[1][1][1][0] else: node[1][1][0]
    let tmpsymi = generator.genSym("i")
    result &= generator.indent()
    result &= getTypeName(generator, varsection[0][2]).genTypeDecl(tmpsymi)
    result &= " = $#;" % gen(generator, varsection[0][2])
    result &= generator.newline()
    generator.tmpinfo.s = tmpsymi
    generator.tmpinfo.e = tmpsymi
    generator.iinfo = tmpsymi

    let body = if node[1][1][0].kind == nnkCommentStmt: node[1][1][1][1] else: node[1][1][1] 
    result &= generator.indent() & gen(generator, body) & ";"

    generator.dec()

proc genBlockStmt*(generator: Generator, node: NimNode): string =
  var tmpi = generator.iinfo
  defer: generator.iinfo = tmpi
  var tmptmpi = generator.tmpinfo
  defer: generator.tmpinfo = tmptmpi
  result = ""
  result &= "{" & generator.newline()
  if node[1][0].kind == nnkVarSection and node[1][0][0][2].kind == nnkEmpty:
    result &= genSpecialBlock(generator, node) & generator.newline()
    result &= generator.indent() & "}"
  else:
    result &= genStmtList(generator, node[1])
    result &= generator.indent() & "}"

proc genWhileStmt*(generator: Generator, node: NimNode): string =
  result = ""
  generator.isInTmpStmt = true
  result &= "while ($#)" % gen(generator, node[0])
  generator.isInTmpStmt = false
  result &= " {" & generator.newline()
  result &= genStmtList(generator, node[1])
  result &= generator.indent() & "}"

proc genObjField*(generator: Generator, node: NimNode, varname: string): string =
  return "$#.$# = $#;" % [varname, $node[0], gen(generator, node[1])]

proc genObjConstr*(generator: Generator, node: NimNode): string =
  discard genObjectTy(generator, node[0], $node[0])
  var tmp = generator.genSym("tmp")
  var prev = ""
  prev &= generator.indent() & "$# $#;" % [$node[0], tmp] & generator.newline()
  for i in 1..<node.len:
    prev &= generator.indent() & genObjField(generator, node[i], tmp) & generator.newline()
  generator.prevStmts.add(prev)
  return tmp

proc genDotExpr*(generator: Generator, node: NimNode): string =
  return "$#.$#" % [gen(generator, node[0]), gen(generator, node[1])]

proc genBracket*(generator: Generator, node: NimNode): string =
  var args: seq[string] = @[]
  for v in node.children:
    args.add(gen(generator, v))
  return "{$#}" % args.join(", ")

proc genBracketExpr*(generator: Generator, node: NimNode): string =
  return "$#[$#]" % [gen(generator, node[0]), gen(generator, node[1])]

proc genDerefExpr*(generator: Generator, node: NimNode): string =
  return "(*$#)" % gen(generator, node[0])

proc genPrefix*(generator: Generator, node: NimNode): string =
  if node[0].repr == "not":
    return "!($#)" % gen(generator, node[1])
  else:
    return "$# $#" % [gen(generator, node[0]), gen(generator, node[1])]

proc gen*(generator: Generator, node: NimNode): string =
  case node.kind
  of nnkLetSection, nnkVarSection:
    result = genVarSection(generator, node)
  of nnkCall, nnkCommand:
    result = genCall(generator, node)
  of nnkFloatLit:
    result = genFloatLit(generator, node)
  of nnkFloat32Lit:
    result = genFloat32Lit(generator, node)
  of nnkFloat64Lit:
    result = genFloat64Lit(generator, node)
  of nnkIntLit:
    result = genIntLit(generator, node)
  of nnkIfStmt:
    result = genIfStmt(generator, node)
  of nnkConv, nnkHiddenStdConv:
    result = genConv(generator, node)
  of nnkInfix:
    result = genInfix(generator, node)
  of nnkIdent:
    result = genIdent(generator, node)
  of nnkSym:
    result = genSymbol(generator, node)
  of nnkProcDef:
    result = genProcDef(generator, node)
  of nnkReturnStmt: 
    result = genReturnStmt(generator, node)
  of nnkAsgn:
    result = genAsgn(generator, node)
  of nnkFastAsgn:
    result = genFastAsgn(generator, node)
  of nnkBlockStmt:
    result = genBlockStmt(generator, node)
  of nnkWhileStmt:
    result = genWhileStmt(generator, node)
  of nnkObjConstr:
    result = genObjConstr(generator, node)
  of nnkDotExpr:
    result = genDotExpr(generator, node)
  of nnkBracket:
    result = genBracket(generator, node)
  of nnkBracketExpr:
    result = genBracketExpr(generator, node)
  of nnkDerefExpr:
    result = genDerefExpr(generator, node)
  of nnkPrefix:
    result = genPrefix(generator, node)
  of nnkHiddenAddr:
    result = gen(generator, node[0])
  of nnkBreakStmt:
    result = "break"
  of nnkStmtList, nnkStmtListExpr:
    result = genPrevStmtList(generator, node)
  else:
    raise newException(GPGPULanuageError, "unsupported expression: " & node.repr & "(" & $node.kind & ")")

proc genKernel*(generator: Generator, node: NimNode): string =
  result = ""
  let procimpl = node.symbol.getImpl()
  # echo procimpl.repr
  # echo procimpl.treeRepr
  result &= "__kernel "
  result &= genProcDef(generator, procimpl, mangling = false)

macro getSymbol*(node: typed): untyped =
  return node.symbol

macro getKernel*(kernelname: varargs[typed, getSymbol], indentSize = 2, isFormat = true): untyped =
  var generator = newGenerator(indentSize.intval.int, isFormat.boolval)
  var kernelsrc = genKernel(generator, kernelname)
  var src = concat(generator.toplevels, @[kernelsrc]).join("\n")
  return newStrLitNode(src)

macro defProgram*(name: untyped, body: untyped): untyped =
  name.expectKind(nnkIdent)
  for kernel in body.children:
    kernel.expectKind(nnkIdent)

  var genstr = ""
  genstr &= "macro gen$#*(): untyped =\n" % $name
  genstr &= "  var tmpsrcs: seq[string] = @[]\n"
  genstr &= "  var generator = newGenerator()\n"
  for kernel in body.children:
    genstr &= "  var $1 = bindSym(\"$1\")\n" % $kernel
  for kernel in body.children:
    genstr &= "  tmpsrcs.add(genKernel(generator, $#))\n" % $kernel
  genstr &= "  return newStrLitNode(concat(generator.toplevels, tmpsrcs).join(\"\\n\"))\n"
  return genstr.parseStmt()

template getProgram*(name: untyped): string =
  `gen name`
