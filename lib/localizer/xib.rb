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

require 'ios_common'
require 'localizer/copies_ios_resources_without_translations'
require 'importer/xib'

module Localizer

  # Applies localized copy to SVG files.

  class Xib < Base
    include IosCommon

    def self.localizable?(project, key)
      key.source =~ /#{Regexp.escape project.base_rfc5646_locale}\.lproj\/[^\/]+\.xib$/ &&
          key.importer == 'xib'
    end

    def localize(input_file, output_file, locale)
      xml = Nokogiri::XML(input_file.content)

      @translations.each do |translation|
        _, object_id, string_class, array_index = translation.key.original_key.split(/(\d+).([\w\.]+)\[?(\d*)\]?/)
        main_object_id_node                     = xml.xpath("//object[@class = 'IBObjectRecord' and int = #{object_id}]").first

        unless main_object_id_node
          Rails.logger.warn "Failed to find object for ID #{object_id}"
          next
        end

        # Look up the reference ID from the object ID
        reference_id = nil
        main_object_id_node.element_children.each do |child_node|
          if child_node.name == 'reference' && child_node['key'] == 'object'
            reference_id = child_node['ref']
            break
          end
        end

        # Look up the text node
        xpath             = "//object[@id = '#{reference_id}']"
        string_class_path = string_class.split('.')
        string_class_path[0..-2].each do |string_class|
          xpath << "/object[@key = '#{string_class}']"
        end
        xpath << '/' << if string_class == 'IBSegmentTitles'
                          'array'
                        elsif array_index
                          'object'
                        else
                          'string'
                        end << "[@key = '#{string_class_path.last}']"

        text_node = xml.xpath(xpath).first

        raise "Found text node with children, but no array index given" if !text_node.element_children.empty? && array_index.nil?

        if array_index.nil?
          set_text_in_text_node translation.copy, text_node
        else
          set_text_in_text_node translation.copy, text_node.element_children[array_index.to_i]
        end
      end

      output_file.path    = input_file.path.sub("/#{@project.base_rfc5646_locale}.lproj/", "/#{locale.rfc5646}.lproj/")
      output_file.content = xml.to_xml
    end

    private

    include CopiesIosResourcesWithoutTranslations
    def copy_resource?(path, blob, project)
      throw :prune if project.skip_path?(::File.dirname(path[1..-1]), Importer::Xib)
      path =~ /#{Regexp.escape(project.base_rfc5646_locale)}\.lproj\/[^\/]+\.xib$/ &&
          Nokogiri::XML(blob.contents).root.name == 'archive'
    end

    def set_text_in_text_node(text, text_node)
      raise "Cannot set string content in node if node has children" unless text_node.element_children.empty?
      raise "Cannot set string content in node if node is not of type 'string'" unless text_node.name == 'string'

      # Does this string require base64 encoding?
      if text.include?("\n")
        # The base 64 string may have different line breaks than the existing
        # string, but they don't matter. Try to detect this to avoid unnecessary
        # file changes
        return if Base64.decode64(padded_base64(text_node.content)).force_encoding('UTF-8') == text

        text_node['type'] = 'base64-UTF8'
        text              = unpadded_base64(Base64.encode64(text))
      else
        text_node.remove_attribute 'type'
      end

      text_node.content = text
    end
  end
end
