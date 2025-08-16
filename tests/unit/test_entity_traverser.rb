# frozen_string_literal: true

# rubocop:disable Style/Documentation

require 'minitest/autorun'
require_relative '../../ElementaroInfoDev/lib/entity_traverser'

# Entities collection that forbids conversion to arrays to ensure
# traverser iterates directly without allocations.
class StrictEntities
  include Enumerable

  def initialize(list)
    @list = list
  end

  def each(&block)
    @list.each(&block)
  end

  def to_a
    raise 'to_a should not be called'
  end
end

class DummyEntity
  attr_accessor :children

  def initialize(children = [])
    @children = children
  end

  def definition
    self
  end

  def entities
    StrictEntities.new(@children)
  end
end

class TraverserModel
  attr_reader :entities

  def initialize(entities)
    @entities = StrictEntities.new(entities)
  end
end

class TestEntityTraverser < Minitest::Test
  def setup
    @traverser = ElementaroInfoDev::EntityTraverser.new
  end

  def test_traverses_all_entities_without_to_a
    child = DummyEntity.new
    parent = DummyEntity.new([child])
    model = TraverserModel.new([parent])

    result = []
    @traverser.traverse(model) { |e| result << e }

    assert_equal [parent, child], result
  end

  def test_handles_cycles
    a = DummyEntity.new
    b = DummyEntity.new([a])
    a.children << b
    model = TraverserModel.new([a])

    result = []
    @traverser.traverse(model) { |e| result << e }

    assert_equal [a, b], result
  end
end
# rubocop:enable Style/Documentation
