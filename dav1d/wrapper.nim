import nimterop/[build, cimport]
 
## Low-level C-wrapper for dav1d av1 decoder
## generated with nimterop
##
## Everything is imported, "dav1d_" prefix is removed

# fetch and build configuration
setDefines(@["dav1dGit", "dav1dSetVer=2ca1bfc3", "dav1dStatic"])

static:
  cDebug()

const
  baseDir = getProjectCacheDir("dav1d")

getHeader(
  "dav1d.h",
  giturl = "https://code.videolan.org/videolan/dav1d.git",
  outdir = baseDir,
  mesonFlags = "--default-library=static"
)

cPlugin:
  import strutils

  # Strip prefix from procs
  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
    if sym.name.toLowerAscii.startsWith("dav1d_"):
      sym.name = sym.name.substr(6)

# supplement automatic conversions with hand-edits
#[
cOverride:
  const
    CODEC_UNKNOWN* = high(cint)
    TRACK_UNKNOWN* = high(cint)
]#

# import symbols
cIncludeDir @[baseDir/"build/include/dav1d"]
cImport dav1dPath, recurse=true

