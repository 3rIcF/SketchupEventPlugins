# frozen_string_literal: true

class SketchupExtension
  attr_reader :name, :path
  attr_accessor :description, :version, :creator

  def initialize(name, path)
    @name = name
    @path = path
  end
end
