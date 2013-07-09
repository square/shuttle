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

#TODO this should probably be abstracted out to share code.
class root.GlossaryList
  currentLocale: 'en'

  error: (message) ->
    flash = $('<p/>').addClass('alert alert-error').text(message).appendTo($('#flashes'))
    $('<a/>').addClass('close').attr('data-dismiss', 'alert').text('×').appendTo flash

  loadLocale: (locale) =>
    if (@availableLocalesOrAdmin != 'admin' &&
          $.inArray(locale, @availableLocalesOrAdmin) == -1 &&
          locale != "en")
      this.error("Locale is unavailable.")
      return false
    this.currentlocale = locale

    $('<i/>').addClass('icon-refresh spinning').appendTo @localeForm
    $.ajax @glossaryUrl.replace('REPLACEME', locale),
      complete: => @localeForm.find('i').remove()
      success: (glossaryEntries) =>
        @glossaryDiv.empty()
        for entry in glossaryEntries
          do (entry) =>
            tr = $('<div/>').addClass('row').appendTo(@glossaryDiv)
            td1 = $('<div/>').addClass('span6').append($("<div/>").addClass("well").text(entry.source_copy)).appendTo(tr)
            existingEntryForm = $('<form/>').append($('<input/>').val(entry.copy)).submit ->
              $.ajax @updateEntryUrl.replace('REPLACEME_LOCALE', locale).replace("REPLACEME_ID", entry.id),
                data: {review: false, copy: $(this).find('input').val()},
                type: "PATCH"
                success: (data) ->
                  # on success, reload
                  this.loadLocale(locale)
              false

            if entry.approved
              existingEntryForm.find('input').attr('disabled','disabled')
            else

            td2 = $('<div/>').addClass('span6').append($('<div/>').addClass('well').append(existingEntryForm)).appendTo(tr)

            # only add the buttons if they should be able to see them
            if @isReviewer
              buttons = $('<span />').addClass('buttons').appendTo(td2.find('.well'))
              # make the buttons do everything they need to.
              btn1 = $('<button/>').addClass('btn btn-mini').append($('<i/>').addClass('icon icon-ok'))
              btn1.click =>
                $.ajax @updateEntryUrl.replace('REPLACEME_LOCALE', locale).replace("REPLACEME_ID", entry.id),
                  data: {review: true, approved: true, copy: existingEntryForm.find('input').val()},
                  type: "PATCH"
                  success: (data) =>
                    # on success, reload
                    this.loadLocale(locale)
                false
              btn1.appendTo buttons
              btn2 = $('<button/>').addClass('btn btn-danger btn-mini').append($('<i/>').addClass('icon icon-remove'))
              btn2.click =>
                $.ajax @updateEntryUrl.replace('REPLACEME_LOCALE', locale).replace("REPLACEME_ID", entry.id),
                  data: {review: true, approved: false, copy: existingEntryForm.find('input').val()},
                  type: "PATCH"
                  success: (data) =>
                    # on success, reload
                    this.loadLocale(locale)
                false
              btn2.appendTo buttons
      error: =>
        this.error("Couldn’t load project list.")
    return false

  constructor: (@localeForm, @glossaryDiv, @glossaryUrl, @newEntryForm,
    @newEntryUrl, @isTranslator, @isReviewer, @availableLocalesOrAdmin,
    @updateEntryUrl) ->
    @newEntryForm.submit =>
      $('<i/>').addClass('icon-refresh spinning').appendTo @newEntryForm
      $.ajax @newEntryUrl,
        data: @newEntryForm.serialize()
        type: "POST",
        complete: => @newEntryForm.find('i').remove()
        success: (success) =>
          this.loadLocale(this.currentLocale)
      return false

    # I don't know why coffeescript makes me do this...
    localeForm = @localeForm
    @localeForm.submit =>
      this.loadLocale(@localeForm.serializeObject().locale)
