path = require 'path'

_ = require 'underscore'
Q = require 'q'

easyimg = require 'easyimage'
resizeImage = Q.nbind easyimg.resize, easyimg

mkdirp = require 'mkdirp'
makeDirectories = Q.denodeify mkdirp

{getAlbum, albums, saveAlbum} = require '../server/db'
{getOriginal} = require '../shared/helpers/media_helper'
{Semaphore} = require '../shared/helpers/concurrency_helper'

DEFAULT_QUALITY = 60

parseSize = (size) ->
  size = /(\d+)x(\d+)(?:@(\d+))?/.exec size
  return "Invalid size: #{size}" unless size

  width: parseInt size[1]
  height: parseInt size[2]
  quality: parseInt(size[3] ? DEFAULT_QUALITY)

mkPath = (first, theRest...) ->
  theRest = theRest.map (pathFrag) ->
    if pathFrag[0] == '/'
      pathFrag[1..]
    else
      pathFrag

  path.resolve first, theRest...

albumUpdateSemaphore = new Semaphore 1

createPreview = (opts) ->
  {albumPath, picture, size, root, output, quiet} = opts
  {width, height, quality} = size

  dstPathOnServer = path.join '/', output, picture.path, "max#{width}x#{height}q#{quality}.jpg"

  resizeOpts = _.extend {}, size,
    src: mkPath root, getOriginal(picture).src
    dst: mkPath root, dstPathOnServer

  makeDirectories(path.dirname(resizeOpts.dst)).then ->
    resizeImage(resizeOpts).spread (resized) ->
      albumUpdateSemaphore.push ->
        getAlbum(path: albumPath).then (album) ->
          picture = _.find album.pictures, (pic) -> pic.path == picture.path
          picture.media.push
            width: parseInt resized.width
            height: parseInt resized.height
            src: dstPathOnServer
          picture.media = _.sortBy picture.media, (medium) -> medium.width
          saveAlbum(album)
        .then ->
          process.stdout.write '.' unless quiet
    .fail ->
      console.warn '\nFailed to create thumbnail:', resizeOpts.src

createPreviews = (opts) ->
  {albums, sizes, concurrency, root, output, quiet} = opts

  sem = new Semaphore concurrency

  albums.forEach (album) ->
    album.pictures.forEach (picture) ->
      sizes.forEach (size) ->
        existingPreview = _.find picture.media, (medium) -> medium.width == size.width or medium.height == size.height

        if existingPreview
          process.stdout.write '-'
        else
          do (album, picture, size) ->
            sem.push ->
              createPreview
                albumPath: album.path
                picture: picture
                size: size
                root: root
                output: output
                quiet: quiet
            .done()

  sem.finished

if require.main is module
  argv = require('optimist')
    .usage('Usage: $0 -s 800x240 [-s 1200x700@85] [-p /foo]')
    .options('size', alias: 's', demand: true, describe: 'Size (WIDTHxHEIGHT[@QUALITY])')
    .options('path', alias: 'p', describe: 'Process only single album (default: all)')
    .options('output', alias: 'o', default: 'previews', 'Output folder for previews, relative to --root')
    .options('root', alias: 'r', default: 'public', 'Document root')
    .options('concurrency', alias: 'j', default: 4, 'Maximum parallel processes')
    .options('quiet', alias: 'q', boolean: true, "Don't print dots")
    .argv

  argv.size = [argv.size] unless _.isArray argv.size
  sizes = argv.size.map parseSize
  {concurrency, root, output, quiet} = argv

  Q.when null, ->
    if argv.path
      albums.find(path: argv.path)
    else
      albums.find()
  .then (albums) ->
    createPreviews {albums, sizes, concurrency, root, output, quiet}
  .then ->
    process.stdout.write '\n'
    process.exit()
  .done()