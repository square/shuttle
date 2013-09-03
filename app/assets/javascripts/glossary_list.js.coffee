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

#TODO: this should probably be abstracted out to share code.
class root.GlossaryList
  currentLocale: 'en'
  # TODO: @availableLocalesOrAdmin, @updateEntryUrl
  constructor: (
      @glossaryTable, @glossaryUrl, @localesUrl,
      @editSourceEntryUrl, @editLocaleEntryUrl, 
      @settingsModal, @addTermForm, @addTermUrl, 
      @isTranslator, @isReviewer, @approvedLocales) ->

    # Defaults source/target locales
    @sourceLocale = {
        flagUrl: "/assets/country-flags/en.png"
        locale: "English"
        rfc: "en"
      }
    @targetLocales = [
      {
        flagUrl: "/assets/country-flags/fr.png"
        locale: "French"
        rfc: "fr"
      },
      {
        flagUrl: "/assets/country-flags/jp.png"
        locale: "Japanese"
        rfc: "ja"
      },
      {
        flagUrl: "/assets/country-flags/es.png"
        locale: "Spanish"
        rfc: "es"
      },
      {
        flagUrl: "/assets/country-flags/de.png"
        locale: "German"
        rfc: "de"
      },
    ]

    this.setupGlossary()
    this.setupAddTermModal()
    this.setupSettingsFormModal()
    this.loadGlossaryEntries()

  error: (message) ->
    flash = $('<p/>').addClass('alert alert-error').text(message).hide().appendTo($('#flashes')).slideDown()
    $('<a/>').addClass('close').attr('data-dismiss', 'alert').text('×').appendTo flash
    flash.delay(4000).slideUp () -> flash.remove()

  setupGlossary: ->
    headerRow = $('<tr/>').appendTo($('<thead/>').appendTo(@glossaryTable)).append('<th/>')
    $('<div/>').text(@sourceLocale.locale).appendTo($('<th/>').appendTo(headerRow))
    # TODO: Check length of foreignLocales
    for localeEntry in @targetLocales
      $('<div/>').text(localeEntry.locale).appendTo($('<th/>').appendTo(headerRow))
    for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('')
      ## TODO: Possibly move this to a HBS template
      glossaryAnchor = $('<tbody/>', 
        id: 'glossary-table-' + letter,
        class: 'glossary-table-anchor'
      ).hide().fadeIn().appendTo(@glossaryTable)
      glossaryAnchor.append($('<tr/>').append($('<td/>').append($('<h3/>').text(letter))))

  setupAddTermModal: =>
    $('#add-term-inputDueDate').datepicker
      startDate: new Date()
      autoclose: true
      todayBtn: "linked"
    $('#add-term-inputEnglish').jqBootstrapValidation
      preventSubmit: true
      filter: -> 
        return $(this).is(":visible")
      
    @addTermForm.submit () => 
      $.ajax @addTermUrl, 
        type: "POST"
        dataType: "json",
        data: 
          source_glossary_entry:
            source_copy: $('#add-term-inputEnglish').val()
            context: $('#add-term-inputContext').val()
            notes: $('#add-term-textAreaNotes').val()
            source_rfc5646_locale: "en"
            # due_date: $('#add-term-inputDueDate').val()
        success: (data) =>
          this.loadGlossaryEntries()
        error: (xhr) =>
          #           if not added
            # this.error("Duplicate term!")  
          this.error("Couldn't add new term!")
          this.loadGlossaryEntries()
      $('#add-term-modal').modal('hide')
      return false

  setupSettingsFormModal: =>
    flashSettingsWarning = (warning) -> 
      $('#settings-modal .help-block').fadeOut () -> 
        $('#settings-modal .help-block').text(warning).css('color', 'red').fadeIn().delay(800).fadeOut () -> 
          $('#settings-modal .help-block').text(' • Press Enter to add a new locale').css('color', 'green').fadeIn()

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

        $('#settings-inputTarget').removeAttr('disabled')
        $('#settings-submit').removeAttr('disabled')

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
      $('#settings-modal').modal('hide')
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
          ## Create on click problem...
          do (sourceEntry) =>
            isTranslator = true
            isReviewer = true
            console.log(sourceEntry)
            context = 
              entry_id: 'glossary-table-entry-' + i++
              num_locales: @targetLocales.length + 2
              source_copy: sourceEntry.source_copy
              source_context: sourceEntry.context
              source_notes: sourceEntry.notes
              source_edit_url: @editSourceEntryUrl.replace("REPLACEME_SOURCE", sourceEntry.id)
              is_translator: isTranslator
              is_reviewer: isReviewer
              translated_copies: []
            for localeEntry in @targetLocales
              isTranslator = true
              isReviewer = true

              if localeEntry.rfc of sourceEntry.locale_glossary_entries
                context.translated_copies.push
                  copy: sourceEntry.locale_glossary_entries[localeEntry.rfc].copy,
                  notes: sourceEntry.locale_glossary_entries[localeEntry.rfc].notes
                  is_translator: isTranslator
                  is_reviewer: isReviewer
                  locale_edit_url: @editLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceEntry.id).replace("REPLACEME_LOCALE", sourceEntry.locale_glossary_entries[localeEntry.rfc].id)
              else
                # CREATE A NEW ONE.
                context.translated_copies.push
                  copy: ''
                  notes: ''
                  is_translator: isTranslator
                  is_reviewer: isReviewer
                  locale_edit_url: @editLocaleEntryUrl.replace("REPLACEME_SOURCE", sourceEntry.id).replace("REPLACEME_LOCALE", localeEntry.id)
            $('#glossary-table-' + sourceEntry.source_copy.substr(0, 1).toUpperCase())
              .after($(HoganTemplates['glossary/glossary_entry'].render(context)).hide().fadeIn())

        ## TODO: Add functionality if is reviewer
        # if @isReviewer
        @glossaryTable.find("input, textarea, button, a").click (e) -> 
          e.stopPropagation()

      error: =>
        this.error("Couldn't load glossary list!")
    return false

  reloadGlossary: =>
    @glossaryTable.empty()
    this.setupGlossary()
    this.loadGlossaryEntries()
