# Copyright 2016 Square Inc.
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
      @glossaryTable,
      @addSourceEntryUrl,
      @sourceLocale,
      @targetLocales,
      @settingsModal,
      @addEntryModal,
      @approvedLocales) ->
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
      this.setupGlossaryRows()

    setup() if window.localesLoaded
    $(document).bind 'locales_loaded', setup

  # Flashes an error at the top of the screen.
  #
  # @param [String] message The message that will be flashed.
  #
  error: (message) ->
    new Flash('alert').text(message)

  # @private
  setupAddTermModal: =>
    @addEntryModal.find("input[name='source_glossary_entry[due_date]']").datepicker
      startDate: new Date()
      autoclose: true
      todayBtn: 'linked'

    @addEntryModal.find('form').submit () =>
      $.ajax @addSourceEntryUrl,
        type: 'POST'
        data: @addEntryModal.find('form').serialize()
        success: => this.loadGlossaryEntries()
        error: =>
          this.error("Couldn’t add new term.")
          this.loadGlossaryEntries()
      @addEntryModal.closeModal()
      window.location = 'glossary'
      return false

  # @private
  setupSettingsFormModal: =>
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

    @settingsModal.find("button.save-target-locales").click =>
      @targetLocales = $.map(
        @settingsModal.find(".locale-field"),
        (field) ->
          return $(field).val()
      ).filter(
        (locale) ->
          locale != ""
      )
      window.location = 'glossary?target_locales=' + @targetLocales
      return false

  setupGlossaryRows: =>
    @animation_time = 200
    @glossaryTable.on 'click', 'tr.glossary-row-header', () ->
      $detailSection = $(@).siblings('tr.glossary-row-detail')
      $detailSectionContent = $detailSection.find('td > div')
      wasActive = $(@).hasClass('active')

      if wasActive
        $(@).removeClass('active')
        $detailSectionContent.slideUp(@animation_time, () -> $detailSection.hide())
      else
        $(@).addClass('active')
        $detailSection.show()
        $detailSectionContent.slideDown(@animation_time)

    @glossaryTable.find('.locale-section').each (i, domLocaleEntry) =>
      approveLocaleEntryUrl = $(domLocaleEntry).data('approve-url')
      rejectLocaleEntryUrl = $(domLocaleEntry).data('reject-url')

      $approveLocaleButton = $(domLocaleEntry).find('.glossary-approve-locale')
      $rejectLocaleButton = $(domLocaleEntry).find('.glossary-reject-locale')

      $approveLocaleButton.on 'click', =>
        $approveLocaleButton.prop('disabled', true)

        # Send the approve glossary entry URL request and undisable the buttons on success
        $.ajax approveLocaleEntryUrl,
          type: "PATCH"
          success: ->
            $rejectLocaleButton.prop('disabled', false)
            $(domLocaleEntry).parents('.glossary-row').find('glossary-row-header-source-entry')
              .hide().removeClass('text-info text-error').addClass('text-success').fadeIn(500)
          error: ->
            # TODO: We should add in some messaging here that it failed.
            $approveLocaleButton.prop('disabled', false)

      $rejectLocaleButton.on 'click', =>
        $rejectLocaleButton.prop('disabled', true)

        # Send the reject glossary entry URL request and undisable the buttons on success
        $.ajax rejectLocaleEntryUrl,
          type: "PATCH"
          success: ->
            $approveLocaleButton.prop('disabled', false)
            $(domLocaleEntry).parents('.glossary-row').find('glossary-row-header-source-entry')
              .hide().removeClass('text-info text-success').addClass('text-error').fadeIn(500)
          error: ->
            # TODO: We should add in some messaging here that it failed.
            $rejectLocaleButton.prop('disabled', false)