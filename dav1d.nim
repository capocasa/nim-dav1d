
import dav1d/wrapper

import posix
  # dav1d uses posix error codes
import strutils

export cPicture

{.passL: "-lpthread -ldl".}
  # dav1d uses pthread and dl

type
  InitError* = object of ValueError
    ## Error is raised if something about initializing the decoder doesn't work out
  DecodeError* = object of ValueError
    ## Error is raised if there is a permanent error sending data to the decoder
  BufferError* = object of ValueError
    ## Error is raised if the data send failed because decoded data need be retrieved first,
    ## or if data retrieve failed because insufficient data was send. This is usually caught
    ## and decoding resumed when the condition has been resolved.
  DecoderObj* = object
    ## Holds the initialization data for a Dav1d decoder
    settings: Settings
    context: ptr Context
    ## Reference to put the decoder on the heap so collecting it will call the finalizer,
    ## which in turn frees the wrapped library's untraced heap memory.
  Decoder* = ref DecoderObj
  PictureObj* = object
    raw*: ptr cPicture
  Picture* = ref PictureObj
  DataObj* = object
    raw*: ptr cData
  Data* = ref DataObj

proc cleanup(decoder: Decoder) =
  close(decoder.context.addr)

template formatError(code: cint): string =
  $strerror(abs(code))

proc newDecoder*(): Decoder =
  ## Initialize a decoder
  new(result, cleanup)
  default_settings(result.settings.addr)
  if 0 != open(result.context.addr, result.settings.addr):
    raise newException(InitError, "Failed to initialize Dav1d av1 decoder")

proc cleanup(data: Data) =
  data_unref(data.raw)

proc newData*(data: ptr uint8, size: uint): Data =
  new(result, cleanup)
  result.raw = cast[ptr cData](alloc(sizeof(cData)))
  let internalPointer = data_create(result.raw, size)
  if internalPointer == nil:
    raise newException(DecodeError, "Could not create internal decoder object")
  
  # Did not find an obvious way to create a Data object with demuxer-allocated memory
  # so copy provided data into dav1d's memory pool- it's the encoded data, not *that* big, will do for now
  copyMem(internalPointer, data, size)

proc send*(decoder: Decoder, data: Data) =
  let r = send_data(decoder.context, data.raw)
  if r < 0:
    if abs(r) == EAGAIN:
      raise newException(BufferError, "could not send data, must consume picture first")
    raise newException(DecodeError, "Decoding error while sending data: $#" % r.formatError)

proc cleanup(picture: Picture) =
  picture_unref(picture.raw)

proc getPicture*(decoder: Decoder): Picture =
  new(result, cleanup)
  result.raw = cast[ptr cPicture](alloc0(sizeof(cPicture)))
  let r = get_picture(decoder.context, result.raw)
  if r < 0:
    if abs(r) == EAGAIN:
      raise newException(BufferError, "could not consume picture, must send more data first")
    raise newException(DecodeError, "Decoding error while consuming picture: $#" % r.formatError)

