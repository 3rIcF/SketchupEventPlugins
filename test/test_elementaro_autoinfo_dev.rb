require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('stubs', __dir__)
require 'sketchup'
require 'extensions'

class ElementaroAutoinfoDevTest < Minitest::Test
  def setup
    Sketchup.clear_extensions
  end

  def test_extension_registration
    load File.expand_path('../elementaro_autoinfo_dev.rb', __dir__)
    assert_equal 1, Sketchup.extensions.length
    ext = Sketchup.extensions.first
    assert_equal 'Elementaro AutoInfo Dev', ext.name
    assert_equal '2.3.0', ext.version
    assert_equal 'Elementaro', ext.creator
  end
end
