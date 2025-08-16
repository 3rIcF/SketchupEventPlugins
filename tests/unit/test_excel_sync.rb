# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'rubyXL'
require_relative '../../ElementaroInfoDev/lib/scanner'
require_relative '../../ElementaroInfoDev/lib/excel_sync'

# Minimal dictionary stub to emulate SketchUp attribute dictionaries
class StubDictionary < Hash
  attr_reader :name

  def initialize(name, attrs = {})
    super()
    @name = name
    attrs.each { |k, v| self[k.to_s] = v }
  end

  def each_pair(&)
    each(&)
  end
end

# Simple entity stub with attribute dictionary support
class StubEntity
  def initialize(dicts = {})
    @dicts = dicts.map { |name, attrs| StubDictionary.new(name, attrs) }
  end

  def attribute_dictionaries
    @dicts
  end

  def set_attribute(dict_name, key, value)
    dictionary = @dicts.find { |d| d.name == dict_name }
    unless dictionary
      dictionary = StubDictionary.new(dict_name)
      @dicts << dictionary
    end
    dictionary.store(key.to_s, value)
  end

  def get_attribute(dict_name, key)
    dictionary = @dicts.find { |d| d.name == dict_name }
    dictionary&.[](key.to_s)
  end
end

# Simple model wrapper providing entities collection
class StubModel
  attr_reader :entities

  def initialize(entities)
    @entities = entities
  end
end

# Tests for ElementaroInfoDev::ExcelSync
class ExcelSyncTest < Minitest::Test
  def setup
    @entity = StubEntity.new('elementaro' => { 'foo' => '1' })
    @model = StubModel.new([@entity])
    @scanner = ElementaroInfoDev::Scanner.new
    @excel = ElementaroInfoDev::ExcelSync.new
  end

  def test_export_import_and_apply
    results = @scanner.scan_model(@model)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'sync.xlsx')
      @excel.export(results, path)

      wb = RubyXL::Parser.parse(path)
      sheet = wb[0]
      sheet[1][3].raw_value = '2'
      wb.write(path)

      data = @excel.import(path)
      @excel.apply(@model, data)

      assert_equal '2', @entity.get_attribute('elementaro', 'foo')
    end
  end
end
