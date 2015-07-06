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

  # Parses translatable strings from Apple Storyboard files, as generated by
  # Interface Builder.

  class Storyboard < Base
    include IosCommon

    # Xpaths of strings to extract.
    XPATHS                      = [
        "//*[@sceneMemberID = 'viewController']",
        "//accessibility",
        "//barButtonItem",
        "//label",
        "//navigationItem",
        "//segments",
        "//state[@key = 'disabled']",
        "//state[@key = 'highlighted']",
        "//state[@key = 'normal']",
        "//state[@key = 'selected']",
        "//tabBarItem",
        "//tableViewSection",
        "//textField"
    ]

    # Attributes to localize.
    ATTRIBUTES                  = %w( footerTitle hint label placeholder headerTitle text title )

    # XML entities containing localizable strings.
    ENTITIES_CONTAINING_STRINGS = %w( accessibility barButtonItem
      glkViewController label navigationController navigationItem
      pageViewController segment splitViewController state tabBarController
      tabBarItem tableViewController tableViewSection textField viewController )

    def self.fencers() %w(Printf) end

    protected

    def import_file?
      file.path =~ /#{Regexp.escape(base_rfc5646_locale)}\.lproj\/[^\/]+\.storyboard$/
    end

    def import_strings
      xml = Nokogiri::XML(file.contents)

      XPATHS.each do |xpath|
        xml.xpath(xpath).each do |node|
          # Form a class path for the string. The class is something like
          # IBUIAccessibilityLabel, but it may be nested in an additional layer, such
          # as IBUIAccessibilityConfiguration.
          text_node_path = []
          object_node    = node
          until object_node['id']
            text_node_path.unshift object_node
            object_node = object_node.parent
          end

          # Parse out a note if one is available
          note = parse_note(xml, object_node['id'])
          if note && note.include?(DO_NOT_LOCALIZE_TOKEN)
            log_skip object_node['id'], "Note contains DNL token"
            next
          end

          # Figure out which view controller this is a part of
          view_controller_node = object_node
          while view_controller_node['sceneMemberID'] != 'viewController'
            if !view_controller_node.kind_of?(Nokogiri::XML::Node) || view_controller_node.kind_of?(Nokogiri::XML::Document)
              view_controller_node = nil
              break
            end
            view_controller_node = view_controller_node.parent
          end
          view_controller_name = display_name_for_class(view_controller_node['customClass']) if view_controller_node && view_controller_node['customClass']

          add_strings_for_node(node, object_node, note, view_controller_name, text_node_path, file).each do |(key, value, comment)|
            add_string "#{file.path}:#{key}", value,
                                original_key: key,
                                context:      comment
          end
        end
      end
    end

    private

    def add_strings_for_node(node, object_node, note, view_controller_name, text_node_path, file, array_index_path=nil)
      if ENTITIES_CONTAINING_STRINGS.include?(node.name)
        build_localizable_strings node, object_node, note, view_controller_name, text_node_path, file, array_index_path
      else
        localizable_strings = []
        node.element_children.each_with_index do |child, index|
          appended_text_node_path = text_node_path + [child]
          array_index_path = [nil]*text_node_path.size if array_index_path.nil?
          appended_array_index_path = array_index_path + [index]

          localizable_strings += add_strings_for_node(child, object_node, note, view_controller_name, appended_text_node_path, file, appended_array_index_path)
        end
        return localizable_strings
      end
    end

    def build_localizable_strings(node, object_node, note, view_controller_name, text_node_path, file, array_index_path)
      localizable_strings = []

      # We'll use the object ID to reference items
      object_id           = object_node['id']

      # Get the node class for the object containing hte string. Something like
      # "label"
      object_class        = object_node.name

      # There are two varieties of strings to localize: node parameters, and
      # strings in a child <string> tag
      strings_to_localize = {}
      ATTRIBUTES.each do |attribute_name|
        text = node[attribute_name]
        strings_to_localize[attribute_name] = text
      end

      node.element_children.each do |child_node|
        if child_node.name == 'string' && ATTRIBUTES.include?(child_node['key'])
          strings_to_localize[child_node['key']] = child_node.content
        end
      end

      strings_to_localize.each do |text_class, text|
        next if text.blank?
        if text.start_with?(DO_NOT_LOCALIZE_TOKEN)
          log_skip object_id, "text starts with DNL token"
          next
        end

        # Attempt to create a human-readable comment from the known context
        if array_index_path.present?
          generated_comment = I18n.t('importer.storyboard.automatic_context_index',
                                     text_class: display_name_for_class(text_class).capitalize,
                                     text_node:  node.name,
                                     index:      array_index_path[-1])
        elsif text_node_path.present?
          generated_comment = I18n.t('importer.storyboard.automatic_context',
                                     key:        node['key'].try!(:capitalize) || '(null)',
                                     text_class: display_name_for_class(text_class))
        else
          generated_comment = display_name_for_class(text_class).capitalize
        end

        if view_controller_name
          generated_comment << I18n.t('importer.storyboard.automatic_context_suffix',
                                      object_class:    display_name_for_class(object_class).downcase,
                                      view_controller: view_controller_name,
                                      file:            ::File.basename(file.path))
        else
          generated_comment << I18n.t('importer.storyboard.automatic_context_suffix_no_vc',
                                      object_class: display_name_for_class(object_class).downcase,
                                      file:         ::File.basename(file.path))
        end

        comment = [note, generated_comment].compact.join(': ')
        key     = object_id.dup
        text_node_path.each_with_index do |child, index|
          key << ".#{child.name}"
          key << "[#{array_index_path[index]}]" if array_index_path && array_index_path[index]
          key << "[#{child['key']}]" if child['key']
        end
        key << ".#{text_class}"

        localizable_strings << [key, text, comment]
      end

      return localizable_strings
    end

    def parse_note(xml, object_id)
      # Notes are an attributed string...

      # ... as part of a binary-encoded plist dictionary
      note_node = xml.xpath("//*[@id = '#{object_id}']/mutableAttributedString[@key = 'userComments']/mutableData[@key = 'keyedArchiveRepresentation']").first
      if note_node
        binary_plist_data   = Base64.decode64(padded_base64(note_node.content))
        note_plist_contents = CFPropertyList.native_types(CFPropertyList::List.new(data: binary_plist_data))
        objects             = note_plist_contents['$objects']
        note                = objects.detect do |object|
          next unless object.kind_of?(Hash)
          object['NS.string']
        end['NS.string']

        return note
      end

      # ... or encoded in XML
      note_node = xml.xpath("//*[@id = '#{object_id}']/attributedString[@key = 'userComments']").first
      if note_node
        note = note_node.css('fragment').map { |f| f['content'] }.join
        return note
      end
    end
  end
end
