# frozen_string_literal: true

require 'tmpdir'

module Sketchup
  @extensions = []

  def self.register_extension(ext, _load = true)
    @extensions << ext
  end

  def self.extensions
    @extensions
  end

  def self.clear_extensions
    @extensions.clear
  end

  class Model
    attr_reader :selection, :observers

    def initialize
      @selection = Selection.new
      @observers = []
    end

    def add_observer(obs)
      @observers << obs
    end

    def remove_observer(obs)
      @observers.delete(obs)
    end
  end

  class Selection
    attr_reader :observers

    def initialize
      @observers = []
    end

    def add_observer(obs)
      @observers << obs
    end

    def remove_observer(obs)
      @observers.delete(obs)
    end
  end

  class ModelObserver; end
  class SelectionObserver; end

  def self.active_model
    @active_model ||= Model.new
  end

  def self.temp_dir
    Dir.tmpdir
  end

  def self.reset
    @active_model = Model.new
  end
end
