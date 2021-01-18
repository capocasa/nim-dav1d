
nim-dav1d
---------

nim-david is a wrapper for the dav1d, a fast, portable av1 decoder.

It adds a low-cost, high-level memory safe Nim interface.

Usage
-----

Usually, a demultiplexer such as https://github.com/capocasa/nim-nestegg is used to get encoded video data from a file.

These packets are then passed to the decoder to get usable video data.

```nim

let myData = getDataFromDemuxer()

let decoder = newDecoder()

decoder.send(myData)

let texture = getSDLTextureFromMyProject()

let picture = decoder.getPicture()

discard updateYUVTexture(texture, nil, 
  cast[ptr byte](pic.raw.data[0]), pic.raw.stride[0].cint, # Y
  cast[ptr byte](pic.raw.data[1]), pic.raw.stride[1].cint, # U
  cast[ptr byte](pic.raw.data[2]), pic.raw.stride[1].cint  # V
)

```

The C interface can be used directly as well. Please see the dav1d/wrapper documentation for details.

Limitations
-----------

Note that memory is allocated by the library itself. This means that in multithreaded code- and it is likely this is required by your application- only shared heap garbage collectors are supported, but not the default refc. Specifically using the refc GC and channels will cause null pointer crashes, because the decoding thread will free the C memory but the main thread will try to access the decoded data. If you would like to use the default GC, consider using the C interface directly using dav1d/wrapper.

Documentation
-------------

Library documentation may be accessed http://capocasa.github.io/nim-dav1d/dav1d.html

Further Information
-------------------

For a fuller usage example, project status and design rationale that also applies to nim-dav1id, see https://github.com/capocasa/lov, a minimalistic nim av1-opus-webm video player.

