# Copyright 2018 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

class AssetXlsxImporter
  # @param [Fixnum] asset_id The ID of a Asset
  def import(asset_id)
    @asset = Asset.find(asset_id)
    @workbook = get_workbook(@asset.file)
    @workbook.worksheets.each_with_index do |worksheet, index|
      process_worksheet(worksheet, index)
    end
  end

  def get_workbook(file)
    return RubyXL::Parser.parse file.path if file.exists?
  end

  def process_worksheet(worksheet, worksheet_index)
    worksheet.each_with_index do |row, index|
      next unless row

      row.cells.each do |cell|
        next unless cell

        unless cell.fill_color =~ /ff0000$/i
          key_name = generate_key_name(worksheet_index, cell)
          if cell.value
            key = @asset.keys.for_key(key_name).create_or_update!(
                project:              @asset.project,
                key:                  key_name,
                source_copy:          cell.value,
                skip_readiness_hooks: true,
                ready: false
            )
            key.add_pending_translations
          end
        end
      end
    end
  end

  def generate_key_name(worksheet_index, cell)
    file_name = @asset.file_name.gsub(' ', '_').downcase
    "#{@asset.id}-#{file_name}-sheet#{worksheet_index}-row#{cell.row}-col#{cell.column}"
  end
end
