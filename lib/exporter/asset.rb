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

module Exporter
  # Exports the translated strings of an Asset to a json representation.

  class Asset
    # Initializes the importer with the given `asset`.
    # Caches the sorted keys which include their respective translations.
    # Caches the sorted translations by locale.

    def initialize(asset)
      @asset = asset
    end

    def export(locales = @asset.required_locales)
      raise InputError.new("No Locale(s) Inputted") unless locales.present?

      if locales.is_a? String
        locales = locales.split(",").map(&:strip).map do |rfc5646|
          locale = Locale.from_rfc5646(rfc5646)
          raise InputError.new("Locale '#{rfc5646}' could not be found.") unless locale
          locale
        end
      end

      # check if all requested locales are among the required locales
      locales.each do |locale|
        raise InputError.new("Inputted locale '#{locale.rfc5646}' is not one of the required locales for this asset.") unless @asset.required_locales.include?(locale)
      end

      raise NotReadyError unless @asset.ready?

      compressed_filestream = Zip::OutputStream.write_buffer do |zos|
        locales.each do |locale|
          # for each locale, generate an excel file from the source copy (Paperclip)
          xlsx_file = generate_xlsx(@asset, locale)
          zos.put_next_entry "#{@asset.file_name}-#{locale.rfc5646.upcase}.xlsx"
          zos.print(xlsx_file.string)
        end
      end
      compressed_filestream.rewind

      return compressed_filestream
    end

    # ======== START ERRORS ==============================================================================================
    class Error < StandardError; end
    class NotReadyError < Error; end # Raised when an Asset is not marked as ready.
    class MissingTranslation < Error; end # Raised when a Translation was missing during export.
    class InputError < Error; end
    # ======== END ERRORS ================================================================================================

private
    def generate_xlsx(asset, locale)
      workbook = RubyXL::Parser.parse(asset.file.path)

      asset.translations.in_locale(locale).each do |translation|
        cell_info = translation.key.original_key.scan(/sheet(\d+)-row(\d+)-col(\d+)/).flatten
        sheet = cell_info[0].to_i
        row = cell_info[1].to_i
        col = cell_info[2].to_i
        worksheet = workbook[sheet]
        worksheet[row][col].change_contents(translation.copy, worksheet[row][col].formula)
      end
      workbook.stream
    end
  end
end
