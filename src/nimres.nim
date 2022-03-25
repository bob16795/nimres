import macros
export macros
import sets
export sets
import tables
export tables
import strutils
import hashes
import os
export os

type
  Resource* = object
    start*: int
    size*: int

template resToc*(parent, target: string, files: untyped) =
  import tables
  export tables
  import streams
  export streams

  var
    file_table {.compileTime, genSym.}: OrderedTable[string, Resource]
    file_size {.compileTime, genSym.}: int = 0
    t {.compileTime, genSym.} = target

  # generate the resource file
  static:
    try:
      var targetdata: string
      for f in files:
        if file_table.contains(f):
          error("File already used '" & f & "'")
        var
          bytes = staticRead((parent / f).replace("\\", "/"))
        echo "read '" & f.extractFilename() & "'"
        file_table[f.extractFilename()] = Resource(start: file_size,
            size: bytes.len())
        file_size += bytes.len()
        targetdata &= bytes
      writeFile((parent / t).replace("\\", "/"), targetdata)
    except: discard
    echo "wrote '" & t & "'"

  const
    TOTAL_SIZE = file_size
    FINAL_TABLE = fileTable
    RESOURCES_PATH = target

  var
    resourcesData = alloc(TOTAL_SIZE)
    tempFile = open(getAppDir() / RESOURCES_PATH)
  discard tempFile.readBuffer(resourcesData, TOTAL_SIZE)
  tempFile.close()

  template `+`*(p: pointer, off: int): pointer =
    cast[pointer](cast[ByteAddress](p) +% off)

  template getPointer*(res: Resource): pointer =
    resourcesData + res.start.int

  proc openStream*(res: Resource): Stream =
    result = newStringStream("")
    result.writedata(res.getPointer(), res.size)
    result.setPosition(0)

  proc contents*(res: Resource): string =
    var stream = openStream(res)
    result = stream.readAll()
    stream.close()

  proc handleFile(name: string, file: NimNode): NimNode {.compileTime.} =
    # returns a Resource object
    if FINAL_TABLE.hasKey(name):
      # This message is in the catalog.
      template retrieve(fileName): untyped =
        FINAL_TABLE[$fileName]
      return getAst(retrieve(file))
    else:
      # This message is not known to the catalog.
      # Use the source-provided value.
      error("The resource '" & name & "' is missing", file)
      return file

  macro file*(name: string, message: untyped): untyped =
    ## TODO
    handleFile($name, message.copyNimTree())

  macro file*(message: untyped): untyped =
    ## TODO
    let saniname = extractFilename($message)
    handleFile(saniname, message.copyNimTree())
