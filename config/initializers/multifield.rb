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

# Multifield additions for form rendering.

module ActionView::Helpers::FormHelper

  # Renders an HTML tag of your choosing whose `name` attribute is set
  # appropriately.
  #
  # @param [String] tag_name The name of the tag (e.g., "div").
  # @param [Symbol, String] object_name The name of the form object.
  # @param [Symbol, String] method The name of the object method.
  # @param [Hash] options Additional options to pass to the tag generator.

  def content_tag_field(tag_name, object_name, method, options)
    ActionView::Helpers::Tags::ContentField.new(object_name, method, self, options.merge(tag_name: tag_name)).render
  end
end

# Multifield additions for form rendering.

class ActionView::Helpers::FormBuilder

  # Renders an HTML tag of your choosing whose `name` attribute is set
  # appropriately.
  #
  # @param [String] tag_name The name of the tag (e.g., "div").
  # @param [Symbol, String] method The name of the object method.
  # @param [Hash] options Additional options to pass to the tag generator.

  def content_tag_field(tag_name, method, options={}, &block)
    @template.content_tag_field tag_name, @object_name, method, objectify_options(options), &block
  end
end

# Multifield additions for form rendering.

class ActionView::Helpers::Tags::ContentField < ActionView::Helpers::Tags::Base

  def render
    options = @options.stringify_keys
    options['value'] = options.fetch('value'){ value_before_type_cast(object) }
    options['value'] &&= ERB::Util.html_escape(options['value'])
    add_default_name_and_id(options)
    tag(options['tag_name'].to_s, options, true) + "</#{options['tag_name']}>".html_safe
  end
end
