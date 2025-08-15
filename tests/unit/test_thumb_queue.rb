# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

$LOADED_FEATURES << 'sketchup.rb'

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
end

module Sketchup
  class Model
    attr_reader :definitions

    def initialize(names)
      @definitions = names.each_with_object({}) { |n, h| h[n] = Object.new }
    end
  end

  class ModelObserver; end
  class SelectionObserver; end

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

require_relative '../../ElementaroInfoDev/main'

class TestThumbQueue < Minitest::Test
  def setup
    Sketchup.active_model = Sketchup::Model.new(%w[A B C D E])
    ElementaroInfoDev.instance_variable_set(:@thumb_timer, nil)
    ElementaroInfoDev.define_singleton_method(:ensure_thumb_for) { |_n| }
    ElementaroInfoDev.define_singleton_method(:send_rows) { |_r| }
    ElementaroInfoDev.define_singleton_method(:to_js) { |_js| }
  end

  def test_queue_captures_and_stops_previous_timer
    ElementaroInfoDev.queue_thumbs(%w[A B C D E], only_missing: false)
    first = ElementaroInfoDev.instance_variable_get(:@thumb_timer)
    refute first.stopped?
    ElementaroInfoDev.queue_thumbs(%w[A], only_missing: false)
    assert first.stopped?
  end
end
