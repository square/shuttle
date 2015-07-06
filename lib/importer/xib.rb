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

module Importer

  # Parses translatable strings from Apple Xib files (below version 3),
  # generated by Interface Builder or versions of Xcode below 5.

  class Xib < Base
    include IosCommon

    # Xpaths of strings to extract.
    XPATHS = [
        "//string[@key = 'IBPlaceholder']",
        "//string[@key = 'IBPrompt']",
        "//object[@key = 'IBScopeButtonTitles']",
        "//array[@key = 'IBSegmentTitles']",
        "//string[@key = 'IBText']",
        "//string[@key = 'IBUIAccessibilityHint']",
        "//string[@key = 'IBUIAccessibilityLabel']",
        "//string[@key = 'IBUIDisabledTitle']",
        "//string[@key = 'IBUIHighlightedTitle']",
        "//string[@key = 'IBUINormalTitle']",
        "//string[@key = 'IBUIPlaceholder']",
        "//string[@key = 'IBUISelectedTitle']",
        "//string[@key = 'IBUIText']",
        "//string[@key = 'IBUITitle']"
    ]

    def self.fencers() %w(Printf) end

    protected

    def import_file?
      file.path =~ /#{Regexp.escape(base_rfc5646_locale)}\.lproj\/[^\/]+\.xib$/
    end

    def import_strings(receiver)
      xml = Nokogiri::XML(file.contents)
      return unless xml.root.name == 'archive'

      XPATHS.each do |xpath|
        xml.xpath(xpath).each do |node|
          # Form a class path for the string. The class is something like
          # IBUIAccessibilityLabel, but it may be nested in an additional layer, such
          # as IBUIAccessibilityConfiguration.
          text_class_path = []
          object_node     = node
          begin
            text_class_path.unshift object_node['key']
            object_node = object_node.parent
          end until object_node['id']

          # Get the node for the object containing the string, something like
          # IBUIButton.
          object_reference_id = object_node['id']

          # We'll use the visible object ID to reference items
          main_object_id_node = xml.xpath("//object[@class = 'IBObjectRecord']/reference[@ref = '#{object_reference_id}']").first
          object_id           = main_object_id_node.parent.element_children.first.inner_text

          # Parse out a note if one is available
          note                = parse_note(xml, object_id)
          if note && note.include?(DO_NOT_LOCALIZE_TOKEN)
            log_skip object_id, "Note contains DNL token"
            next
          end

          object_class = object_node['class']
          text_class   = node['key']

          if node.element_children.empty?
            text = parse_text_from_text_node(node)
            next unless text

            # Attempt to create a human-readable comment from the known context
            generated_comment = I18n.t('importer.xib.automatic_context',
                                       text_class:   display_name_for_class(text_class).capitalize,
                                       object_class: display_name_for_class(object_class).downcase,
                                       file:         ::File.basename(file.path))

            comment = [note, generated_comment].compact.join(': ')
            key     = "#{object_id}.#{text_class_path.join('.')}"

            receiver.add_string "#{file.path}:#{key}", text, context: comment, original_key: key
          else
            item_index = 0
            node.element_children.each_with_index do |child, array_index|
              next unless child.name == 'string'
              item_index += 1

              text = parse_text_from_text_node(child)
              next unless text

              class_display_name = display_name_for_class(text_class).capitalize.singularize
              generated_comment  = I18n.t('importer.xib.automatic_context_item',
                                          text_class:   class_display_name,
                                          index:        item_index,
                                          object_class: display_name_for_class(object_class).downcase,
                                          file:         ::File.basename(file.path))

              comment = [note, generated_comment].compact.join(': ')
              key     = "#{object_id}.#{text_class_path.join('.')}[#{array_index}]"

              receiver.add_string "#{file.path}:#{key}", text, context: comment, original_key: key
            end
          end
        end
      end
    end

    private

    # Find the note. Notes are part of an encoded dictionary, which is encoded
    # as two arrays, one for keys and one for values.
    def parse_note(xml, object_id)
      # Find the note node, then find the corresponding value to get the note
      # itself

      note          = nil
      note_key_node = xml.xpath("//object[string = '#{object_id}.notes']/string[. = '#{object_id}.notes']").first

      note_node = nil
      if note_key_node
        keys_array   = note_key_node.parent
        values_array = keys_array.next_element

        if (key_index = keys_array.element_children.index(note_key_node))
          note_value_node = values_array.element_children[key_index]
          note_node       = note_value_node.element_children.first.element_children.first
        end
      end

      # If the first method didn't work, try an alternative method that seems to
      # be used in some xibs
      if note_node.nil?
        note_value_node = xml.xpath("//dictionary[@key = 'flattenedProperties']/object[@key = '#{object_id}.notes']").first
        note_node = note_value_node.element_children.first.element_children.first if note_value_node
      end

      if note_node
        case note_node.name
          when 'bytes'
            note = Base64.decode64(padded_base64(note_node.inner_text))
            note.force_encoding 'UTF-8'
          when 'characters'
            note = note_node.inner_text
        end
      end

      return note
    end

    def parse_text_from_text_node(node)
      text = node.inner_text
      text = Base64.decode64(padded_base64(text)).force_encoding('UTF-8') if node['type'] == 'base64-UTF8'

      return nil if text.blank?
      return nil if text.start_with?(DO_NOT_LOCALIZE_TOKEN)
      return text
    end
  end
end
