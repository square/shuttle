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
  # Parameters
  # ----------
  # 
  # |                         |                                                             |
  # |:------------------------|:------------------------------------------------------------|
  # | `glossaryTable`         | Div that contains the glossary table                        |
  # | `glossaryUrl`           | URL to retrieve all source glossary entries                 |
  # | `localesUrl`            | URL to retrieve all locales                                 |
  # | `sourceLocale`          | The initial source locale                                   |
  # | `targetLocales`         | The initial target locales                                  |
  # | `addSourceEntryUrl`     | URL to add a new source entry                               |
  # | `addLocaleentryUrl`     | URL to add a new locale entry                               |
  # | `editSourceEntryUrl`    | URL to update an existing source entry                      |
  # | `editLocaleEntryUrl`    | URL to update an existing locale entry                      |
  # | `approveLocaleEntryUrl` | URL to approve an existing locale entry                     |
  # | `rejectLocaleEntryUrl`  | URL to reject an existing locale entry                      |
  # | `settingsModal`         | Div that contains the modal to modify settings              |
  # | `addEntryModal`         | Div that contains the modal to add a new entry              |
  # | `userRole`              | The current user's role (monitor/translator/reviewer/admin) |
  # | `approvedLocales`       | The current user's approved locales to modify               |

  constructor: (
      @glossaryTable, @glossaryUrl, 
      @localesUrl, @sourceLocale, @targetLocales, 
      @addSourceEntryUrl, @addLocaleEntryUrl,
      @editSourceEntryUrl, @editLocaleEntryUrl, 
      @approveLocaleEntryUrl, @rejectLocaleEntryUrl
      @settingsModal, @addEntryModal,
      @userRole, @approvedLocales) ->
    if this.readCookie("sourceLocale") != null
      @sourceLocale = JSON.parse(this.readCookie("sourceLocale"))
    if this.readCookie("targetLocales") != null
      @targetLocales = JSON.parse(this.readCookie("targetLocales"))
      
    this.setupGlossary()
    this.setupAddTermModal()
    this.setupSettingsFormModal()
    this.loadGlossaryEntries()

  # Flashes an error at the top of the screen.
  # 
  # Parameters
  # ----------
  # |           |                                             |
  # |:----------|:--------------------------------------------|
  # | `message` | The message that will be flashed at the top |

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

  # Sets up the add term modal by enabling the date picker and the validator.

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

  # Sets up the settings modal by retrieving all locales from @localesUrl and rendering them
  # within the typeahead

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

  loadGlossaryEntries: => 
    $('.glossary-table-entry').remove()
    ## TODO: Add loading animation http://fgnass.github.io/spin.js/
    $.ajax @glossaryUrl,
      type: "GET"
      dataType: "json"
      complete: => 
        ## TODO: Remove loading animation
      success: (glossaryEntries) =>
        i = 0
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
              source_edit_url: @editSourceEntryUrl.replace("REPLACEME_SOURCE", sourceEntry.id)
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
              if localeEntry.rfc of sourceEntry.locale_glossary_entries
                localeContext.locale_id = sourceEntry.locale_glossary_entries[localeEntry.rfc].id
                localeContext.copy = sourceEntry.locale_glossary_entries[localeEntry.rfc].copy
                localeContext.notes = sourceEntry.locale_glossary_entries[localeEntry.rfc].notes

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

        for domLocaleEntry in $('.glossary-table-locale-entry')
          localeID = $(domLocaleEntry).data('localeId') 
          sourceID = $(domLocaleEntry).data('sourceId') 
          locale = $(domLocaleEntry).data('locale') 

          $(domLocaleEntry).find(".glossary-table-edit-locale").click(((addLocaleEntryUrl, editLocaleEntryUrl, localeID, sourceID, locale) ->
            return () ->
              if localeID
                window.location.href = editLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", localeID)
              else 
                $.ajax addLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID),
                  type: "POST"
                  dataType: "json"
                  data: 
                    locale_glossary_entry:
                      rfc5646_locale: locale
                  success: (newEntry) =>
                    window.location.href = editLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", newEntry.id)
                    console.error(xhr)
          )(@addLocaleEntryUrl, @editLocaleEntryUrl, localeID, sourceID, locale))

          $(domLocaleEntry).find(".glossary-table-approve-locale").click(((domLocaleEntry, addLocaleEntryUrl, editLocaleEntryUrl, approveLocaleEntryUrl, localeID, sourceID, locale) ->
            return () ->
              $(domLocaleEntry).find(".glossary-table-reject-locale").prop('disabled', false)
              $(domLocaleEntry).find(".glossary-table-approve-locale").prop('disabled', true)
              if localeID
                $.ajax approveLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", localeID),
                  type: "PATCH"
                  success: () ->
                    $(domLocaleEntry).parents(".glossary-table-entry").find("." + locale + "-copy")
                      .hide().removeClass("text-info text-error").addClass("text-success").fadeIn(500)
              else 
                $.ajax addLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID),
                  type: "POST"
                  dataType: "json"
                  data: 
                    locale_glossary_entry:
                      source_glossary_entry_id: sourceID
                      rfc5646_locale: locale
                  success: (newEntry) =>
                    $.ajax approveLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", localeID),
                      type: "PATCH"
          )(domLocaleEntry, @addLocaleEntryUrl, @editLocaleEntryUrl, @approveLocaleEntryUrl, localeID, sourceID, locale))

          $(domLocaleEntry).find(".glossary-table-reject-locale").click(((domLocaleEntry, addLocaleEntryUrl, editLocaleEntryUrl, rejectLocaleEntryUrl, localeID, sourceID, locale) ->
            return () ->
              $(domLocaleEntry).find(".glossary-table-reject-locale").prop('disabled', true)
              $(domLocaleEntry).find(".glossary-table-approve-locale").prop('disabled', false)
              if localeID
                $.ajax rejectLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", localeID),
                  type: "PATCH"
                  success: () ->
                    $(domLocaleEntry).parents(".glossary-table-entry").find("." + locale + "-copy")
                      .hide().removeClass("text-info text-success").addClass("text-error").fadeIn(500)
              else 
                $.ajax addLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID),
                  type: "POST"
                  dataType: "json"
                  data: 
                    locale_glossary_entry:
                      source_glossary_entry_id: sourceID
                      rfc5646_locale: locale
                  success: (newEntry) =>
                    $.ajax rejectLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceID).replace("REPLACEME_LOCALE", localeID),
                      type: "PATCH"
          )(domLocaleEntry, @addLocaleEntryUrl, @editLocaleEntryUrl, @rejectLocaleEntryUrl, localeID, sourceID, locale))

        @glossaryTable.find("input, textarea, button, a").click (e) -> 
          e.stopPropagation()

      error: =>
        this.error("Couldn't load glossary list!")
    return false

  # Reloads the glossary by emptying the glossary table and setting it up again.

  reloadGlossary: =>
    @glossaryTable.empty()
    this.setupGlossary()
    this.loadGlossaryEntries()

  # Creates a cookie with a given `name` and `value` and stores it for `days` days.
  # 
  # Parameters
  # ----------
  # |         |                                                       |
  # |:--------|:------------------------------------------------------|
  # | `name`  | The name that can be used to retrieve the cookie      |
  # | `value` | The value that will be stored in the cookie           |
  # | `days`  | The number of days that the cookie will be stored for |

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
  # Parameters
  # ----------
  # |        |                                                   |
  # |:-------|:--------------------------------------------------|
  # | `name` | The name that will be used to search for a cookie |

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
  # Parameters
  # ----------
  # |        |                                                   |
  # |:-------|:--------------------------------------------------|
  # | `name` | The name that will be used to search for a cookie |

  eraseCookie: (name) ->
    createCookie(name, "", -1)
