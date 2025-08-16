# frozen_string_literal: true

# rubocop:disable Style/Documentation

require 'minitest/autorun'
require_relative '../../ElementaroInfoDev/lib/scanner'

# Stubs mimicking minimal SketchUp entities for scanner tests.
class MockAttributeDictionary
  attr_reader :name

  def initialize(name, attrs)
    @name = name
    @attrs = attrs
  end

  def each_pair(&)
    @attrs.each_pair(&)
  end
end

class MockDefinition
  attr_reader :name, :entities

  def initialize(name, entities = [])
    @name = name
    @entities = MockEntities.new(entities)
  end
end

class MockEntity
  attr_reader :definition

  def initialize(name, dicts: {}, children: [])
    @definition = MockDefinition.new(name, children)
    @dicts = dicts.map { |n, h| MockAttributeDictionary.new(n, h) }
  end

  def attribute_dictionaries
    return nil if @dicts.empty?

    @dicts
  end
end

class MockEntities
  def initialize(list)
    @list = list
  end

  def to_a
    @list
  end
end

class MockModel
  attr_reader :entities

  def initialize(entities)
    @entities = MockEntities.new(entities)
  end
end

class TestScanner < Minitest::Test
  def setup
    @scanner = ElementaroInfoDev::Scanner.new
  end

  def test_can_create_scanner_instance
    assert_instance_of ElementaroInfoDev::Scanner, @scanner
  end

  def test_scan_collects_attributes_from_root_entities
    entity = MockEntity.new('Root', dicts: { 'dict' => { 'sku' => '123' } })
    model = MockModel.new([entity])
    results = @scanner.scan_model(model)
    assert_equal 1, results.size
    assert_equal '123', results.first[:attributes]['dict']['sku']
  end

  def test_scan_traverses_nested_entities
    child = MockEntity.new('Child', dicts: { 'info' => { 'val' => 1 } })
    parent = MockEntity.new('Parent', children: [child])
    model = MockModel.new([parent])
    results = @scanner.scan_model(model)
    assert_equal 2, results.size
    child_attrs = results.last[:attributes]['info']
    assert_equal 1, child_attrs['val']
  end

  def test_scan_avoids_cycles
    a = MockEntity.new('A')
    b = MockEntity.new('B')
    a.definition.entities.instance_variable_set(:@list, [b])
    b.definition.entities.instance_variable_set(:@list, [a])
    model = MockModel.new([a])

    results = @scanner.scan_model(model)
    names = results.map { |r| r[:entity].definition.name }
    assert_equal %w[A B], names
  end
end
# rubocop:enable Style/Documentation
