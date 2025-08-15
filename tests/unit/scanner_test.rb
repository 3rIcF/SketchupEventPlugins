# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../ElementaroInfoDev/lib/scanner'

# Unit tests for the Scanner placeholder class
class TestScanner < Minitest::Test
  def test_can_create_scanner_instance
    scanner = ElementaroInfoDev::Scanner.new
    assert_instance_of ElementaroInfoDev::Scanner, scanner
  end
end
