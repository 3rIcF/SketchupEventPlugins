# frozen_string_literal: true

module ElementaroInfoDev
  # Scanner traverses models in chunks and reports progress
  class Scanner
    CHUNK_SIZE = 3000

    # Yields slices of entities along with progress percentage
    # @param model [Sketchup::Model] the model to scan
    # @yield [slice, percent] Gives a slice of entities and progress
    def scan_model(model)
      ents = model.entities.to_a
      return enum_for(:scan_model, model) unless block_given?

      total = ents.length
      processed = 0
      ents.each_slice(CHUNK_SIZE) do |slice|
        processed += slice.length
        percent = total.zero? ? 100 : ((processed.to_f / total) * 100).round
        yield slice, percent
      end
    end
  end
end
