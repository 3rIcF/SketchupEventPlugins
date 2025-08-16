# frozen_string_literal: true

require 'sketchup'
require 'extensions'

ext = SketchupExtension.new('Elementaro AutoInfo Dev', 'ElementaroInfoDev/main')
ext.description = 'AutoInfo/BOM: Liste, Karten/Library, Katalog, Filter-Cache, Thumbnails'
ext.version     = '2.3.1'
ext.creator     = 'Elementaro'

Sketchup.register_extension(ext, true)
