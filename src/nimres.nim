import macros
export macros
import sets
import tables
import strutils
import memfiles
import streams
import os

export os
export sets
export tables
export macros
export streams

type
  Resource* = object
    start*: int
    size*: int
  ResourceStreamObj* = object of StreamObj
    data: pointer
    size: int
    pos: int
  ResourceStream* = ref ResourceStreamObj

template `+`*(p: pointer, off: int): pointer =
  cast[pointer](cast[ByteAddress](p) +% off)

proc rsAtEnd(s: Stream): bool =
  var s = ResourceStream(s)
  return s.pos >= s.size

proc rsSetPosition(s: Stream, pos: int) =
  var s = ResourceStream(s)
  s.pos = pos

proc rsGetPosition(s: Stream): int =
  var s = ResourceStream(s)
  return s.pos

proc rsReadDataStr(s: Stream, buffer: var string, slice: Slice[int]): int =
  var s = ResourceStream(s)
  result = min(slice.b + 1 - slice.a, s.size - s.pos)
  if result > 0:
    copyMem(unsafeAddr buffer[slice.a], s.data + s.pos, result)
    inc(s.pos, result)
  else:
    result = 0

proc rsReadData(s: Stream, buffer: pointer, bufLen: int): int =
  var s = ResourceStream(s)
  result = min(bufLen, s.size - s.pos)
  if result > 0:
    copyMem(buffer, s.data + s.pos, result)
    inc(s.pos, result)
  else:
    result = 0

proc newResourceStream*(data: pointer, size: int): owned ResourceStream =
  new(result)

  result.data = data
  result.size = size
  result.pos = 0

  result.atEndImpl = rsAtEnd
  result.setPositionImpl = rsSetPosition
  result.getPositionImpl = rsGetPosition
  result.readDataImpl = rsReadData
  result.readDataStrImpl = rsReadDataStr

template resToc*(parent, target: string, files: varargs[string]) =
  import tables
  export tables
  import streams
  export streams
  export Resource
  import strutils

  var
    file_table {.compileTime, genSym.}: OrderedTable[string, Resource]
    file_size {.compileTime, genSym.}: int = 0
    t {.compileTime, genSym.} = target

  # generate the resource file
  static:
    var tmpDir = getTempDir() / "nimres"
    echo staticExec("mkdir -p " & tmpDir.replace("\\", "/"))

    var contents: string
    var targetdata: string
    for f in files:
      when defined(genContents):
        contents &= (parent / f).replace("\\", "/") & " "
        if file_table.contains(f):
          error("File already used '" & f & "'")
      else:
        var dataPath: string = "" 
        var fileName: string = ""
        if "|" in f:
          fileName = f.split("|")[0]
          var cmd = f.split("|")[1]
          echo "exec '" & cmd & "'"
          echo staticExec((parent / cmd).replace("\\", "/") & " " & (parent / fileName).replace("\\", "/") & " " & (tmpDir / fileName.extractFilename()).replace("\\", "/"))
          dataPath = tmpDir / fileName.extractFilename().replace("\\", "/")
        else:
          dataPath = parent / f
          fileName = f
        var
          bytes = staticRead((dataPath).replace("\\", "/"))
        echo "read '" & fileName & "'"
        file_table[fileName.extractFilename().replace("\\", "/")] = Resource(start: file_size,
            size: bytes.len())
        file_size += bytes.len()
        targetdata &= bytes
    for f in file_table.keys():
      echo f & " " & $file_table[f].size

    when defined(genContents):
      echo "contents: " & contents
      quit(1)
    else:
      writeFile((parent / t).replace("\\", "/"), targetdata)
      echo "wrote '" & t & "'"
  const
    TOTAL_SIZE = file_size
    FINAL_TABLE = fileTable
    RESOURCES_PATH = target

  let resourcesData = memfiles.open(getAppDir() / RESOURCES_PATH, mode = fmRead, mappedSize = TOTAL_SIZE)

  template getPointer*(res: Resource): pointer =
    resourcesData.mem + res.start.int

  proc openStream*(res: Resource): Stream {.inline.} =
    result = newResourceStream(res.getPointer(), res.size)

  proc `$`*(res: Resource): string {.inline.} =
    let stream = openStream(res)
    result = stream.readAll()
    stream.close()

  template handleRes(name: string, file: string): Resource =
    # returns a Resource object
    FINAL_TABLE.getOrDefault(file)

  proc res*(name: string, path: string): Resource {.inline.} =
    handleRes($name, path)

  proc res*(path: string): Resource {.inline.} =
    let tmpName = extractFilename(path)
    handleRes(tmpName, path)
