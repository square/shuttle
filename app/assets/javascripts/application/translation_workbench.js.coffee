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

# @private
htmlEscape = (str) -> str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

# @private
#
# Manages a single item in a translation workbench view. Translation items act as a
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
  # @param [TranslationWorkbench] parent The translation workbench this item belongs to.
  # @param [Object] translation The translation (loaded from JSON) for this
  #   item.
  # @param [Object] options Additional options.
  # @option options [Boolean] alternate (false) If `true`, this cell will be
  #   rendered with a slightly darker background.
  # @option options [Boolean] review (false) If `true`, the nomenclature for
  #   the translation workbench will be geared towards reviewers, not translators.
  # @option options [String] word_substitute_url If provided, a button will be
  #   provided that submits the source copy for automatic word substitution.

  constructor: (@parent, @translation, @options) ->
    @next = null
    @fencers = []
    for fencer_type in @translation.key.fencers
      do (fencer_type) =>
        @fencers.push(new Fencer(fencer_type, @translation.source_fences))

  # Submits the copy for translation and re-renders the cell. Aborts early if
  # the copy does not pass token parity checks.
  #
  # @return [Boolean] Whether the submission passed checks.
  #
  submit: ->
    if @copy_field.val().length > 0 && this.hasMissingTokens(@copy_field.val())
      this.highlightTokenParityWarning()
      return false

    # if it was empty and it is empty, short-circuit
    if !@copy_field.val().length && !@translation.copy?.length
      return true

    @element.find('.translation-area, input').attr 'disabled', 'disabled'

    $.ajax @translation.url + '.json',
      type: 'PUT'
      data: $.param('translation[copy]': @element.find('.translation-area').val())
      complete: => @element.find('.translation-area, input').removeAttr 'disabled', 'disabled'
      success: (new_translation) => this.refresh new_translation
      error: => new Flash('alert').text("Couldn't update that translation.");
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
    @element.find(".translation-area").autosize()

  # Attempts to find an existing matching translation. If one is found,
  # pre-populates the copy field with it.
  #
  loadSuggestion: ->
    return unless !@translation.translated && @element.find('.translation-area').val() == ''
    $.ajax @translation.suggestion_url,
      success: (match) =>
        return unless match?
        @copy_field.val match.copy
        @copy_field.focus()
        @copy_field[0].selectionStart = 0
        @copy_field[0].selectionEnd = match.copy.length

  # @private
  build: ->
    context = {}

    switch @translation.approved
      when true then context.status = 'approved'
      when false then context.status = 'rejected'
      else
        if @translation.translated
          context.status = 'translated'
        else
          context.status = ''

    context.translation_copy = @translation.copy
    context.source_copy = this.renderCopyWithFencing(
                                                      @translation.source_copy,
                                                      @translation.source_fences
                                                    ).html()

    if @options.review && (@translation.approved == null)
      context.controls = true

    if @translation.key.context?
      context.context = @translation.key.context

    if @options.word_substitute_url
      context.convert_source = true

    context.key = @translation.key.original_key
    if @translation.key.source?
      context.source = @translation.key.source
      if @translation.key.importer_name?
        context.source += " (imported by #{@translation.key.importer_name})"
    else
      context.source = " (by request)"

    if @translation.translator
      context.translator = @translation.translator.name
    if @translation.reviewer
      context.approved = @translation.approved
      context.reviewer = @translation.reviewer.name

    @element = $(HoganTemplates['translationworkbench/translation_item'].render(context)) 

    @copy_field = @element.find('.translation-area').first()

    @expand_link_button = @element.find('.expand-link').first()
    @copy_source_button = @element.find('.copy-source').first()
    @convert_source_button = @element.find('.convert-source').first()

    @approve_button = @element.find('button.square.approve').first()
    @reject_button = @element.find('button.square.reject').first()

    @alerts = @element.find('div.alerts').first()
    @glossary_tips = @element.find('div.tips').first()
    
    # Set up @copy_field
    @copy_field.focus () =>
      # select entire range when focused
      @copy_field[0].selectionStart = 0
      @copy_field[0].selectionEnd = @copy_field.val().length
      this.loadSuggestion()
      this.hideOtherGlossaryTooltips()
      this.renderGlossaryTooltip()

    @copy_field.keydown (e) =>
      # hitting enter saves the field
      if e.keyCode == 13
        e.preventDefault()
        this.submit() && this.advanceSelection()
        return false
      else
        return true

    @copy_field.keyup () =>
      # mark field unsaved when modified
      this.setUnsaved()
      # show warnings
      this.checkForDumbCharacters(@copy_field.val())
      this.warnForTokenParity(@copy_field.val())
      return true
    
    # Set up @expand_link_button
    @expand_link_button.click (e) =>
      window.open @translation.edit_url, '_blank'
      @expand_link_button.find("i").removeClass('fa-pencil-square-o').addClass 'fa-spinner'
      @expand_link_button.unbind('click').click =>
        $.ajax (@translation.url + '.json'),
               success: (translation) => this.refresh translation
               error: => new Flash('alert').text("Couldn't refresh a translation.");
      e.preventDefault(); e.stopPropagation(); return false

    # Set up @copy_source_button
    @copy_source_button.click () => 
      @copy_field.val @translation.source_copy
      this.setUnsaved()
      @copy_field.focus()
      return false

    # Set up @convert_source_button
    if @convert_source_button.size() > 0
      @convert_source_button.click () =>
        $.ajax "#{@options.word_substitute_url}&string=#{encodeURIComponent @translation.source_copy}",
          success: (result) =>
            this.clearNotes()
            @copy_field.val result.string
            for note in result.notes
              do (note) => this.addNote note
            for suggestion in result.suggestions
              do (suggestion) => this.addNote suggestion
          error: () => new Flash('alert').text("Couldn't automatically convert the source string.");
        return false

    # Set up @approve_button and @reject_button
    if (@approve_button.size() > 0) && (@reject_button.size() > 0)
      @approve_button.click () =>
        $.ajax @translation.approve_url,
          type: 'PUT'
          success: (translation) => this.refresh translation
          error: () => new Flash('alert').text("Couldn't approve that translation.");
        return false
      @reject_button.click () =>
        $.ajax @translation.reject_url,
          type: 'PUT'
          success: (translation) => this.refresh translation
          error: () => new Flash('alert').text("Couldn't reject that translation.");
        return false

    # Set up @alerts
    $('<p/>').addClass('alert token-parity-warning')
      .appendTo(@alerts).hide()

    for chars in TranslationItem::DUMB_CHARACTERS
      $('<p/>').addClass("warning dumb-#{chars[0]}")
        .text("Consider using #{chars[4]} #{chars[3]} instead of #{chars[2]} #{chars[1]}.")
        .appendTo(@alerts).hide()

    # Set up @glossary_tips
    $('<p/>').addClass('glossary-tips')
      .appendTo(@glossary_tips).hide()

    return @element

  # Moves focus to the next translation item in the list.
  advanceSelection: -> @next?.activate()

  # Moves focus to this cell's copy field.
  activate: -> @copy_field.focus()

  # @private
  setUnsaved: ->
    if @translation.copy?
      if @translation.copy != @copy_field.val()
        @copy_field.addClass('unsaved') if !@copy_field.hasClass('unsaved')
      else
        @copy_field.removeClass 'unsaved'
    else
      if @copy_field.val().length > 0
        @copy_field.addClass('unsaved') if !@copy_field.hasClass('unsaved')
      else
        @copy_field.removeClass 'unsaved'

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
  hasMissingTokens: (copy) ->
    (f for f in @fencers when f.missingFences(copy).length > 0).length > 0

  # @private
  warnForTokenParity: (copy) ->
    if copy.length == 0
      @element.find('.token-parity-warning').hide()
      return

    missing_fences = []
    for fencer in @fencers
      do (fencer) -> missing_fences = missing_fences.concat(fencer.missingFences(copy))
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
      if @element.find('.source-copy').text().toLowerCase().search(term[0].toLowerCase()) == 0
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
    div = $('<p/>').addClass('translation-item-note alert').text(note.note).appendTo(@glossary_tips)
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


# Manages and renders a translation workbench where translators can quickly view and
# contribute translations to a project, and reviewers can quickly approve or
# reject translations.
#
class root.TranslationWorkbench

  # Creates a new translation workbench manager.
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
      windowScroll: true
      renderer: (items) =>
        @addItems items
    @filter.submit => 
      @search() 
      return false

  # Submits a filter query and refreshes the strings list.
  #
  search: ->
    @empty()
    @scroll.loadNextPage()

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
        item = new TranslationItem(this, translation, @options)
        previousItem.next = item if previousItem?
        item.build().appendTo @list
        @items.push item
        previousItem = item
    @list.find(".translation-area").autosize()

  # @private
  makeURL: -> 
    @url + "?" + @filter.serialize()
