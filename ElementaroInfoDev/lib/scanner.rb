# frozen_string_literal: true

require_relative 'entity_traverser'

module ElementaroInfoDev
  # Scanner collects attribute data from SketchUp-like models.
  # It walks through all entities and gathers attribute dictionaries
  # for each entity. Results are returned as an array of hashes with
  # `:entity` and `:attributes` keys.
  class Scanner
    def initialize(traverser = EntityTraverser.new)
      @traverser = traverser
      @attr_cache = {}.compare_by_identity
    end

    # Scans the given SketchUp model for entities and their attributes.
    # @param model [Object] Model-like object responding to `entities`.
    # @return [Array<Hash>] Array of results per entity.
    def scan_model(model)
      results = []
      @traverser.traverse(model) do |entity|
        results << { entity: entity, attributes: collect_attributes(entity) }
      end
      results
    end

    private

    def collect_attributes(entity)
      @attr_cache[entity] ||= begin
        dicts = entity.attribute_dictionaries if entity.respond_to?(:attribute_dictionaries)
        if dicts
          attrs = {}
          dicts.each do |dict|
            dict_name = dict.respond_to?(:name) ? dict.name.to_s : 'default'
            attrs[dict_name] = {}
            dict.each_pair { |k, v| attrs[dict_name][k.to_s] = v }
          end
          attrs
        else
          {}
        end
      end
    end
  end
end
