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

require 'localizer/copies_ios_resources_without_translations'
require 'importer/storyboard'

module Localizer

  # Applies localized copy to Apple Storyboard files.

  class Storyboard < Base
    def self.localizable?(project, key)
      key.source =~ /#{Regexp.escape project.base_rfc5646_locale}\.lproj\/[^\/]+\.storyboard$/
    end

    def localize(input_file, output_file, locale)
      xml = Nokogiri::XML(input_file.content)

      @translations.each do |translation|
        key_components = translation.key.original_key.split('.')
        object_id      = key_components.first
        xpath          = "//*[@id = '#{object_id}']"
        object_node    = xml.xpath(xpath)[0]

        unless object_node
          Rails.logger.warn "Skipping translation #{translation.key.original_key} because object node is missing"
          next
        end

        text_node = object_node
        key_path  = key_components[1..-2]

        key_path.each do |key_component|
          break unless text_node

          # Does this key component have an index or "key" attribute?
          match, entity, array_index = key_component.split(/(\w+)\[?(\w*)\]?/)

          if array_index.nil?
            # No subcontext
            matching_child_node = nil
            text_node.element_children.each do |child_node|
              if child_node.name == entity
                matching_child_node = child_node
                break
              end
            end

            if matching_child_node.nil?
              Rails.logger.warn "Failed to apply string because no child item was found of type #{entity}: #{translation.key.original_key}"
            end
            text_node = matching_child_node
          elsif array_index =~ /^\d*$/
            # Array index
            text_node = text_node.element_children[array_index.to_i]
            unless text_node.name == entity
              warn "Failed to apply string because item at child #{array_index} of #{object_id} is not a #{entity}: #{translation.key.original_key}"
              text_node = nil
            end
          else
            # Key attribute
            entity_key          = array_index
            matching_child_node = nil
            text_node.element_children.each do |child_node|
              if child_node.name == entity && child_node['key'] == entity_key
                matching_child_node = child_node
                break
              end
            end

            if matching_child_node.nil?
              Rails.logger.warn "Failed to apply string because no child item was found of type #{entity} with a key of #{entity_key}: #{translation.key.original_key}"
            end
            text_node = matching_child_node
          end
        end

        next unless text_node

        string_class = key_components.last

        text_node.xpath("string[@key = '#{string_class}']").each(&:remove)

        # multiline strings become <string> child nodes
        if translation.copy.include?("\n")
          text_node.remove_attribute string_class
          string_node         = Nokogiri::XML::Node.new('string', xml)
          string_node['key']  = string_class
          string_node.content = translation.copy
          text_node.add_child string_node
        else
          text_node[string_class] = translation.copy
        end
      end

      output_file.path    = input_file.path.sub("/#{@project.base_rfc5646_locale}.lproj/", "/#{locale.rfc5646}.lproj/")
      output_file.content = xml.to_xml
    end

    private

    include CopiesIosResourcesWithoutTranslations
    def copy_resource?(path, blob, project)
      throw :prune if project.skip_path?(::File.dirname(path[1..-1]), Importer::Storyboard)
      path =~ /#{Regexp.escape(project.base_rfc5646_locale)}\.lproj\/[^\/]+\.storyboard$/
    end
  end
end
