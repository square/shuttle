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

class root.GlossaryList

  # Constructor method for the Glossary List 
  # 
  # @param [jQuery Element] glossaryTable The table jQuery element that will 
  #   soon contain the glossary table
  # @param [String] glossaryUrl The url from which we can pull all glossary 
  #   entries from
  # @param [String] addSourceEntryUrl The url to add a new source entry to the 
  #   glossary
  # @param [String] localesUrl The url that retrieves a list of all locales 
  #   along with their flag
  # @param [Array] sourceLocale The locale where all source entries derive from
  # @param [Array] targetLocale The locales that we want to view translated 
  #   entries from
  # @param [jQueryElement] settingsModal The jQuery element that contains an
  #   uninitialized settings modal
  # @param [jQueryElement] addEntryModal The jQuery element that contains an 
  #   uninitialized add entry modal
  # @param [String] userRole The role of the user (monitor/translator/etc.)
  # @param [Array] approvedLocales An array of the locales the user is approved
  #   for
  constructor: (
      @glossaryTable, @glossaryUrl, @addSourceEntryUrl, 
      @localesUrl, @sourceLocale, @targetLocales, 
      @settingsModal, @addEntryModal,
      @userRole, @approvedLocales) ->
    if this.readCookie("sourceLocale") != null
      @sourceLocale = JSON.parse(this.readCookie("sourceLocale"))
    if this.readCookie("targetLocales") != null
      @targetLocales = JSON.parse(this.readCookie("targetLocales"))
    this.setupAddTermModal()
    this.setupSettingsFormModal()
    this.reloadGlossary()

  # Flashes an error at the top of the screen.
  # 
  # @param [String] message The message that will be flashed at the top
  error: (message) ->
    flash = $('<p/>').addClass('alert alert-error').text(message).hide().appendTo($('#flashes')).slideDown()
    $('<a/>').addClass('close').attr('data-dismiss', 'alert').text('×').appendTo flash


  # Sets up the glossary within the glossary table div
  setupGlossary: ->
    headerRow = $('<tr/>').appendTo($('<thead/>').appendTo(@glossaryTable)).append('<th/>')
    $('<div/>').text(@sourceLocale.locale).appendTo($('<th/>').appendTo(headerRow))
    for localeEntry in @targetLocales
      $('<div/>').text(localeEntry.locale).appendTo($('<th/>').appendTo(headerRow))
    for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('')
      glossaryAnchor = $('<tbody/>', 
        id: 'glossary-table-' + letter,
        class: 'glossary-table-anchor'
      ).hide().fadeIn().appendTo(@glossaryTable)
      glossaryAnchor.append($('<tr/>').append($('<td/>').append($('<h3/>').text(letter))))

  # Sets up the add term modal by enabling the date picker and the 
  # validator.
  setupAddTermModal: =>
    $('#add-entry-inputDueDate').datepicker
      startDate: new Date()
      autoclose: true
      todayBtn: "linked"
    $('#add-entry-inputEnglish').jqBootstrapValidation
      preventSubmit: true
      filter: -> 
        return $(this).is(":visible")
      
    @addEntryModal.find("form").submit () => 
      $.ajax @addSourceEntryUrl, 
        type: "POST"
        dataType: "json"
        data: @addEntryModal.find("form").serialize()
        success: (data) =>
          this.loadGlossaryEntries()
        error: (jqXHR) =>
          this.error("ERROR: Couldn't add new term!")
          this.loadGlossaryEntries()
      @addEntryModal.modal('hide')
      return false

  # Sets up the settings modal by retrieving all locales from @localesUrl and 
  # rendering them within the typeahead
  setupSettingsFormModal: =>
    flashSettingsWarning = (warning) -> 
      $('#settings-modal .help-block span').fadeOut () -> 
        $('#settings-modal .help-block span').text(warning)
          .removeClass('text-success').addClass('text-error').fadeIn().delay(800).fadeOut () -> 
            $('#settings-modal .help-block span').text(' • Press Enter to add a new locale')
              .removeClass('text-error').addClass('text-success').fadeIn()

    localesDict = {}

    newTargetLocales = []
    newUniqueLocales = {en: ''}

    $.ajax @localesUrl,
      success: (data) ->
        for localeEntry in data
          localesDict[localeEntry.rfc] = 
            rfc: localeEntry.rfc
            locale: localeEntry.locale
            flagUrl: localeEntry.flagUrl

        $('#settings-btn').removeAttr('disabled')

        $('#settings-inputTarget').typeahead
          name: 'locales'
          local: data # prefetch: '/locales/remote' # To debug, use incognito mode.  Remember this stores in cache.
          template: '<img src=\"{{flagUrl}}\" style=\"float: right;\"><p><strong>{{rfc}}</strong> - {{locale}}</p>'
          engine: Hogan

        $('#settings-inputTarget').keypress (e) -> 
          if e.which == 13
            newRfc = $('#settings-inputTarget').val().split(' ')[0]
            if newRfc not of localesDict
              flashSettingsWarning('• Invalid locale!')
              $('#settings-inputTarget').typeahead('setQuery', '')
              return false

            if newRfc of newUniqueLocales
              flashSettingsWarning('• Duplicate locale!')
              $('#settings-inputTarget').typeahead('setQuery', '')
              return false

            newTargetLocales.push(localesDict[newRfc])
            newUniqueLocales[newRfc] = ''

            $("#settings-listTargets").append(
              $(HoganTemplates['glossary/settings_locale_entry'].render(localesDict[newRfc])).hide().fadeIn()
            )
            $('#settings-listTargets > li:last-child > button.removeLocale').click () -> 
              deleteRfc = newTargetLocales.splice($(this).parent().index(), 1)[0].rfc
              delete newUniqueLocales[deleteRfc]
              $(this).parent().fadeOut(300, () -> $(this).remove())
              
            $('#settings-inputTarget').typeahead('setQuery', '')
            return false
        
    $('#settings-submit').click () =>
      @targetLocales = newTargetLocales
      newTargetLocales = []
      newUniqueLocales = {en: ''}
      $("#settings-listTargets").empty()
      @settingsModal.modal('hide')
      this.createCookie("sourceLocale", JSON.stringify(@sourceLocale), 1);
      this.createCookie("targetLocales", JSON.stringify(@targetLocales), 1);
      this.reloadGlossary()

  # Loads the glossary entries and appends them to the glossary table
  loadGlossaryEntries: => 
    $('.glossary-table-entry').remove()
    $.ajax @glossaryUrl,
      type: "GET"
      dataType: "json"
      success: (glossaryEntries) =>
        for sourceEntry in glossaryEntries.reverse()
          do (sourceEntry) =>
            switch @userRole
              when "admin" then isTranslator = true
              when "reviewer", "translator" 
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
            for localeEntry in @targetLocales
              switch @userRole
                when "admin"
                  isTranslator = true
                  isReviewer = true
                when "reviewer" 
                  if @approvedLocales.indexOf(localeEntry.rfc) > -1                
                    isTranslator = true
                    isReviewer = true
                  else 
                    isTranslator = false  
                    isReviewer = false
                when "translator"
                  if @approvedLocales.indexOf(localeEntry.rfc) > -1                
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
                locale: localeEntry.rfc
                is_translator: isTranslator
                is_reviewer: isReviewer
                add_url: sourceEntry.add_locale_entry_url
              if localeEntry.rfc of sourceEntry.locale_glossary_entries
                localeContext.locale_id = sourceEntry.locale_glossary_entries[localeEntry.rfc].id
                localeContext.copy = sourceEntry.locale_glossary_entries[localeEntry.rfc].copy
                localeContext.notes = sourceEntry.locale_glossary_entries[localeEntry.rfc].notes
                localeContext.edit_url = sourceEntry.locale_glossary_entries[localeEntry.rfc].edit_locale_entry_url
                localeContext.approve_url = sourceEntry.locale_glossary_entries[localeEntry.rfc].approve_url
                localeContext.reject_url = sourceEntry.locale_glossary_entries[localeEntry.rfc].reject_url

                if sourceEntry.locale_glossary_entries[localeEntry.rfc].translated
                  approved = sourceEntry.locale_glossary_entries[localeEntry.rfc].approved
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

            newGlossaryEntry = $('#glossary-table-' + sourceEntry.source_copy.substr(0, 1).toUpperCase())
              .after($(HoganTemplates['glossary/glossary_entry'].render(context)).hide().fadeIn())
            console.log(newGlossaryEntry)

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

      error: =>
        this.error("Couldn't load glossary list!")
    return false

  # Reloads the glossary by emptying the glossary table and setting it up 
  # again.
  reloadGlossary: =>
    @glossaryTable.empty()
    this.setupGlossary()
    this.loadGlossaryEntries()

  # Creates a cookie with a given `name` and `value` and stores it for `days` 
  # days.
  # 
  # @param [String] name The name that can be used to retrieve the cookie
  # @param [String] value The value that will be stored in the cookie
  # @param [Integer] days The number of days that the cookie will be stored for
  createCookie: (name, value, days) ->
    if (days) 
      date = new Date()
      date.setTime(date.getTime() + (days*24*60*60*1000))
      expires = "; expires=" + date.toGMTString()
    else
      expires = ""
    document.cookie = name + "=" + value + expires + "; path=/"

  # Reads a cookie with a given `name`
  # 
  # @param [String] name The name that will be used to search for a cookie
  readCookie: (name) ->
    nameEQ = name + "="
    for c in document.cookie.split(';')
      while c.charAt(0) == ' '
        c = c.substring(1, c.length)
      if c.indexOf(nameEQ) == 0
        return c.substring(nameEQ.length, c.length)
    return null

  # Erases a cookie with a given `name`
  # 
  # @param [String] name The name that will be used to search for a cookie
  eraseCookie: (name) ->
    createCookie(name, "", -1)
