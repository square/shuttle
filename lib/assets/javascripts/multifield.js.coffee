# Copyright 2013 Square Inc.
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

# A dynamic field that builds a list of field items (with plus and minus
# buttons) that will be serialized as an array in Rails. This allows the field
# to integrate directly with an array model value in forms.
#
# See multifield.rb to learn how to easily use this class in your forms.
#
class root.ArrayField

  # Creates a new ArrayField to render within a given element.
  #
  # @param [jQuery element] element A container element to render the field in.
  # @param [Array] value The initial value of the field.
  # @param [Object] options Additional options.
  # @option options [function] renderer A function that renders an individual
  #   array field item. By default it renders a simple text field. This function
  #   takes three parameters: the container to render the field item into, the
  #   `name` attribute of the field, and the field's value. It should render a
  #   field into the container whose `name` and `value` attributes are set
  #   accordingly.
  # @option options [Object] defaultValue (null) The value to set a new field
  #   item to, when it is added via the plus button.
  #
  constructor: (@element, @value, @options={}) ->
    @options['renderer'] ?= (container, name, value) => this.renderTextField(container, name, value)

    this.redraw()

    MutationObserver = window.MutationObserver || window.WebKitMutationObserver || window.MozMutationObserver
    observer = new MutationObserver (changes) =>
      for change in changes
        do (change) =>
          if change.attributeName == 'name'
            @element.find('[name]').attr('name', "#{this.name()}[]")
    observer.observe @element[0], {attributes: true}

  # Removes all content under the container element and re-renders the field.
  #
  redraw: ->
    @element.empty()
    this.drawButtons()
    for string in @value
      do (string) => this.addElement string

  # Appends a field item to the array field.
  #
  # @param [Object] value The initial value of the field item.
  #
  addElement: (value) ->
    div = $('<div/>').addClass('arrayfield-element').insertBefore(@element.find('.multifield-buttons'))
    @options.renderer div, "#{this.name()}[]", value
    remove = $('<a/>').addClass('icon-minus-sign').attr('href', '#').appendTo(div)
    remove.click =>
      div.remove()
      false

  # @private
  renderTextField: (container, name, value) ->
    $('<input/>').attr('name', name).val(value).appendTo container

  # @private
  drawButtons: ->
    div = $('<div/>').addClass('multifield-buttons').appendTo(@element)
    add = $('<a/>').addClass('icon-plus-sign').attr('href', '#').appendTo(div)
    add.click =>
      this.addElement @options.defaultValue
      false

  # @private
  name: -> @element.attr 'name'

# A dynamic field that builds a list of field item pairs (with plus and minus
# buttons) that will be serialized as a hash in Rails. This allows the field
# to integrate directly with an hash model value in forms.
#
# See multifield.rb to learn how to easily use this class in your forms.
#
class root.HashField

  # Creates a new HashField to render within a given element.
  #
  # @param [jQuery element] element A container element to render the field in.
  # @param [Hash] value The initial value of the field.
  # @param [Object] options Additional options.
  # @option options [function] renderer A function that renders an individual
  #   hash field item. By default it renders a simple text field pair. This
  #   function takes three parameters: the container to render the field item
  #   into, the `name` attribute of the field, and the field's value. The
  #   function should render both the key and value fields. The key field should
  #   have its `rel` attribute set to "key", and the value field should have its
  #   `rel` attribute set to "value". The fields should have their `value`
  #   attribute set to the key and value parameters respectively.
  # @option options [Object] defaultKey (null) The value to set the key field of
  #   a new field item to, when it is added via the plus button.
  # @option options [Object] defaultValue (null) The value to set the value
  #   field of a new field item to, when it is added via the plus button.
  #
  constructor: (@element, @value, @options={}) ->
    @options['renderer'] ?= (container, key, value) => this.renderTextFields(container, key, value)

    this.redraw()

    MutationObserver = window.MutationObserver || window.WebKitMutationObserver || window.MozMutationObserver
    observer = new MutationObserver (changes) =>
      for change in changes
        do (change) =>
          if change.attributeName == 'name'
            @element.find('[name]').each (_, field) =>
              $(field).attr 'name', "#{this.name()}[#{this.keyFromName($(field).attr('name'))}]"
    observer.observe @element[0], {attributes: true}

  # Removes all content under the container element and re-renders the field.
  #
  redraw: ->
    @element.empty()
    this.drawButtons()
    for own name, value of @value
      do (name, value) => this.addElement name, value

  # Appends a field item to the hash field.
  #
  # @param [Object] key The initial value of the key field.
  # @param [Object] value The initial value of the value field.
  #
  addElement: (key, value) ->
    div = $('<div/>').addClass('hashfield-element').insertBefore(@element.find('>.multifield-buttons'))

    @options.renderer div, key, value
    key_field = div.find('[rel=key]')
    value_field = div.find('[rel=value]')
    refreshName = =>
      new_key = key_field.val()
      if new_key?.length > 0
        value_field.attr 'name', "#{this.name()}[#{new_key}]"
      else
        value_field.removeAttr 'name'
    key_field.keyup refreshName
    key_field.change refreshName
    refreshName()

    remove = $('<a/>').addClass('icon-minus-sign').attr('href', '#').appendTo(div)
    remove.click =>
      div.remove()
      false

  # @private
  renderTextFields: (container, key, value) ->
    $('<input/>').attr('rel', 'key').val(key).appendTo container
    container.append ' '
    $('<input/>').attr('rel', 'value').val(value).appendTo container

  # @private
  drawButtons: ->
    div = $('<div/>').addClass('multifield-buttons').appendTo(@element)
    add = $('<a/>').addClass('icon-plus-sign').attr('href', '#').appendTo(div)
    add.click =>
      this.addElement @options.defaultKey, @options.defaultValue
      false

  # @private
  name: -> @element.attr 'name'

  # @private
  keyFromName: (name) -> name.match(/\[\w+\]/g)[1..-2]

(($) ->

  # Allows you to convert a jQuery container object into an {ArrayField}.
  #
  # @param [Object] options Additional options to give to ArrayField.
  #
  $.fn.arrayField = (options={}) ->
    $(this).each (_, element) ->
      jqe = $(element)
      value = if jqe.attr('data-value') then JSON.parse(jqe.attr('data-value')) else ''
      new ArrayField(jqe, value, options)

  # Allows you to convert a jQuery container object into a {HashField}.
  #
  # @param [Object] options Additional options to give to HashField.
  #
  $.fn.hashField = (options={}) ->
    $(this).each (_, element) ->
      jqe = $(element)
      value = if jqe.attr('data-value') then JSON.parse(jqe.attr('data-value')) else ''
      new HashField(jqe, value, options)
)(jQuery)

# Converts `DIV`s with the class "array-field" into {ArrayField}s, and `DIV`s
# with the class "hash-field" into {HashField}s.

$(document).ready ->
  $('.array-field').arrayField()
  $('.hash-field').hashField()
