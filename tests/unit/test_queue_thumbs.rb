$LOAD_PATH.unshift File.expand_path('../stubs', __dir__)
require_relative '../test_helper'
require_relative '../../ElementaroInfo/main'

class TestQueueThumbs < Minitest::Test
  def test_empty_list_does_not_start_timer
    start_called = false
    stop_called = false
    UI.stub(:start_timer, ->(*args, &block) {
      start_called = true
      1
    }) do
      UI.stub(:stop_timer, ->(_id) {
        stop_called = true
      }) do
        ElementaroInfo.stub(:to_js, nil) do
          ElementaroInfo.queue_thumbs([], only_missing: true)
        end
      end
    end
    assert_equal false, start_called, 'timer should not start for empty list'
    assert_equal false, stop_called,  'timer should not stop for empty list'
  end
end
