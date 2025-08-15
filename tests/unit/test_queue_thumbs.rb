# frozen_string_literal: true

require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../test/stubs', __dir__)
require 'sketchup'

module UI
  class HtmlDialog; end
  class Menu
    def add_submenu(_name); self; end
    def add_item(_name); 1; end
  end
  def self.menu(_name)
    Menu.new
  end
end

require_relative '../../ElementaroInfoDev/main'

# rubocop:disable Style/Documentation
class TestQueueThumbs < Minitest::Test
  def setup
    Sketchup.reset
    Sketchup.active_model.define_singleton_method(:definitions) { Hash.new(true) }
    called = false
    UI.singleton_class.class_eval do
      define_method(:start_timer) do |_interval, _repeat, &block|
        block.call
        :tid
      end
      define_method(:stop_timer) do |_id|
        called = true
      end
    end
    @called_ref = -> { called }
    ElementaroInfoDev.define_singleton_method(:thumb_path) { |_n| '' }
    ElementaroInfoDev.define_singleton_method(:ensure_thumb_for) { |_n| nil }
    ElementaroInfoDev.define_singleton_method(:send_rows) { |_rows| nil }
    ElementaroInfoDev.define_singleton_method(:to_js) { |_js| nil }
  end

  def test_timer_stopped
    ElementaroInfoDev.queue_thumbs(['a'], only_missing: false)
    assert @called_ref.call, 'expected stop_timer to be called'
  end
end
# rubocop:enable Style/Documentation
