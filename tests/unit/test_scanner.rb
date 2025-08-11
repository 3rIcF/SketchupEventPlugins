require 'minitest/autorun'
require_relative '../../ElementaroInfo/lib/scanner'

class TestScanner < Minitest::Test
  def test_can_create_scanner_instance
    scanner = ElementaroInfo::Scanner.new
    assert_instance_of ElementaroInfo::Scanner, scanner
  end
end
