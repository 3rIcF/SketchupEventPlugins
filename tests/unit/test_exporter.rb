# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'

$LOAD_PATH.unshift File.expand_path('../../test/stubs', __dir__)
require 'sketchup'

# Minimal stubs for the SketchUp UI module
module UI
  class << self
    def menu(_)
      Menu.new
    end
  end

  # Minimal menu stub
  class Menu
    def add_submenu(_)
      self
    end

    def add_item(*)
      self
    end
  end
end

require_relative '../../ElementaroInfoDev/main'

# Tests for CSV and JSON export formats
class TestExporter < Minitest::Test
  ROW = {
    row_id: 1,
    parent_key: nil,
    entity_type: 'ComponentInstance',
    entity_kind: 'Component',
    level: 0,
    path: 'Root',
    parent_display: '',
    definition_name: 'RootComp',
    instance_name: '',
    tag: '',
    sku: '',
    variant: '',
    unit: '',
    price_eur: nil,
    owner: '',
    supplier: '',
    article_number: '',
    description: '',
    def_total_qty: nil,
    def_tag_qty: nil,
    def_total_price_eur: nil,
    def_tag_price_eur: nil,
    thumb: '',
    pid: 1
  }.freeze

  def setup
    @rows = [
      ROW,
      ROW.merge(
        row_id: 2,
        parent_key: 1,
        path: 'Root/Child',
        parent_display: 'RootComp',
        definition_name: 'ChildComp',
        pid: 2
      )
    ]
  end

  def test_csv_export_field_count_and_encoding
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'out.csv')
      ElementaroInfoDev.write_csv(path, @rows)
      data = File.binread(path)
      assert_equal [0xEF, 0xBB, 0xBF], data.bytes[0, 3], 'CSV should start with UTF-8 BOM'
      lines = data.force_encoding('UTF-8').split("\n")
      assert_equal 3, lines.size
      lines.each { |line| assert_equal 24, line.split(';').size }
    end
  end

  def test_json_export_field_count_and_encoding
    json = JSON.pretty_generate(@rows)
    assert_equal Encoding::UTF_8, json.encoding
    parsed = JSON.parse(json)
    assert_equal 2, parsed.size
    assert_equal 24, parsed.first.keys.size
  end
end
