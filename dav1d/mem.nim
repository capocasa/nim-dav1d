
import dav1d/wrapper

include system/bitmasks

template `+!`(p: pointer, s: SomeInteger): pointer =
  cast[pointer](cast[int](p) +% int(s))

template `-!`(p: pointer, s: SomeInteger): pointer =
  cast[pointer](cast[int](p) -% int(s))

proc nd_alignedAlloc0(size, align: Natural): pointer =
  ## copy/paste unexported aligned alloc from nim system module (source: 1.4.2)
  if align <= MemAlign:
    when compileOption("threads"):
      result = allocShared0(size)
    else:
      result = alloc0(size)
  else:
    # allocate (size + align - 1) necessary for alignment,
    # plus 2 bytes to store offset
    when compileOption("threads"):
      let base = allocShared0(size + align - 1 + sizeof(uint16))
    else:
      let base = alloc0(size + align - 1 + sizeof(uint16))
    let offset = align - (cast[int](base) and (align - 1))
    cast[ptr uint16](base +! (offset - sizeof(uint16)))[] = uint16(offset)
    result = base +! offset

proc nd_alignedDealloc(p: pointer, align: int) {.compilerproc.} =
  if align <= MemAlign:
    when compileOption("threads"):
      deallocShared(p)
    else:
      dealloc(p)
  else:
    # read offset at p - 2 bytes, then deallocate (p - offset) pointer
    let offset = cast[ptr uint16](p -! sizeof(uint16))[]
    when compileOption("threads"):
      deallocShared(p -! offset)
    else:
      dealloc(p -! offset)

const PICTURE_ALIGN=64

proc alloc*(raw: ptr cPicture, cookie: pointer): cint {.cdecl} =
  ## Transliteration of the dav1d default picture allocator and its alignment magic
  ## modified to use alignedAlloc0 taken from nim stdlib
  ## Prevents any direct C memory management by dav1d and uses nim's mechanisms instead
  let hbd = raw.p.bpc > 8
  let aligned_w = (raw.p.w + 127) and not 127
  let aligned_h = (raw.p.h + 127) and not 127
  let has_chroma = raw.p.layout != PIXEL_LAYOUT_I400
  let ss_ver = raw.p.layout == PIXEL_LAYOUT_I420
  let ss_hor = raw.p.layout != PIXEL_LAYOUT_I444
  var y_stride = aligned_w shl hbd.cint
  var uv_stride = if has_chroma: y_stride shr ss_hor.cint else: 0
  if not (y_stride and 1023).bool:
    y_stride += PICTURE_ALIGNMENT
  if not (uv_stride and 1023).bool and has_chroma:
    uv_stride += PICTURE_ALIGNMENT
  raw.stride[0] = y_stride;
  raw.stride[1] = uv_stride;
  let y_sz = y_stride * aligned_h
  let uv_sz = uv_stride * (aligned_h shr ss_ver.int)
  let pic_size = y_sz + 2 * uv_sz

  var data = nd_alignedAlloc0(pic_size, PICTURE_ALIGN)
  raw.allocator_data = data
  raw.data[0] = data
  raw.data[1] = if has_chroma: cast[pointer](cast[ByteAddress](data) + y_sz.ByteAddress) else: nil
  raw.data[2] = if has_chroma: cast[pointer](cast[ByteAddress](data) + y_sz.ByteAddress + uv_sz.ByteAddress) else: nil

  return 0

proc dealloc*(raw: ptr cPicture, cookie: pointer) {.cdecl} =
  nd_alignedDealloc(raw.allocator_data, PICTURE_ALIGN)


