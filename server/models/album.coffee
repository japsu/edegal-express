{Schema} = mongoose = require 'mongoose'

{mediaSchema, mediaSpec} = require './media.coffee'
{pictureSchema} = require './picture.coffee'

exports.albumSchema = albumSchema = new Schema
  path:
    type: String
    required: true
    index: true

  title:
    type: String
    required: true

  version:
    type: Number
    required: true
    'default': 0

  description: String

  breadcrumb: [
    path:
      type: String
      required: true

    title:
      type: String
      required: true
  ]

  subalbums: [
    path:
      type: String
      required: true

    title:
      type: String
      required: true

    thumbnail:
      type: mediaSpec
      required: false
  ]

  pictures: [pictureSchema]

albumSchema.index {'pictures.path': 1}, {unique: true, sparse: true}
albumSchema.index {'breadcrumb.path': 1}

exports.Album = Album = mongoose.model 'Album', albumSchema, 'albums'