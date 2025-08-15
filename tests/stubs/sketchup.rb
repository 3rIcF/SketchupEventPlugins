# frozen_string_literal: true

# rubocop:disable Style/Documentation, Lint/EmptyClass
module Sketchup
  def self.temp_dir
    Dir.pwd
  end

  def self.active_model
    Model.new
  end

  class Model
    def definitions
      {}
    end

    def selection
      []
    end

    def entities
      []
    end

    def layers
      []
    end

    def add_observer(*); end
  end

  class ModelObserver; end
  class SelectionObserver; end
end

module UI
  def self.menu(_name)
    Menu.new
  end

  class Menu
    def add_submenu(_name)
      self
    end

    def add_item(_name)
      self
    end
  end

  def self.start_timer(*)
    1
  end

  def self.stop_timer(_id); end
end

# rubocop:enable Style/Documentation, Lint/EmptyClass
