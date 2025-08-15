# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../stubs', __dir__)
require_relative '../test_helper'
require_relative '../../ElementaroInfo/main'

# Tests for ElementaroInfo.queue_thumbs
class TestQueueThumbs < Minitest::Test
  def test_empty_list_does_not_start_timer
    start_called = false
    stop_called = false
    UI.stub(:start_timer, lambda do |_time, _repeat, &_block|
      start_called = true
      1
    end) do
      UI.stub(:stop_timer, lambda do |_id|
        stop_called = true
      end) do
        ElementaroInfo.stub(:to_js, nil) do
          ElementaroInfo.queue_thumbs([], only_missing: true)
        end
      end
    end
    refute start_called, 'timer should not start for empty list'
    refute stop_called,  'timer should not stop for empty list'
  end
end
