# frozen_string_literal: true

require 'set'

module ElementaroInfoDev
  # Simple depth-first traversal for SketchUp-like entity trees.
  # It yields each entity so callers can collect data without worrying
  # about the hierarchy structure. Cyclical references are guarded so
  # traversal terminates even for incorrectly linked models.
  class EntityTraverser
    def traverse(model, &block)
      walk(model.entities.to_a, Set.new, &block)
    end

    private

    def walk(entities, visited, &block)
      entities.each do |entity|
        oid = entity.object_id
        next if visited.include?(oid)

        visited.add(oid)
        yield entity

        children = child_entities(entity)
        walk(children, visited, &block) unless children.empty?
      end
    end

    def child_entities(entity)
      if entity.respond_to?(:definition) && entity.definition.respond_to?(:entities)
        entity.definition.entities.to_a
      elsif entity.respond_to?(:entities)
        entity.entities.to_a
      else
        []
      end
    end
  end
end
