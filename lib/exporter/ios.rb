# Copyright 2014 Square Inc.
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

require 'exporter/multifile'

module Exporter

  # Exports the translated strings of a Commit to a .tar file (containing
  # .strings files) for use with iOS or Mac OS X. This tarball should be
  # extracted to the project's root directory.

  class Ios < Base
    include Multifile

    def export_files(receiver, *locales)
      exporter = Exporter::Strings.new(@commit)

      locales.each do |locale|
        Translation.in_commit(@commit).includes(:key).
            where(rfc5646_locale: locale.rfc5646, translated: true).
            group_by { |t| t.key.source }.each do |source, translations|
          unless source
            Rails.logger.warn "[Exporter::Ios] Skipping #{translations.size} translations with no source"
            next
          end

          # Only export .strings files
          next unless source.end_with?('.strings')

          stream = StringIO.new
          # write the BOM
          stream.putc 0xFF
          stream.putc 0xFE
          translations.sort_by { |t| t.key.key }.each do |translation|
            exporter.export_translation stream, translation
          end

          # build new path from source
          path = source.gsub(/^\//, '')
          path = path.split('/')
          path.each_with_index { |element, index| path[index] = "#{locale.rfc5646}.lproj" if element == "#{@commit.project.base_rfc5646_locale}.lproj" }
          path = path.join('/')

          receiver.add_file path, stream.string.force_encoding('BINARY')
        end
      end
    end

    def self.request_format() :ios end
  end
end
