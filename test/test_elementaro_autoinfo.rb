# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'stubs/sketchup'
require_relative 'stubs/extensions'

class ElementaroAutoinfoDevTest < Minitest::Test
  STUB_DIR = File.expand_path('stubs', __dir__)

  def setup
    Sketchup.clear_extensions
  end

  def test_extension_registration
    $LOAD_PATH.unshift STUB_DIR
    load File.expand_path('../elementaro_autoinfo_dev.rb', __dir__)
    $LOAD_PATH.delete(STUB_DIR)
    assert_equal 1, Sketchup.extensions.length
    ext = Sketchup.extensions.first
    assert_equal 'Elementaro AutoInfo Dev', ext.name
    assert_equal '2.3.0', ext.version
    assert_equal 'Elementaro', ext.creator
  end
end
