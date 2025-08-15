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

  class Entities
    def initialize(list = [])
      @list = list
    end

    def to_a
      @list
    end
  end

  class Selection < Entities
    attr_reader :observers

    def initialize(list = [])
      super(list)
      @observers = []
    end

    def add_observer(obs)
      @observers << obs
    end

    def remove_observer(obs)
      @observers.delete(obs)
    end
  end

  class Layer
    attr_accessor :visible
    attr_reader :name

    def initialize(name = '')
      @name = name
      @visible = true
    end

    def visible?
      @visible
    end
  end

  class Model
    attr_reader :entities, :selection, :layers, :observers

    def initialize(entities = [])
      @entities = Entities.new(entities)
      @selection = Selection.new([])
      @layers = []
      @observers = []
    end

    def add_observer(obs)
      @observers << obs
    end

    def remove_observer(obs)
      @observers.delete(obs)
    end
  end

  class ComponentInstance; end
  class Group < ComponentInstance; end
  class ModelObserver; end
  class SelectionObserver; end

  def self.active_model
    @active_model ||= Model.new
  end

  def self.active_model=(model)
    @active_model = model
  end

  def self.temp_dir
    Dir.tmpdir
  end

  def self.reset
    @active_model = Model.new
  end
end

