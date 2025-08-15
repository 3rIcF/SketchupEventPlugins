# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

$LOAD_PATH.unshift File.expand_path('../stubs', __dir__)
require 'sketchup'

module UI
  class HtmlDialog
    def initialize(**_opts)
      @visible = false
      @on_closed = nil
    end

    def add_action_callback(*); end
    def set_file(_path); end
    def set_html(_html); end

    def set_on_closed(&block)
      @on_closed = block
    end

    def show
      @visible = true
    end

    def visible?
      @visible
    end

    def execute_script(_script); end

    def close
      @visible = false
      @on_closed&.call
    end
  end

  class Menu
    def add_submenu(_name)
      self
    end
    def add_item(_name); end
  end

  def self.menu(_name)
    Menu.new
  end
end
require_relative '../../ElementaroInfoDev/main'

class TestDetachObservers < Minitest::Test
  def setup
    Sketchup.reset
  end

  def test_observers_detached_after_close
    ElementaroInfoDev.show_panel
    model = Sketchup.active_model

    assert_equal 1, model.observers.length
    assert_equal 1, model.selection.observers.length

    ElementaroInfoDev.instance_variable_get(:@dlg).close

    assert_empty model.observers
    assert_empty model.selection.observers
  end
end

