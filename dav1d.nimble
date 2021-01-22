# Package

version       = "0.1.0"
author        = "Carlo Capocasa"
description   = "Nim wrapper for dav1d, a fast, portable av1 video decoder created by videolan and used by VLC and Netflix"
license       = "BSD2"

# Dependencies

requires "nim >= 1.4.2"
requires "https://github.com/capocasa/nimterop#a2af4b6"

import distros
foreignDep "meson"
if detectOs(Windows):
  foreignDep("mingw-w64-x86_64-toolchain")
  foreignDep("mingw-w64-x86_64-nasm")
else:
  foreignDep "nasm"

