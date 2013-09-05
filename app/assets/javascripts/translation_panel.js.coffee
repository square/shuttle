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

# @private
modal = (title, body, confirm='OK') ->
  modaldiv = $('<div/>').addClass('modal hide fade')

  header = $('<div/>').addClass('modal-header').appendTo(modaldiv)
  $('<h3/>').text(title).appendTo header

  body_div = $('<div/>').addClass('modal-body').appendTo(modaldiv)
  $('<p/>').text(body).appendTo body_div

  footer = $('<div/>').addClass('modal-footer').appendTo(modaldiv)
  $('<a/>').addClass('btn btn-primary').text(confirm).attr('data-dismiss', 'modal').appendTo(footer)

  modaldiv.modal()

# @private
modalQuery = (title, body, options={}, yes_proc) ->
  modal = $('<div/>').addClass('modal hide fade')

  header = $('<div/>').addClass('modal-header').appendTo(modal)
  $('<h3/>').text(title).appendTo header

  body_div = $('<div/>').addClass('modal-body').appendTo(modal)
  $('<p/>').text(body).appendTo body_div

  footer = $('<div/>').addClass('modal-footer').appendTo(modal)
  $('<a/>').addClass('btn btn').text(options.no ? 'Cancel').attr('data-dismiss', 'modal').appendTo(footer)
  ok = $('<a/>').addClass('btn btn-primary').text(options.yes ? 'OK').appendTo(footer)
  ok.click ->
    modal.modal('hide')
    yes_proc()

  modal.modal()

# @private
htmlEscape = (str) -> str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

# @private
#
# Manages a single item in a translation panel view. Translation items act as a
# linked list via the `next` instance variable.
#
class TranslationItem

  # Characters to warn translators about. A list of four items:
  #
  # 1. an identifier for the character (used in CSS class names),
  # 2. the bad character,
  # 3. the human name of the bad character,
  # 4. the suggested replacement character, and
  # 5. the human name for the replacement character.
  #
  DUMB_CHARACTERS: [
    ['dash', '--', 'a double dash', '—', 'an em-dash'],
    ['double', '"', 'dumb quotes', '“”', 'smart quotes'],
    ['single', "'", 'dumb quotes', '‘’', 'smart quotes'],
    ['smiley', ':)', 'ASCII smiley', '☺', 'super cool Unicode smiley']
  ]

  # Creates a new translation item manager.
  #
  # @param [TranslationPanel] parent The translation panel this item belongs to.
  # @param [Object] translation The translation (loaded from JSON) for this
  #   item.
  # @param [Object] options Additional options.
  # @option options [Boolean] alternate (false) If `true`, this cell will be
  #   rendered with a slightly darker background.
  # @option options [Boolean] review (false) If `true`, the nomenclature for
  #   the translation panel will be geared towards reviewers, not translators.
  # @option options [String] word_substitute_url If provided, a button will be
  #   provided that submits the source copy for automatic word substitution.

  constructor: (@parent, @translation, @options) ->
    @next = null

  # Submits the copy for translation and re-renders the cell. Aborts early if
  # the copy does not pass token parity checks.
  #
  # @return [Boolean] Whether the submission passed checks.
  #
  submit: ->
    if @copy_field.val().length > 0 &&
        this.checkTokenParity(@translation.source_fences, @copy_field.val()).length > 0
      this.highlightTokenParityWarning()
      return false

    # if it was empty and it is empty, short-circuit
    if !@copy_field.val().length && !@translation.copy?.length
      return true

    @element.find('textarea, input').attr 'disabled', 'disabled'

    $.ajax @translation.url + '.json',
      type: 'PUT'
      data: $.param('translation[copy]': @element.find('textarea').val())
      complete: => @element.find('textarea, input').removeAttr 'disabled', 'disabled'
      success: (new_translation) => this.refresh new_translation
      error: => modal("Couldn’t update that translation.", "An error occurred.")
    return true

  # Re-renders the cell using a new translation object (loaded from JSON).
  #
  # @param [Object] new_translation The translation to re-render the cell with.
  #   By default it uses the cell's current translation.
  #
  refresh: (new_translation=@translation) ->
    @translation = new_translation
    old_element = @element
    this.build().insertAfter old_element
    old_element.remove()

  # Attempts to find an existing matching translation. If one is found,
  # pre-populates the copy field with it.
  #
  loadSuggestion: ->
    return unless !@translation.translated && @element.find('textarea').val() == ''
    $.ajax @translation.suggestion_url,
      success: (match) =>
        return unless match?
        @copy_field.val match.copy
        @copy_field.focus()
        @copy_field[0].selectionStart = 0
        @copy_field[0].selectionEnd = match.copy.length

  # @private
  build: ->
    @element = $('<div/>').addClass('text row-fluid')
    @element.addClass('alternate') if @options.alternate
    @element.addClass 'approved' if @translation.approved == true
    @element.addClass 'rejected' if @translation.approved == false
    @element.addClass 'translated' if @translation.approved == null && @translation.translated

    @left = $('<div/>').addClass('span6').appendTo(@element)
    @right = $('<div/>').addClass('span6').appendTo(@element)

    expand = $('<div/>').addClass('large-view pull-right').appendTo(@right)
    expand_link = $('<a/>').addClass('icon-external-link').attr('href', '#').appendTo(expand)
    expand_desc = $('<span/>').text("Go to full-screen view ").prependTo(expand).hide()
    expand_link.click (e) =>
      window.open @translation.edit_url, '_blank'
      expand_link.removeClass('icon-external-link').addClass 'icon-refresh'
      expand_desc.text "Reload any changes you made "
      expand_link.unbind('click').click =>
        $.ajax (@translation.url + '.json'),
               success: (translation) => this.refresh translation
               success: (translation) => this.refresh translation
               error: => modal("Couldn’t refresh a translation.", "An error occurred.")
      e.preventDefault(); e.stopPropagation(); return false
    expand.hover (-> expand_desc.show()), -> expand_desc.hide()

    this.renderCopyWithFencing(@translation.source_copy, @translation.source_fences).appendTo(@right)

    if @options.review && @translation.approved == null
      icons = $('<p/>').addClass('icons').appendTo(@right)
      button_approve = $('<button/>').addClass('btn btn-success btn-mini').appendTo(icons).click =>
        $.ajax @translation.approve_url,
          type: 'PUT'
          success: (translation) => this.refresh translation
          error: => modal("Couldn’t approve that translation.", "An error occurred.")
        return false
      $('<i/>').addClass('icon-ok').appendTo button_approve
      icons.append ' '

      button_reject = $('<button/>').addClass('btn btn-danger btn-mini').appendTo(icons).click =>
        $.ajax @translation.reject_url,
          type: 'PUT'
          success: (translation) => this.refresh translation
          error: => modal("Couldn’t reject that translation.", "An error occurred.")
        return false
      $('<i/>').addClass('icon-remove').appendTo button_reject
      icons.append ' '

    button_flag = $('<button/>').addClass('btn btn-warning btn-mini').appendTo(icons)
    $('<i/>').addClass('icon-flag').appendTo button_flag

    if @translation.key.context?
      $('<h6/>').text("Context").appendTo @right
      $('<p/>').addClass('context').text(@translation.key.context).appendTo @right


    stats = $('<p/>').addClass('stats').appendTo(@right)

    $('<strong/>').text("Key: ").appendTo stats
    stats.appendText @translation.key.original_key
    $('<br/>').appendTo stats

    $('<strong/>').text("Source: ").appendTo stats
    if @translation.key.source?
      stats.appendText @translation.key.source
      if @translation.key.importer_name?
        stats.appendText " (imported by #{@translation.key.importer_name})"
    else
      stats.append " (by request)"
    $('<br/>').appendTo stats

    @copy_field = $('<textarea/>').addClass('span12').val(@translation.copy).appendTo(@left)

    # select entire range when focused
    @copy_field.focus =>
      @copy_field[0].selectionStart = 0
      @copy_field[0].selectionEnd = @copy_field.val().length
      this.loadSuggestion()
      this.hideOtherGlossaryTooltips()
      this.renderGlossaryTooltip()

    # hitting enter saves the field
    @copy_field.keydown (e) =>
      if e.keyCode == 13
        e.preventDefault()
        this.submit() && this.advanceSelection()
        return false
      else
        return true

    @left.append ' '
    $('<a/>').addClass('btn btn-mini').text('Copy from source').attr('href', '#').appendTo(@left).click =>
      @copy_field.val @translation.source_copy
      this.setUnsaved()
      @copy_field.focus()
      false
    if @options.word_substitute_url
      @left.append ' '
      $('<a/>').addClass('btn btn-mini').text('Convert from source').attr('href', '#').appendTo(@left).click =>
        $.ajax "#{@options.word_substitute_url}&string=#{encodeURIComponent @translation.source_copy}",
          success: (result) =>
            this.clearNotes()
            @copy_field.val result.string
            for note in result.notes
              do (note) => this.addNote note
            for suggestion in result.suggestions
              do (suggestion) => this.addNote suggestion
          error: -> modal("Couldn’t automatically convert the source string.", "An error occurred.")
      false

    @copy_field.keyup =>
      # mark field unsaved when modified
      this.setUnsaved()
      # show warnings
      this.checkForDumbCharacters(@copy_field.val())
      this.warnForTokenParity(@translation.source_fences, @copy_field.val())
      return true

    for chars in TranslationItem::DUMB_CHARACTERS
      $('<p/>').addClass("alert dumb-#{chars[0]}").text("Consider using #{chars[4]} #{chars[3]} instead of #{chars[2]} #{chars[1]}.").insertAfter(@copy_field).hide()

    $('<p/>').addClass('alert token-parity-warning').insertAfter(@copy_field).hide()

    $('<p/>').addClass('alert alert-info glossary-tips').insertAfter(@copy_field).hide()

    if @translation.translator
      p = $('<p/>').text("Translated by #{@translation.translator.name}").appendTo(@right)
      $('<i/>').addClass('icon-globe').prependTo p
    if @translation.reviewer
      if @translation.approved == true
        p = $('<p/>').css('color', 'darkgreen').text(" Approved by #{@translation.reviewer.name}").appendTo(@right)
        $('<i/>').addClass('icon-ok').prependTo p
      if @translation.approved == false
        p = $('<p/>').css('color', 'darkred').text(" Rejected by #{@translation.reviewer.name}").appendTo(@right)
        $('<i/>').addClass('icon-remove').prependTo p

    return @element

  # Moves focus to the next translation item in the list.
  advanceSelection: -> @next?.activate()

  # Moves focus to this cell's copy field.
  activate: -> @copy_field.focus()

  # @private
  setUnsaved: ->
    if @translation.copy?
      if @translation.copy != @copy_field.val()
        @element.addClass('unsaved') if !@element.hasClass('unsaved')
      else
        @element.removeClass 'unsaved'
    else
      if @copy_field.val().length > 0
        @element.addClass('unsaved') if !@element.hasClass('unsaved')
      else
        @element.removeClass 'unsaved'

  # @private
  checkForDumbCharacters: (copy) ->
    if copy.length == 0
      for chars in TranslationItem::DUMB_CHARACTERS
        @element.find(".dumb-#{chars[0]}").hide()
      return

    for chars in TranslationItem::DUMB_CHARACTERS
      if copy.indexOf(chars[1]) > -1
        @element.find(".dumb-#{chars[0]}").show()
      else
        @element.find(".dumb-#{chars[0]}").hide()

  # @private
  checkTokenParity: (fences, copy) ->
    (key for own key, value of fences when copy.indexOf(key) == -1)

  # @private
  warnForTokenParity: (fences, copy) ->
    if copy.length == 0
      @element.find('.token-parity-warning').hide()
      return

    missing_fences = this.checkTokenParity(fences, copy)
    if missing_fences.length > 0
      @element.find('.token-parity-warning').text("You’re missing the following tokens in your translation: #{toSentence(missing_fences)}").show()
    else
      @element.find('.token-parity-warning').hide()

  # @private
  highlightTokenParityWarning: ->
    @element.find('.token-parity-warning').
      addClass('bulge').
      oneTime 200, -> $(this).removeClass('bulge')

  # @private
  renderCopyWithFencing: (copy, fences) ->
    # build an array of ranges we need to wrap in SPAN tags
    ranges = []
    for own _, ranges_for_keyword of fences
      do (ranges_for_keyword) -> ranges = ranges.concat ranges_for_keyword
    ranges = ranges.sort (a,b) -> b[0] - a[0]

    copy_index = 0
    fenced_p = $('<p/>').addClass('fenced-copy')

    # consume the list of ranges
    while ranges.length > 0
      range = ranges.pop()
      # consume the string up to the next range
      if range[0] > copy_index
        fenced_p.append htmlEscape(copy[copy_index...range[0]])
        copy_index = range[0]
      # consume the range and enclose it in a span
      $('<span/>').addClass('fenced').text(copy[range[0]..range[1]]).appendTo fenced_p
      copy_index = range[1] + 1

    # consume from the end of the last range to the end of the string
    if copy_index < copy.length
      fenced_p.append htmlEscape(copy[copy_index..])

    return fenced_p

  renderGlossaryTooltip: ->
    glossaryTips = []
    for term in @parent.glossary
      if @element.find('.fenced-copy').text().toLowerCase().search(term[0].toLowerCase()) > -1
        glossaryTips.push("<em>" + term[0] + "</em>: " + term[1])

    if glossaryTips.length == 0
      return
    @element.find('.glossary-tips').html(glossaryTips.join("<br/>")).show()

  hideOtherGlossaryTooltips: ->
    $('.glossary-tips').hide()

  # @private
  removeGlossaryTooltip: (element) -> element.find('input').popover('destroy')

  # @private
  clearNotes: -> @left.find('.translation-item-note').remove()

  # @private
  addNote: (note) ->
    div = $('<p/>').addClass('translation-item-note alert').text(note.note).appendTo(@left)
    if note.replacement
      $('<strong/>').text(note.replacement + ': ').prependTo div
    else
      div.addClass 'alert-info'

    oldStart = null
    oldEnd = null
    div.hover (=>
      oldStart = @copy_field[0].selectionStart
      oldEnd = @copy_field[0].selectionEnd
      @copy_field[0].selectionStart = note.range[0]
      @copy_field[0].selectionEnd = note.range[1] + 1
    ), =>
      @copy_field[0].selectionStart = oldStart
      @copy_field[0].selectionEnd = oldEnd


# Manages and renders a translation panel where translators can quickly view and
# contribute translations to a project, and reviewers can quickly approve or
# reject translations.
#
class root.TranslationPanel

  # Creates a new translation panel manager.
  #
  # @param [jQuery Object] list The element that the translation list will be
  #   rendered into.
  # @param [jQuery Object] filter The element containing the filter form.
  # @param [String] url The URL to load translations from.
  # @param [Array] glossary A JSON-decoded list of glossary entries.
  # @param [Object] options Addditional options. These are passed to the
  #   `TranslationItem` constructor.
  #
  constructor: (@list, @filter, @url, @glossary, @options) ->
    @items = []
    @scroll = @list.infiniteScroll (=> @makeURL()),
      renderer: (items) => @addItems items
    @filter.submit => @search(); return false

  # Submits a filter query and refreshes the strings list.
  #
  search: ->
    @empty()
    $('<p/>').text("Loading…").addClass('big-status').appendTo @list
    $.ajax @makeURL(),
      success: (translations) =>
        @empty()
        if translations.length == 0
          $('<p/>').addClass('big-status').text("Nothing to translate").appendTo @list
          return
        @scroll.append translations
      error: =>
        @empty()
        flash = $('<p/>').addClass('alert alert-error').text("Couldn’t load list of translations.").appendTo($('#flashes'))
        $('<a/>').addClass('close').attr('data-dismiss', 'alert').text('×').appendTo flash

  # Removes all items from the strings list.
  #
  empty: ->
    @items = []
    @scroll.reset()
    @list.empty()

  # @private
  addItems: (translations) ->
    previousItem = null
    for translation, i in translations
      do (translation) =>
        options = $.extend({}, @options, {alternate: i % 2 == 1})
        item = new TranslationItem(this, translation, options)
        previousItem.next = item if previousItem?
        item.build().appendTo @list
        @items.push item
        previousItem = item

  # @private
  makeURL: -> @url + "?" + @filter.serialize()
