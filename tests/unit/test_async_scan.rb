# frozen_string_literal: true
require 'minitest/autorun'
require 'tmpdir'
require 'ostruct'

$LOADED_FEATURES << 'sketchup.rb'

# --- Stubs for SketchUp API ---
module UI
  class TimerStub
    def initialize(repeat, block)
      @repeat = repeat
      @block = block
      @stopped = false
    end

    def trigger
      return if @stopped
      @block.call(self)
      @stopped = true unless @repeat
    end

    def stop
      @stopped = true
    end

    def stopped?
      @stopped
    end
  end

  def self.start_timer(_interval, repeat, &block)
    timer = TimerStub.new(repeat, block)
    timer.trigger
    timer
  end

  class MenuStub
    def add_submenu(_name)
      self
    end

    def add_item(_name)
      1
    end
  end

  def self.menu(_name)
    MenuStub.new
  end

  class HtmlDialog
    def initialize(*) ; end
    def add_action_callback(*) ; end
    def set_file(*) ; end
    def set_html(*) ; end
    def show ; end
    def execute_script(*) ; end
    def visible?; false; end
    def close; end
  end
end

module Geom
  Z_AXIS = [0, 0, 1]
end

module Sketchup
  class ComponentInstance; end
  class Group < ComponentInstance; end
  class ModelObserver; end
  class SelectionObserver; end
  class Layer
    def visible?; true; end
    def name; ''; end
  end
  class Entities
    def initialize(list)
      @list = list
    end

    def to_a
      @list
    end
  end
  class Model
    attr_reader :entities, :selection, :layers

    def initialize(entities)
      @entities = Entities.new(entities)
      @selection = Entities.new([])
      @layers = []
    end
  end

  def self.active_model
    @model
  end

  def self.active_model=(model)
    @model = model
  end

  def self.temp_dir
    Dir.tmpdir
  end
end

class MockDefinition
  attr_reader :name, :entities

  def initialize(name)
    @name = name
    @entities = Sketchup::Entities.new([])
  end

  def attribute_dictionaries
    nil
  end
end

class MockEntity < Sketchup::ComponentInstance
  attr_reader :persistent_id

  def initialize(id)
    @persistent_id = id
    @definition = MockDefinition.new("Def#{id}")
    @layer = Sketchup::Layer.new
  end

  def hidden?
    false
  end

  def layer
    @layer
  end

  def definition
    @definition
  end

  def name
    "Inst#{@persistent_id}"
  end

  def attribute_dictionaries
    nil
  end
end

require_relative '../../ElementaroInfoDev/main'

ElementaroInfoDev.singleton_class.class_eval do
  attr_accessor :js_calls
end

ElementaroInfoDev.define_singleton_method(:to_js) do |js|
  (self.js_calls ||= []) << js
end
ElementaroInfoDev.define_singleton_method(:send_rows) { |_rows| }
ElementaroInfoDev.define_singleton_method(:send_defs_summary) { }

class TestAsyncScan < Minitest::Test
  def setup
    ElementaroInfoDev.js_calls = []
    ElementaroInfoDev.send(:remove_const, :CHUNK_SIZE)
    ElementaroInfoDev.const_set(:CHUNK_SIZE, 2)
    ents = (1..5).map { |i| MockEntity.new(i) }
    Sketchup.active_model = Sketchup::Model.new(ents)
  end

  def test_scan_in_chunks
    ElementaroInfoDev.scan_async(ElementaroInfoDev.default_opts)
    timer = ElementaroInfoDev.instance_variable_get(:@scan_timer)

    progress = ElementaroInfoDev.js_calls.grep(/EA\.scanProgress\((\d+)\)/)
    assert_equal ["EA.scanProgress(0)", "EA.scanProgress(40)"] , progress

    timer.trigger
    progress = ElementaroInfoDev.js_calls.grep(/EA\.scanProgress\((\d+)\)/)
    assert_equal ["EA.scanProgress(0)", "EA.scanProgress(40)", "EA.scanProgress(80)"] , progress

    timer.trigger
    progress = ElementaroInfoDev.js_calls.grep(/EA\.scanProgress\((\d+)\)/)
    assert_equal ["EA.scanProgress(0)", "EA.scanProgress(40)", "EA.scanProgress(80)", "EA.scanProgress(100)"] , progress
    assert timer.stopped?
  end

  def test_cancel_scan
    ElementaroInfoDev.scan_async(ElementaroInfoDev.default_opts)
    ElementaroInfoDev.cancel_scan!
    timer = ElementaroInfoDev.instance_variable_get(:@scan_timer)
    timer.trigger
    assert timer.stopped?
    progress = ElementaroInfoDev.js_calls.grep(/EA\.scanProgress\((\d+)\)/)
    last = progress.last[/\d+/].to_i
    assert last < 100
  end
end
