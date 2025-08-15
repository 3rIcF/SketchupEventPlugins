#!/usr/bin/env ruby
# frozen_string_literal: true

CHECKS = [
  ['rubocop', 'rubocop'],
  [
    'tests',
    "ruby -Itests -e \"Dir.glob('tests/unit/**/*_test.rb').sort.each { |f| require f }\""
  ]
].freeze

OPTIONAL_CHECKS = [
  [
    'htmlhint',
    'npx --no-install htmlhint ElementaroInfoDev/ui/**/*.html',
    'npx --no-install htmlhint --version'
  ],
  [
    'stylelint',
    'npx --no-install stylelint ElementaroInfoDev/ui/**/*.css',
    'npx --no-install stylelint --version'
  ]
].freeze

def run(name, cmd)
  puts "==> #{name}: #{cmd}"
  system(cmd) || abort("#{name} failed")
end

def run_optional(name, cmd, detect_cmd)
  if system(detect_cmd, out: File::NULL, err: File::NULL)
    run(name, cmd)
  else
    warn "==> #{name}: skipped (tool not installed)"
  end
end

CHECKS.each { |name, cmd| run(name, cmd) }
OPTIONAL_CHECKS.each { |name, cmd, detect| run_optional(name, cmd, detect) }

puts 'All smoke checks passed.'
