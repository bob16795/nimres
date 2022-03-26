# nimres

nimres is a nim package used to bundle dependencys into a single file to be shipped with the executable that can store data from multiple other files.

## Alternatives

both of these store the assets in the executable.

[nimdeps](https://github.com/genotrance/nimdepss)
[nimassets](https://github.com/xmonader/nimassets)
## Quickstart

install `nimres`

```
nimble install https://github.com/bob16795/nimres.git
```

create a `files.nim` file containing:

```
import nimres

const root = currentSourcePath()

resToc root, "content.bin":
  [
    "file1.txt",
    # more files
  ]
```

import `files.nim` in any files you want to refrence a resource:

```
import files

# get the contents as a string
echo res"file1.txt".contents

# get the contents as a stream
var stream = res"file1.txt".openStream
stream.close()

# get the pointer of the contents
var dataPtr = res"file1.txt".getPointer

# get the size of the contents
var contents = res"file1.txt".size
```