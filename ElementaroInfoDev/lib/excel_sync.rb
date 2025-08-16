# frozen_string_literal: true

require 'rubyXL'

module ElementaroInfoDev
  # ExcelSync handles export and import of attribute data
  # to and from Excel (XLSX) files. Export takes scanner
  # results, import reads a workbook into a hash structure,
  # and apply writes imported attributes back to entities.
  class ExcelSync
    HEADER = %w[EntityID Dictionary Key Value].freeze

    # Exports scanner results to an XLSX file.
    # @param results [Array<Hash>] data from Scanner#scan_model
    # @param path [String] destination path for the xlsx file
    def export(results, path)
      workbook = RubyXL::Workbook.new
      worksheet = workbook[0]
      HEADER.each_with_index { |h, i| worksheet.add_cell(0, i, h) }

      row = 1
      results.each do |entry|
        entity_id = entry[:entity].object_id
        entry[:attributes].each do |dict_name, attrs|
          attrs.each do |key, value|
            worksheet.add_cell(row, 0, entity_id)
            worksheet.add_cell(row, 1, dict_name)
            worksheet.add_cell(row, 2, key)
            worksheet.add_cell(row, 3, value)
            row += 1
          end
        end
      end
      workbook.write(path)
    end

    # Imports an XLSX file and returns attribute data.
    # @param path [String] source xlsx file path
    # @return [Hash{Integer=>Hash}]
    def import(path)
      workbook = RubyXL::Parser.parse(path)
      worksheet = workbook[0]
      data = {}
      worksheet.each_with_index do |row, idx|
        next if idx.zero?

        eid = row[0]&.value
        dict = row[1]&.value
        key = row[2]&.value
        value = row[3]&.value
        next if eid.nil? || dict.nil? || key.nil?

        eid = eid.to_i
        data[eid] ||= {}
        data[eid][dict] ||= {}
        data[eid][dict][key] = value
      end
      data
    end

    # Applies imported attribute data to entities in the model.
    # @param model [Object] model responding to `entities`
    # @param data [Hash] data from {#import}
    def apply(model, data)
      entities_by_id = model.entities.to_h { |e| [e.object_id, e] }
      data.each do |eid, dicts|
        entity = entities_by_id[eid]
        next unless entity

        dicts.each do |dict_name, attrs|
          attrs.each do |key, value|
            entity.set_attribute(dict_name, key, value)
          end
        end
      end
    end
  end
end
