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
    if File.file?(file.path)
      RubyXL::Parser.parse(file.path)
    else
      content = open(file.url).read
      RubyXL::Parser.parse_buffer(content)
    end
  end

  def process_worksheet(worksheet, worksheet_index)
    worksheet.each_with_index do |row, index|
      next unless row

      row.cells.each do |cell|
        next unless cell

        unless cell.fill_color =~ /ff0000$/i
          if cell.value
            key_name = generate_key_name(worksheet_index, cell)
            key = Key.for_key(key_name).create_or_update!(
                project:              @asset.project,
                key:                  key_name,
                source_copy:          cell.value,
                skip_readiness_hooks: true,
                ready: false
            )

            @asset.keys << key unless @asset.keys.include?(key)

            key.add_pending_translations(@asset)
          end
        end
      end
    end
  end

  def generate_key_name(worksheet_index, cell)
    file_name = @asset.file_name.gsub(' ', '_').downcase
    hashed_value = Digest::SHA1.hexdigest(cell.value)
    "#{file_name}-sheet#{worksheet_index}-row#{cell.row}-col#{cell.column}-#{hashed_value}"
  end
end
