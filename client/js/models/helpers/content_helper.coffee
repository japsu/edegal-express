Promise = require 'bluebird'

{Album, albums} = require '../album.coffee'
{Picture, pictures} = require '../picture.coffee'

getContent = (path) ->
  picture = pictures.get(path)
  return Promise.when {album: picture.get('album'), picture} if picture

  album = albums.get(path)
  return Promise.when {album: album, picture: null} if album

  album = new Album path: path
  Promise.when album.fetch(), ->
    albums.add album
    album.get('pictures').forEach (picture) -> pictures.add picture
    picture = album.get('pictures').findWhere path: path

    {album, picture}

module.exports = {getContent}