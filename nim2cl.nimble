
version = "0.1.0"
author = "shsnow23"
description = "nim2cl is a translator from nim to computing language"
license = "MIT"

srcDir = "src"

requires "nim >= 0.15.2" 

task test, "test nim2cl":
  exec "nim c -r tests/tester.nim"
  