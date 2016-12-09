
import unittest
import nim2cl
import re

proc formatSrc(src: string): string =
  return src[0..^3]

include language_test
include render_test