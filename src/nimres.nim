import macros
export macros
import sets
export sets
import tables
export tables
import strutils
import os
export os

type
  Resource* = object
    start*: int
    size*: int

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
    echo staticExec("mkdir -p " & tmpDir)

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
          echo staticExec(parent / cmd & " " & parent / fileName & " " & tmpDir / fileName.extractFilename())
          dataPath = tmpDir / fileName.extractFilename()
        else:
          dataPath = parent / f
          fileName = f
        var
          bytes = staticRead((dataPath).replace("\\", "/"))
        echo "read '" & fileName & "'"
        file_table[fileName.extractFilename()] = Resource(start: file_size,
            size: bytes.len())
        file_size += bytes.len()
        targetdata &= bytes
    echo staticExec("rm -rf " & tmpDir)
    echo file_table

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

  var
    resourcesData = alloc(TOTAL_SIZE)
    tempFile = open(getAppDir() / RESOURCES_PATH)
  discard tempFile.readBuffer(resourcesData, TOTAL_SIZE)
  tempFile.close()

  template `+`*(p: pointer, off: int): pointer =
    cast[pointer](cast[ByteAddress](p) +% off)

  template getPointer*(res: Resource): pointer =
    resourcesData + res.start.int

  proc openStream*(res: Resource): Stream {.inline.} =
    result = newStringStream("")
    result.writedata(res.getPointer(), res.size)
    result.setPosition(0)

  proc `$`*(res: Resource): string {.inline.} =
    var stream = openStream(res)
    result = stream.readAll()
    stream.close()

  template handleRes(name: string, file: string): Resource =
    # returns a Resource object
    FINAL_TABLE.getOrDefault(file)

  proc res*(name: string, path: string): Resource {.inline.} =
    handleRes($name, path)

  proc res*(path: string): Resource {.inline.} =
    var tmpName = extractFilename(path)
    handleRes(tmpName, path)
