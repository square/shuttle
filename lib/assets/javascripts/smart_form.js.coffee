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

root = exports ? this

# @private A field in a SmartForm.
class SmartField
  constructor: (@element) ->
    @element.change =>
      this.setErrors []

  setErrors: (errors) ->
    if errors.length == 0
      @element.find('ul').remove()
      @element.closest('.control-group').removeClass 'error'
    else
      control_group = @element.closest('.control-group')
      if !control_group
        control_group = $('<div/>').addClass('control-group')
        @element.wrap control_group
      control_group.addClass('error')
      @element.tooltip
        title: (this.escape(error) for error in errors).join("<br/>")
        placement: 'right'
        trigger: 'focus'
        template: '<div class="tooltip tooltip-error"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'

  escape: (str) -> str.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

# A form that automatically parses JSON error responses and modifies itself to
# display the errors appropriately.
#
# The form will be submitted using Ajax, with form elements encoded in JSON
# format. The response should be of the form:
#
# ```` json
# {'recordname':{'fieldname':['error1',...]}}
# ````
#
# This class will look for fields with names of the format
# `recordname[fieldname]` and give them an errored appearance. When the field
# receives focus, a tooltip is displayed showing the errors that need to be
# corrected.
#
# In the event that an HTTP error prevents the form from being submitted, a
# flash alert will be displayed above the field.
#
class root.SmartForm

  # Creates a new manager for a smart form.
  #
  # @param [jQuery element array] element The form to smartify.
  # @param [function] success A callback to execute on successful submission.
  #
  constructor: (@element, success) ->
    @smart_fields = {}
    @element.find('input[name],textarea[name]').each (_, field) =>
      @smart_fields[$(field).attr('name')] = new SmartField($(field))
    @element.submit (e) =>
      @element.find('input[type=submit]').attr 'disabled', 'disabled'
      $.ajax @element.attr('action'),
        type: @element.attr('method')
        data: @element.serialize()
        complete: => @element.find('input[type=submit],button').removeAttr 'disabled'
        success: =>
          this.clearErrors()
          success arguments...
        error: (xhr) =>
          this.clearErrors()
          if xhr && xhr.status == 422
            models = JSON.parse(xhr.responseText)
            this.setErrors models
          else
            error_text = if xhr then JSON.parse(xhr.responseText).message else "An error occurred. Sorry!"
            div = $('<div/>').addClass('alert alert-error').text(error_text).insertBefore(@element)
            $('<a/>').addClass('close').attr('data-dismiss', 'alert').html('&times;').prependTo div
      false

  # @private
  setErrors: (models) ->
    for model, errors of models
      do (model, errors) =>
        for name, messages of errors
          do (name, messages) =>
            return unless @smart_fields["#{model}[#{name}]"]
            @smart_fields["#{model}[#{name}]"].setErrors messages

  # @private
  clearErrors: ->
    for _, field of @smart_fields
      field.setErrors []
