require 'sketchup.rb'
require 'extensions.rb'

ext = SketchupExtension.new('Elementaro AutoInfo Dev', 'ElementaroInfoDev/main')
ext.description = 'AutoInfo/BOM: Liste, Karten/Library, Katalog, Filter-Cache, Thumbnails'
ext.version     = '2.3.0'
ext.creator     = 'Elementaro'

Sketchup.register_extension(ext, true)
