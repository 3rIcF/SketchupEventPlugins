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
end
