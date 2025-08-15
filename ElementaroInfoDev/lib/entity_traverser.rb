# frozen_string_literal: true

module ElementaroInfoDev
  # Simple depth-first traversal for SketchUp-like entity trees.
  # It yields each entity so callers can collect data without worrying
  # about the hierarchy structure.
  class EntityTraverser
    def traverse(model, &)
      walk(model.entities.to_a, &)
    end

    private

    def walk(entities, &)
      entities.each do |entity|
        yield entity
        children = child_entities(entity)
        walk(children, &) unless children.empty?
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
