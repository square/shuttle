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
  # @param [Object] translation The translation (loaded from JSON) for this item.

  constructor: (@parent, @translation) ->
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

    # if this is a reviewer edit, fill in the data and show reason modal
    if @parent.enable_reasons && @parent.role == 'reviewer' && @copy_field.val() != @translation.copy
      $('#reason_trigger').click()
      return false

    @saveTranslation(@translation, @element)
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
        @copy_field[0].selectionStart = 0
        @copy_field[0].selectionEnd = match.copy.length


  findFuzzyMatches: ->
    loadFuzzyMatches(@fuzzy_matches, @copy_field, @translation.fuzzy_match_url, @translation.source_copy)


  saveTranslation: (translation, element, reason_ids = [], reason_severity = null) ->
    # find checked locales to which this translation copy should be copied to
    copyToLocales = element.find('.multi-updateable-translations input[type=checkbox]:checked').map(() -> this.value).get()
    element.find('.translation-area, input').attr 'disabled', 'disabled'

    copy = @element.find('.translation-area').val()
    params = (new URL(document.location)).searchParams
    sha = params.get('commit')
    articleId = params.get('article_id')
    assetId = params.get('asset_id')

    ajaxParams = {}
    ajaxParams['translation[copy]'] = copy
    ajaxParams['copyToLocales'] = copyToLocales
    ajaxParams['commit'] = sha
    ajaxParams['reason_ids'] = reason_ids if reason_ids.length
    ajaxParams['reason_severity'] = reason_severity if reason_severity != null
    ajaxParams['article_id'] = articleId if articleId
    ajaxParams['asset_id'] = assetId if assetId

    $.ajax translation.url + '.json',
      type: 'PUT'
      data: $.param(ajaxParams)
      complete: => element.find('.translation-area, textarea').removeAttr 'disabled', 'disabled'
      success: (new_translation) => this.refresh new_translation
      error: (xhr, textStatus, errorThrown) => new Flash('alert').text("Couldn't update that translation. Error: " + $.parseJSON(xhr.responseText));

  # @private
  build: ->
    severity_texts = ['Minor', 'Neutral', 'Major', 'Critical']
    severity_classes = ['badge-success', 'badge-info', 'badge-warning', 'badge-danger']
    context = {}

    context.status = @translation.status
    context.translation_copy = @translation.copy
    context.source_copy = this.renderCopyWithFencing(
                                                      @translation.source_copy,
                                                      @translation.source_fences
                                                    ).html()

    context.multi_updateable_translations_and_locale_associations = @translation.multi_updateable_translations_and_locale_associations

    if @parent.is_group
      context.is_shared = @translation['shared?']
      if @translation.approved && !@parent.edit_approved
        context.read_only_mode = 'read-only-mode'
        context.translation_editing_status = 'disabled'

    if @translation.article_name
      context.article_name = @translation.article_name
    if @translation.article_url
      context.article_url = @translation.article_url

    if @translation.key.context?
      context.context = @translation.key.context

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

    if @translation.changes.length
      # extract the reasons
      reasons = @translation.changes.map (change) ->
        change.reasons.map (reason) ->
          id: reason.id,
          text: "#{reason.category}: #{reason.name}"
      # flatten array of reasons
      reasons = reasons.reduce(((a, b) ->
        a.concat b
      ), [])

      reasons.sort (a,b) ->
        new Date(b.date) - new Date(a.date)

      context.reasons = reasons

      [first, ..., last] = @translation.changes

      if first
        severity = first.reason_severity
        if severity
          context.reason_severity = {
            class_name: severity_classes[severity],
            severity: severity
            severity_text: "Severity: #{severity_texts[severity]}"
          }


    @element = $(HoganTemplates['translationworkbench/translation_item'].render(context))

    @copy_field = @element.find('.translation-area').first()
    @source_copy = @element.find('.source-copy')

    @expand_link_button = @element.find('.expand-link').first()
    @copy_source_button = @element.find('.copy-source').first()

    @alerts = @element.find('div.alerts').first()
    @glossary_tips = @element.find('div.tips').first()
    @fuzzy_matches = @element.find('div.item.fuzzy-matches').first()

    # Set up @source_copy
    @source_copy.highlighter(
      selector: '.highlighter-container'
      minWords: 1
    )

    # Set up @copy_field
    @copy_field.focus () =>
      # select entire range when focused
      @copy_field[0].selectionStart = 0
      @copy_field[0].selectionEnd = @copy_field.val().length
      @loadSuggestion()
      @findFuzzyMatches()
      @hideOtherGlossaryTooltips()
      @renderGlossaryTooltip()

    @copy_field.keydown (e) =>
      # hitting enter saves the field
      if e.keyCode == 13
        # clear all active textareas
        $('textarea.active').removeClass('active');
        # and set this one active
        $(e.currentTarget).addClass('active');

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
      searchParams = (new URL(document.location)).searchParams
      sha = searchParams.get('commit')
      articleId = searchParams.get('article_id')

      url = @translation.edit_url
      url += if sha then "?commit=#{sha}" else "?article_id=#{articleId}"

      window.open url, '_blank'
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
      if @element.find('.source-copy').text().search(term[0]) >= 0
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
  # @param [Array] glossary A JSON-decoded list of glossary entries.
  # @param [String] url of the translations search page
  # @param [Object] JSON of translation information
  # @param [String] role of the current user
  # @param [Boolean] whether or not to show reviewers the reason modal on save
  #
  constructor: (@list, @search_url, @glossary, @translations, @role, @enable_reasons, @edit_approved, @is_group) ->
    @highlighter = $(HoganTemplates['translationworkbench/translation_tooltip'].render())
    @highlighter.find('.tool-item.hide').click =>
      @highlighter.hide()
    @highlighter.find('.tool-item.search').click =>
      if window.getSelection().toString().length > 0
        window.open "#{@search_url}&field=searchable_source_copy&query=#{encodeURIComponent(window.getSelection().toString())}",
          "_blank", 'toolbar=0,location=0,menubar=0,height=800,width=1280,left=0'

    @items = []
    @reasonSeverity = null
    @reasonSeverityClasses = ['badge-success', 'badge-info', 'badge-warning', 'badge-danger']
    @highlighter.appendTo @list
    @addItems @translations
    @setupReasonsModal()

  # @private
  addItems: (translations) ->
    previousItem = null
    for translation, i in translations
      do (translation) =>
        item = new TranslationItem(this, translation)
        previousItem.next = item if previousItem?
        item.build().appendTo @list
        @items.push item
        previousItem = item
    @list.find(".translation-area").autosize()

  setupReasonsModal: ->
    $modal = $('#add-translation-reasons')
    workbench = this

    $('[data-toggle="tooltip"]', $modal).tooltip()
    $('[data-toggle="popover"]', $modal).popover
      html: true
      content: ->
        content = $(this).attr('data-popover-content')
        $(content).children('.popover-body').html()
      title: ->
        title = $(this).attr('data-popover-content')
        $(title).children('.popover-heading').html()

    $('[data-severity]', $modal).on 'click', (event) ->
      event.preventDefault()
      $this = $(this)
      $prev = $this.parent().prev()
      $save_btn = $('.save-btn', $modal)
      $severityLabel = $('#reason-review-popover .popover-body .severity-label')
      $area = $('.translation-area.active').parent().find('.reason-badges')
      severityText = "Severity: #{$this.text()}"

      # set the text and data attr of the button
      $prev.text(severityText)
      $prev.data('severity', $this.data('severity'))

      # update review
      $severityLabel.text(severityText)

      # update the reasonSeverity variable
      workbench.reasonSeverity = $this.data('severity')

      # see if we should update the save button
      $save_btn.removeAttr('disabled') if $('input:checked', $modal).length

      # add the severity badge
      $severityBadge = $('.severity-badge', $area)
      if $severityBadge.length
        $severityBadge.text(severityText)
          .data('severity', workbench.reasonSeverity)
          .removeClass(workbench.reasonSeverityClasses.join(' '))
          .addClass(workbench.reasonSeverityClasses[workbench.reasonSeverity])
      else
        $area.prepend(
          "<span class=\"badge #{workbench.reasonSeverityClasses[workbench.reasonSeverity]} severity-badge\"
          data-severity=\"#{workbench.reasonSeverity}\">#{severityText}</span>"
        )

    $modal.on 'shown.bs.dropdown', ->
      $('#dropdown-search').focus()

    # modal drop-drop down checkboxes
    # handle clicking on a li and checking/unchecking the checkbox
    # and update the UI (badges, review, and button badge (count))
    $('.dropdown-menu li:not(.no-padding)', $modal).on 'click', (event) ->
      $target = $(event.currentTarget)
      $inp = $target.find('input[type=checkbox]')
      return unless $inp.length
      text = $inp.parent().text()
      $area = $('.translation-area.active').parent().find('.reason-badges')
      $btn_badge = $('.reason-btn .badge')
      $review = $('#reason-review-popover .popover-body ul')
      $save_btn = $('.save-btn', $modal)

      setTimeout ->
        $inp.prop 'checked', !$inp.prop('checked')
        checked = $inp.prop('checked')
        if checked
          $save_btn.removeAttr('disabled') if workbench.reasonSeverity != null
          $area.append(
            "<span class=\"badge badge-secondary\"
            data-checkbox=\"#{$inp.val()}\">#{text}</span>"
          )
          $review.append("<li data-checkbox=\"#{$inp.val()}\">#{text}</li>")
          $btn_badge.text(parseInt($btn_badge.text()) + 1)
        else
          item_count = parseInt(parseInt($btn_badge.text()) - 1)
          $save_btn.attr('disabled', 'disabled') unless item_count && workbench.reasonSeverity != null
          $area.find(".badge[data-checkbox='#{$inp.val()}']:not(.saved)").remove()
          $review.find("[data-checkbox='#{$inp.val()}']").remove()
          $btn_badge.text(item_count)
      , 0

      $(event.target).blur()
      false

    $('#dropdown-search').on 'keyup', ->
      search_regex = new RegExp(this.value, 'i')
      $('.dropdown-menu li:not(.no-padding)', $modal).each ->
        $this = $(this)
        string_value = "#{$this.text()} #{$('i', $this).data('original-title')}"
        if search_regex.test string_value
          $(this).fadeIn('fast')
        else
          $(this).fadeOut('fast')

    $('.undo-btn', $modal).on 'click', =>
      $trans = $('.translation-area.active')
      $reasonBadgeArea = $trans.parent().find('.reason-badges')
      $severityBadge = $reasonBadgeArea.find('.severity-badge')

      # handle reason severity
      workbench.reasonSeverity = $('#original_severity').val()
      $severityBadge.text($('#original_severity_text').val())
        .data('severity', workbench.reasonSeverity)
        .removeClass(workbench.reasonSeverityClasses.join(' '))
        .addClass(workbench.reasonSeverityClasses[workbench.reasonSeverity])

      $trans.parent().find('.badge:not(.saved)').remove()
      item = @items.find (item) ->
        item.copy_field.hasClass 'active'
      $trans.val(item.translation.copy)

      # close the modal window
      $('#add-translation-reasons .close').click()

      # update the UI
      $trans.keyup()
      $trans.focus()

    $('.save-btn', $modal).on 'click', =>
      $modal = $('#add-translation-reasons')
      $trans = $('.translation-area.active')

      item = @items.find (item) ->
        item.copy_field.hasClass 'active'

      reason_ids = $('input:checked', $modal).map ->
        this.value

      if reason_ids.length
        item.saveTranslation(item.translation, item.element, reason_ids.toArray(), workbench.reasonSeverity)
        $('.close', $modal).click()
        $trans.keyup()
        $trans.focus()

    $(document).on 'leanModal.shown', ->
      $modal = $('#add-translation-reasons')
      $reasonBadgeArea = $('.translation-area.active').parent().find('.reason-badges')
      $severityBadge = $reasonBadgeArea.find('.severity-badge')
      $badges = $reasonBadgeArea.find('.badge:not(.severity-badge):not(.saved)')
      $btn_badge = $('.reason-btn .badge')
      $review = $('#reason-review-popover .popover-body ul')
      $severityLabel = $('.severity-label', $review)

      if $severityBadge.length
        workbench.reasonSeverity = $severityBadge.data('severity')
        $('.severity-btn', $modal).text($severityBadge.text())
          .data('severity', workbench.reasonSeverity)
        $severityLabel.text($severityBadge.text())
        $('#original_severity').val(workbench.reasonSeverity)
        $('#original_severity_text').val($severityBadge.text())

      $('.save-btn', $modal).removeAttr('disabled') if $badges.length && workbench.reasonSeverity != null

      for badge in $badges
        $modal.find("[value=#{$(badge).data('checkbox')}]").prop 'checked', true
        $btn_badge.text(parseInt($btn_badge.text()) + 1)
        $review.append("<li data-checkbox=\"#{$(badge).data('checkbox')}\">
          #{$(badge).text()}</li>"
        )

    $(document).on 'leanModal.hidden', ->
      $btn_badge = $('.reason-btn .badge')
      $btn_badge.text('0')
      workbench.reasonSeverity = null
      $severityLabel = $('#reason-review-popover .popover-body .severity-label')
      $severityLabel.text('Severity Not Selected')
      $('.severity-btn', $modal).text('Select Severity')
      $('.save-btn', $modal).attr('disabled', 'disabled')
      $('#reason-review-popover .popover-body ul li:not(.severity-label)').remove()
      $('#dropdown-search').val('')
      $('.dropdown-menu li:not(.no-padding)', $modal).fadeIn('fast')
      $('input[type=checkbox]', $modal).prop 'checked', false
