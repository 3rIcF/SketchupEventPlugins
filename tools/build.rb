#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'shellwords'

ROOT    = File.expand_path('..', __dir__)
DIST    = File.join(ROOT, 'dist')
VERSION = begin
  File.read(File.join(ROOT, 'VERSION')).strip
rescue StandardError
  '0.0.0'
end
TARGET  = File.join(DIST, "elementaro_autoinfo_dev-v#{VERSION}.rbz")
SOURCES = %w[elementaro_autoinfo_dev.rb ElementaroInfoDev README.md].freeze

FileUtils.mkdir_p(DIST)

Dir.chdir(ROOT) do
  zip_cmd = ['zip', '-r', TARGET, *SOURCES].map { |p| Shellwords.escape(p) }.join(' ')
  abort('zip command failed') unless system(zip_cmd)
end

puts "Created #{TARGET}"
