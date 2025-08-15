#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic local sanity checks for the project.

abort('Unit test directory not found: tests/unit') unless Dir.exist?('tests/unit')
abort('UI directory not found: ElementaroInfoDev/ui') unless Dir.exist?('ElementaroInfoDev/ui')
abort('Build script not found: tools/build.rb') unless File.exist?('tools/build.rb')

TEST_FILES = Dir['tests/unit/test_*.rb']
abort('No unit tests found in tests/unit') if TEST_FILES.empty?
HTML_FILES = Dir['ElementaroInfoDev/ui/*.html']
abort('No HTML files found in ElementaroInfoDev/ui') if HTML_FILES.empty?

def run(name, cmd, abort_on_fail: true)
  puts "==> #{name}: #{cmd}"
  ok = system(cmd)
  return if ok || !abort_on_fail
  abort("#{name} failed")
end

if system('command -v rubocop >/dev/null 2>&1')
  run('rubocop', 'rubocop', abort_on_fail: false)
else
  warn('rubocop command not found: skipping Ruby lint')
end

TEST_FILES.each do |file|
  run(File.basename(file), "ruby -Itests #{file}")
end

run('build', 'ruby tools/build.rb')

if system('command -v npx >/dev/null 2>&1')
  run('htmlhint', "npx --yes htmlhint #{HTML_FILES.join(' ')}")
else
  warn('npx command not found: skipping HTML lint')
end

puts 'All smoke checks passed.'
