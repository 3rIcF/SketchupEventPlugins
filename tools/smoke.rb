#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

CHECKS = [
  %w[rubocop rubocop],
  ['tests', 'ruby -Itests tests/unit/test_scanner.rb']
].freeze

CHECKS.each do |name, cmd|
  puts "==> #{name}: #{cmd}"
  system(cmd) || abort("#{name} failed")
end

puts 'All smoke checks passed.'
