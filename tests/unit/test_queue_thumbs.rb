# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/SingleLineMethods, Lint/EmptyClass

require 'minitest/autorun'
require 'tmpdir'

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
    TimerStub.new(repeat, block)
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
    def initialize(*) end
    def add_action_callback(*) end
    def set_file(*) end
    def set_html(*) end
    def show; end
    def execute_script(*) end
    def visible?; false; end
    def close; end
  end
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

  class DefinitionsStub
    def [](name)
      Object.new if name
    end
  end

  class ModelStub
    def definitions
      DefinitionsStub.new
    end
  end

  def self.active_model
    @active_model ||= ModelStub.new
  end

  def self.temp_dir
    Dir.tmpdir
  end
end

require_relative '../../ElementaroInfoDev/main'

ElementaroInfoDev.define_singleton_method(:to_js) { |_js| nil }
ElementaroInfoDev.define_singleton_method(:send_rows) { |_rows| nil }
ElementaroInfoDev.define_singleton_method(:ensure_thumb_for) { |_n| nil }
ElementaroInfoDev.define_singleton_method(:thumb_path) { |_n| '' }

class TestQueueThumbs < Minitest::Test
  def setup
    ElementaroInfoDev.instance_variable_set(:@thumb_timer, nil)
  end

  def test_stores_and_clears_timer
    ElementaroInfoDev.queue_thumbs(%w[a], only_missing: true)
    timer = ElementaroInfoDev.instance_variable_get(:@thumb_timer)
    refute_nil timer
    refute timer.stopped?

    timer.trigger
    assert timer.stopped?
    assert_nil ElementaroInfoDev.instance_variable_get(:@thumb_timer)
  end
end
# rubocop:enable Style/Documentation, Style/SingleLineMethods, Lint/EmptyClass
