
import dav1d/wrapper

type
  InitError = object of IOError
  DecoderObj = object
    settings: ptr Settings
    context: ptr Context
  Decoder = ref DecoderObj

proc cleanup(d: Decoder) =
  close(d.context.addr)

proc newDecoder(): Decoder =
  new(result, cleanup)
  default_settings(result.settings)
  if 1 != open(result.context.addr, result.settings):
    raise newException(InitError, "Failed to initialize Dav1d decoder")

