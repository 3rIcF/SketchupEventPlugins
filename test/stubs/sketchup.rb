# frozen_string_literal: true

require 'tmpdir'

# Teststubs für SketchUp-API.
module Sketchup
  @extensions = []

  # Registriert eine Erweiterung in der Testumgebung.
  def self.register_extension(ext, _load = true) # rubocop:disable Style/OptionalBooleanParameter
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

  # rubocop:disable Lint/EmptyClass
  class ModelObserver; end
  class SelectionObserver; end
  # rubocop:enable Lint/EmptyClass

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
