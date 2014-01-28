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

# Works with config/initializers/field_error_proc.rb to properly stylize form
# fields with errors. This is intended for basic HTML forms; smart Ajax-y forms
# are handled by {SmartForm}.

$(document).ready ->
  escape = (str) -> str.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

  $('.field-with-errors').each (_, span) ->
    element = $(span)
    already_applied = element.parent('div.control-group').hasClass('error')
    errors = (attr.value for attr in span.attributes when attr.name == 'data-error')
    form_element = element.find('input,textarea,select,label')
    element.children().unwrap()
    return if form_element.is('label')

    form_element.parents('div.control-group').addClass('error')
    form_element.tooltip
      title: (escape(error) for error in errors).join("<br/>")
      placement: 'right'
      trigger: 'focus'
      template: '<div class="tooltip tooltip-error"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'
