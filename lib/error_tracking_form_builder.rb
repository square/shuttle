# encoding: utf-8

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


# This class extends the normal `FormBuilder` to include the ability to render
# those errors which were not attached to a field using the `field_error_proc`.
# After rendering all your fields, call the {#other_errors_tag} method to render
# a list of errors that were not associated with any rendered field.
#
# If you wish to customize error output, use {#other_errors} instead. These
# methods must be called _after_ all fields have been rendered. Use `capture`
# if you want to reorder the display of errors to above the form.
#
# @example
#   form_for @object, builder: ErrorTrackingFormBuilder do |f|
#     f.text_field :some_field
#     f.other_errors_tag
#     f.submit
#   end

class ErrorTrackingFormBuilder < ActionView::Helpers::FormBuilder
  # @private
  def initialize(*)
    @rendered_fields = Set.new
    super
  end

  field_helpers.each do |meth|
    next if meth == :hidden_field

    define_method(meth) do |method, *args, &block|
      @rendered_fields << method
      super method, *args, &block
    end
  end

  # @return [Hash<Symbol, Array<String>>] Those errors that were not output to
  #   HTML using the `field_error_proc`.

  def other_errors
    object.errors.to_hash.except(*@rendered_fields)
  end

  # @return [String] A string containing a Bootstrap-ready HTML div with a list
  #   of all unrendered errors. Use the I18n key
  #   `helpers.error_tracking_form.could_not_be_saved` to set the header text,
  #   and the `helpers.error_tracking_form.error_pair` I18n key to set the
  #   display of a single error in the list.

  def other_errors_tag
    return if other_errors.empty?

    ERB.new(<<-HTML).result(binding).html_safe
      <div class="alert alert-error">
        <p><%= I18n.t('helpers.error_tracking_form.could_not_be_saved', model: object.class.model_name.singular) %></p>
        <ul>
          <% other_errors.each do |field, errors| %>
            <% errors.each do |error| %>
              <li><%= I18n.t('helpers.error_tracking_form.error_pair', field: object.class.human_attribute_name(field), error: error)%></li>
            <% end %>
          <% end %>
        </ul>
      </div>
    HTML
  end
end
