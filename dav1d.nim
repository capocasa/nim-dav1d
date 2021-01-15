
## dav1d is an AV1 video codec implementation created by the kind folks at VideoLAN and is widely used.
## 
## This Nim wrapper puts a low-cost memory safe high level on top of it. If the low-level API is required,
## applications can include dav1d/wrapper directly.

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
    settings*: Settings
    context*: ptr Context
  Decoder* = ref DecoderObj
    ## which in turn frees the wrapped library's untraced heap memory.
  PictureObj* = object
    ## A container object for one frame of decoded video data
    raw*: ptr cPicture
  Picture* = ref PictureObj
    ## A memory safe reference to one frame of decoded video data
  DataObj* = object
    ## A container objcet for low-lavel encoded video data
    raw*: cData
  Data* = ref DataObj
    ## A memory safe reference to encoded video data

proc cleanup(decoder: Decoder) =
  close(decoder.context.addr)

proc flush*(decoder: Decoder) =
  ## Reset the decoder. Do this before a seek
  flush(decoder.context)

template formatError(code: cint): string =
  $strerror(abs(code))

proc newDecoder*(): Decoder =
  ## Initialize a decoder
  new(result, cleanup)
  default_settings(result.settings.addr)
  if 0 != open(result.context.addr, result.settings.addr):
    raise newException(InitError, "Failed to initialize Dav1d av1 decoder")

proc cleanup(data: Data) =
  discard

proc cleanup(buf: ptr uint8; cookie: pointer) {.cdecl.} =
  discard

proc newData*(encoded: openArray[byte]): Data =
  ## Create a new data object from an encoded data chunk that can
  ## be sent to the decoder.
  new(result, cleanup)
  let r = data_wrap(result.raw.addr, encoded[0].unsafeAddr, encoded.len.uint, cleanup, nil)
  if r < 0:
    raise newException(DecodeError, r.formatError)

template newData*(encoded: ptr UncheckedArray[byte], len: int): Data =
  ## Create a new data object from an unchecked array and a length instead of an OpenArray
  ## This can also be used to send a pointer and a length, by casting it to the UncheckedArray[byte] type
  newData(toOpenArray(encoded, 0, len-1))

proc send*(decoder: Decoder, data: Data) =
  ## Actually send the data to the decoder. It will be available to retrieve using the getPicture object
  ## If a BufferError is raised, then no more data can be queued- getPicture needs to be called first.
  ## This error should be caught, and responeded to.
  ## If a DecodeError is raised, then something actually is wrong with the encoded data
  let r = send_data(decoder.context, data.raw.addr)
  if r < 0:
    if abs(r) == EAGAIN:
      raise newException(BufferError, "could not send data, must consume picture first")
    raise newException(DecodeError, "Decoding error while sending data: $#" % r.formatError)

template send*(decoder: Decoder, encoded: openArray[byte]) =
  ## Convenience function to send array data to the encoded without explicitly creating
  ## a data object. toOpenArray can be used to send further types of data
  send(decoder, newData(encoded))

template send*(decoder: Decoder, encoded: ptr UncheckedArray[byte], len: int) =
  ## Convenience function to send array-and-length data to dav1d
  send(decoder, newData(encoded, len))

proc cleanup(picture: Picture) =
  picture_unref(picture.raw)
  deallocShared(picture.raw)

proc getPicture*(decoder: Decoder): Picture =
  ## Retrieve one frame of decoded video data.
  ## If a BufferError is raised, not enough data is available- call send first and try again.
  ## If a DecodeError is raised, something is actually wrong with the decoding process.
  new(result, cleanup)
  result.raw = cast[ptr cPicture](allocShared0(sizeof(cPicture)))
  let r = get_picture(decoder.context, result.raw)
  if r < 0:
    if abs(r) == EAGAIN:
      raise newException(BufferError, "could not consume picture, must send more data first")
    raise newException(DecodeError, "Decoding error while consuming picture: $#" % r.formatError)

