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

# Manager class for the glossary list view.
#
class root.GlossaryList

  # Creates a new glossary list manager.
  # 
  # @param [jQuery element] glossaryTable The table jQuery element that will
  #   soon contain the glossary table.
  # @param [String] glossaryUrl The URL from which we can pull all glossary
  #   entries.
  # @param [String] addSourceEntryUrl The URL to POST to that adds a new source
  #   entry to the glossary.
  # @param [String] localesUrl The URL to GET that retrieves a list of all
  #   locales along with their flags.
  # @param [Array] sourceLocale The locale of all source entries.
  # @param [Array] targetLocale The locales that we want to view translated 
  #   entries in.
  # @param [jQuery element] settingsModal The jQuery element that contains an
  #   uninitialized settings modal.
  # @param [jQuery element] addEntryModal The jQuery element that contains an
  #   uninitialized add-entry modal.
  # @param [String] userRole The role of the user (monitor/translator/etc.)
  # @param [Array] approvedLocales An array of the locales the user is approved
  #   to translate in.
  #
  constructor: (
      @glossaryTable, @glossaryUrl, @addSourceEntryUrl, 
      @sourceLocale, @targetLocales,
      @settingsModal, @addEntryModal,
      @userRole, @approvedLocales) ->
    if $.cookie('glossaryList_sourceLocale')?
      @sourceLocale = Locale.from_rfc5646($.cookie('glossaryList_sourceLocale'))
    else
      @sourceLocale = Locale.from_rfc5646(@sourceLocale)
    if $.cookie('glossaryList_targetLocales')?
      @targetLocales = JSON.parse($.cookie('glossaryList_targetLocales'))
    else
      @targetLocales = @approvedLocales

    setup = =>
      this.setupAddTermModal()
      this.setupSettingsFormModal()
      this.reloadGlossary()

    setup() if window.localesLoaded
    $(document).bind 'locales_loaded', setup

  # Flashes an error at the top of the screen.
  # 
  # @param [String] message The message that will be flashed.
  #
  error: (message) ->
    new Flash('alert').text(message)

  # @private
  setupGlossary: ->
    headerRow = $('<tr/>').appendTo($('<thead/>').appendTo(@glossaryTable)).append('<th/>')
    $('<div/>').text(@sourceLocale.name()).appendTo($('<th/>').appendTo(headerRow))
    for rfc5646 in @targetLocales
      localeEntry = Locale.from_rfc5646(rfc5646)
      $('<div/>').text(localeEntry.name()).appendTo($('<th/>').appendTo(headerRow))
    for letter in '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
      glossaryAnchor = $('<tbody/>', 
        id: 'glossary-table-' + letter,
        class: 'glossary-table-anchor'
      ).appendTo(@glossaryTable)
      glossaryAnchor.append($('<tr/>').append($('<td/>').append($('<strong/>').text(letter))))

  # @private
  setupAddTermModal: =>
    @addEntryModal.find("input[name='source_glossary_entry[due_date]']").datepicker
      startDate: new Date()
      autoclose: true
      todayBtn: 'linked'
    # @addEntryModal.find("input[name='source_glossary_entry[source_copy]']").jqBootstrapValidation
    #   preventSubmit: true
    #   filter: -> 
    #     return $(this).is(':visible')
      
    @addEntryModal.find('form').submit () =>
      $.ajax @addSourceEntryUrl, 
        type: 'POST'
        data: @addEntryModal.find('form').serialize()
        success: => this.loadGlossaryEntries()
        error: =>
          this.error("Couldn’t add new term.")
          this.loadGlossaryEntries()
      @addEntryModal.closeModal()
      return false

  # @private
  setupSettingsFormModal: =>
    # @settingsModal.find("#glossary_target_locales").attr("data-value", "#{JSON.stringify(@targetLocales)}")

    @settingsModal.find("#glossary_target_locales").arrayField(
      renderer: (container, name, value) ->
        text_field = $('<input/>').attr('type', 'text')
                                  .attr('name', name)
                                  .attr('placeholder', "Locale")
                                  .addClass('locale-field')
                                  .val(value)
        text_field.appendTo container
        new LocaleField(text_field)
        return text_field
    )

    @settingsModal.find("button.save").click => 
      @targetLocales = $.map( 
        @settingsModal.find(".locale-field"), 
        (field) -> 
          return $(field).val() 
      ).filter(
        (locale) ->
          locale != ""
      )

      $.cookie('glossaryList_sourceLocale', @sourceLocale.rfc5646(), { expires: 1 })
      $.cookie('glossaryList_targetLocales', JSON.stringify(@targetLocales), { expires: 1 })

      $("#lean_overlay").fadeOut(200)
      @settingsModal.css({ 'display': 'none' })
      this.reloadGlossary()
      return false

  # @private
  loadGlossaryEntries: => 
    $('.glossary-table-entry').remove()
    $.ajax @glossaryUrl,
      type: 'GET'
      success: (glossaryEntries) =>
        for sourceEntry in glossaryEntries.reverse()
          do (sourceEntry) =>
            switch @userRole
              when 'admin' then isTranslator = true
              when 'reviewer', 'translator'
                if @approvedLocales.indexOf(sourceEntry.source_locale) > -1                
                  isTranslator = true
                else 
                  isTranslator = false  
              else 
                isTranslator = false
            
            context = 
              source_id: sourceEntry.id
              num_locales: @targetLocales.length + 2
              source_copy: sourceEntry.source_copy
              source_context: sourceEntry.context
              source_notes: sourceEntry.notes
              source_edit_url: sourceEntry.edit_source_entry_url
              is_translator: isTranslator
              translated_copies: []
            for rfc5646 in @targetLocales
              localeEntry = Locale.from_rfc5646(rfc5646)
              switch @userRole
                when 'admin'
                  isTranslator = true
                  isReviewer = true
                when 'reviewer'
                  if @approvedLocales.indexOf(localeEntry.rfc5646()) > -1
                    isTranslator = true
                    isReviewer = true
                  else 
                    isTranslator = false  
                    isReviewer = false
                when 'translator'
                  if @approvedLocales.indexOf(localeEntry.rfc5646()) > -1
                    isTranslator = true
                  else 
                    isTranslator = false  
                  isReviewer = false
                else 
                  isTranslator = false
                  isReviewer = false

              localeContext =
                copy: ''
                notes: ''
                locale: localeEntry.rfc5646()
                is_translator: isTranslator
                is_reviewer: isReviewer
                add_url: sourceEntry.add_locale_entry_url
              if sourceEntry.locale_glossary_entries[localeEntry.rfc5646()]?
                lge = sourceEntry.locale_glossary_entries[localeEntry.rfc5646()]
                localeContext.locale_id   = lge.id
                localeContext.copy        = lge.copy
                localeContext.notes       = lge.notes
                localeContext.edit_url    = lge.edit_locale_entry_url
                localeContext.approve_url = lge.approve_url
                localeContext.reject_url  = lge.reject_url

                if lge.translated
                  approved = lge.approved
                  if approved == true
                    localeContext.entry_state = "text-success"
                    localeContext.approved = true
                    localeContext.rejected = false
                  else if approved == false
                    localeContext.entry_state = "text-error"
                    localeContext.approved = false
                    localeContext.rejected = true
                  else 
                    localeContext.entry_state = "text-info"
                    localeContext.approved = false
                    localeContext.rejected = false
              context.translated_copies.push(localeContext)

            firstLetter = sourceEntry.source_copy.substr(0, 1).toUpperCase()
            if firstLetter.match(/[A-Z]/)
              $('#glossary-table-' + firstLetter)
                .after($(HoganTemplates['glossary/glossary_entry'].render(context)))
            else 
              $('#glossary-table-\\#')
                .after($(HoganTemplates['glossary/glossary_entry'].render(context)))

        for domLocaleEntry in $('.glossary-table-locale-entry')
          locale = $(domLocaleEntry).data('locale') 
          localeId = $(domLocaleEntry).data('localeId') 
          addLocaleEntryUrl = $(domLocaleEntry).data('addUrl') 
          editLocaleEntryUrl = $(domLocaleEntry).data('editUrl')
          approveLocaleEntryUrl = $(domLocaleEntry).data('approveUrl')
          rejectLocaleEntryUrl = $(domLocaleEntry).data('rejectUrl') 

          $(domLocaleEntry).find(".glossary-table-edit-locale").click(((addLocaleEntryUrl, editLocaleEntryUrl, locale, localeId) ->
            return () ->
              if localeId
                window.location.href = editLocaleEntryUrl
              else 
                $.ajax addLocaleEntryUrl,
                  type: "POST"
                  dataType: "json"
                  data: 
                    locale_glossary_entry:
                      rfc5646_locale: locale
                  success: (newEntry, textStatus, jqXhr) =>
                    window.location.href = jqXhr.getResponseHeader("location")
          )(addLocaleEntryUrl, editLocaleEntryUrl, locale, localeId))

          $(domLocaleEntry).find(".glossary-table-approve-locale").click(((domLocaleEntry, addLocaleEntryUrl, approveLocaleEntryUrl, locale, localeId) ->
            return () ->
              $(domLocaleEntry).find(".glossary-table-reject-locale").prop('disabled', false)
              $(domLocaleEntry).find(".glossary-table-approve-locale").prop('disabled', true)
              if localeId
                $.ajax approveLocaleEntryUrl,
                  type: "PATCH"
                  success: () ->
                    $(domLocaleEntry).parents(".glossary-table-entry").find("." + locale + "-copy")
                      .hide().removeClass("text-info text-error").addClass("text-success").fadeIn(500)
          )(domLocaleEntry, addLocaleEntryUrl, approveLocaleEntryUrl, locale, localeId))

          $(domLocaleEntry).find(".glossary-table-reject-locale").click(((domLocaleEntry, addLocaleEntryUrl, rejectLocaleEntryUrl, locale, localeId) ->
            return () ->
              $(domLocaleEntry).find(".glossary-table-reject-locale").prop('disabled', true)
              $(domLocaleEntry).find(".glossary-table-approve-locale").prop('disabled', false)
              if localeId
                $.ajax rejectLocaleEntryUrl,
                  type: "PATCH"
                  success: () ->
                    $(domLocaleEntry).parents(".glossary-table-entry").find("." + locale + "-copy")
                      .hide().removeClass("text-info text-success").addClass("text-error").fadeIn(500)
          )(domLocaleEntry, addLocaleEntryUrl, rejectLocaleEntryUrl, locale, localeId))

        @glossaryTable.find("input, textarea, button, a").click (e) ->
          e.stopPropagation()

        new TableAccordion(@glossaryTable)

      error: => this.error "Couldn’t load glossary list."
    return false

  # Reloads the glossary by emptying the glossary table and setting it up again.
  #
  reloadGlossary: =>
    @glossaryTable.empty()
    this.setupGlossary()
    this.loadGlossaryEntries()
