# mkosuskin

Turn a folder with a bunch of project files & individual render scripts into a .osk.

## Folder format

Specify a folder to render with -p.

### render script

If an executable called `render` is in a subdirectory, it'll be executed.

It should handle the rendering of whatever is in that folder, and return a list of rendered files via a file called `rendered-files`, containing a json list of files.

`mkosuskin.rkt` will then look up the files and move them to a cache directory, `.cache/`, under the project directory.

### post processing

A series of post processing actions will be run on the files in cache depending on their filenames.

- resize-@nx: filename@*n*x will get resized to filename@2x
- resize-resizeto: filename_resizeto*n*x*m* or filename_resizeto*n*%, *n*x*m* or *n*% is passed to `convert -resize`
- crop: filename_tocrop*n*x*m*+*x*+*y* will be cropped to an area of *n*x*m*, with an offset (*x*, *y*)
- trim: filename_totrim gets trimmed
- resize-@2x: filename@2x gets resized to just filename, with the @2x version kept
