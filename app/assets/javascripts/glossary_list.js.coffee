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

$(document).ready(()-> 

)

#TODO: this should probably be abstracted out to share code.
class root.GlossaryList
  currentLocale: 'en'
  # TODO: @availableLocalesOrAdmin, @updateEntryUrl
  constructor: (
      @glossaryTable, @glossaryUrl, 
      @sourceLocale, @foreignLocales, 
      @settingsForm, @addTermForm, @addTermUrl, 
      @isTranslator, @isReviewer) ->
    this.setupGlossary()
    this.setupAddTermForm()
    this.loadGlossaryEntries()

  error: (message) ->
    flash = $('<p/>').addClass('alert alert-error').text(message).appendTo($('#flashes'))
    $('<a/>').addClass('close').attr('data-dismiss', 'alert').text('×').appendTo flash

  setupGlossary: ->
    headerRow = $('<tr/>').appendTo($('<thead/>').appendTo(@glossaryTable)).append('<th/>')
    $('<div/>').text(@sourceLocale[0]).appendTo($('<th/>').appendTo(headerRow))
    # TODO: Check length of foreignLocales
    for locale in @foreignLocales
      $('<div/>').text(locale[0]).appendTo($('<th/>').appendTo(headerRow))
    for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('')
      ## TODO: Possibly move this to a HBS template
      glossaryAnchor = $('<tbody/>', 
        id: 'glossary-table-' + letter,
        class: 'glossary-table-anchor'
      ).hide().fadeIn().appendTo(@glossaryTable)
      glossaryAnchor.append($('<tr/>').append($('<td/>').append($('<h3/>').text(letter))))

  setupAddTermForm: =>
    $('#add-term-inputDueDate').datepicker(
      startDate: new Date()
      autoclose: true
      todayBtn: "linked"
      );
    $('#add-term-inputEnglish').jqBootstrapValidation(
      preventSubmit: true
      filter: -> 
        return $(this).is(":visible")
      )
    @addTermForm.submit () => 
      $.ajax @addTermUrl, 
        type: "POST"
        dataType: "json",
        data: 
          source_copy: $('#add-term-inputEnglish').val()
          context: $('#add-term-inputContext').val()
          notes: $('#add-term-textAreaNotes').val()
          due_date: $('#add-term-inputDueDate').val()
        success: (added) =>
          if not added
            this.error("Duplicate term!")  
          this.loadGlossaryEntries()
        error: =>
          this.error("Couldn't add new term!")
          this.loadGlossaryEntries()
      $('#add-term-modal').modal('hide')
      return false

  setupSettingsForm: ->

  loadGlossaryEntries: => 
    $('.glossary-table-entry').fadeOut().remove()
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
            context = 
              entry_id: 'glossary-table-entry-' + i++
              num_locales: @foreignLocales.length + 2
              source_copy: sourceEntry.source_copy
              source_context: sourceEntry.context
              source_notes: sourceEntry.notes
              is_translator: @isTranslator
              is_reviewer: @isReviewer
              translated_copies: []
            for locale in @foreignLocales
              if locale[1] of sourceEntry.locale_glossary_entries
                context.translated_copies.push(
                  copy: sourceEntry.locale_glossary_entries[locale[1]].copy,
                  notes: sourceEntry.locale_glossary_entries[locale[1]].notes
                  )
              else
                context.translated_copies.push(
                  copy: ''
                  notes: ''
                  )
            $('#glossary-table-' + sourceEntry.source_copy.substr(0, 1).toUpperCase())
              .after($(HandlebarsTemplates['glossary_entry'](context)).hide().fadeIn())
        ## TODO: Add functionality if is reviewer
        # if @isReviewer
        @glossaryTable.find("input, textarea").click (e) -> 
          e.stopPropagation()

      error: =>
        this.error("Couldn't load glossary list!")
    return false
