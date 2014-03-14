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

# An overview panel that administrators can use to track the progress of
# localization efforts, add new SHAs to import, and modify project settings.
#
class root.StatusPanel

  # Constructs a new status panel manager for an element. Renders the status
  # panel into that element.
  #
  # @param [jQuery element] element The element to contain the status panel.
  # @param [String] projects_url A URL that returns a JSON-serialized list of
  #   projects.
  #
  constructor: (@element, @dataSource) ->
    @element.infiniteScroll @dataSource,
      renderer: (projects) => @renderProjects projects

  # @private
  renderProjects: (projects) ->
    for project in projects
      do (project) =>
        cell = $('<div/>').addClass('project-cell').appendTo(@element)
        new Project(project, cell)

# @private
class Project
  constructor: (@project, @element) ->
    summary = @renderSummary().appendTo(@element)
    details = @renderDetails().appendTo(@element).hide()
    summary.find('a.toggle').click ->
      summary.hide()
      details.show()
    details.find('a.toggle').click ->
      details.hide()
      summary.show()
    @reload()

  reload: ->
    @dynamic_portion.empty()
    loading = $('<p/>').addClass('loading').appendTo(@dynamic_portion)
    $('<i/>').addClass('fa fa-spinner spinning').appendTo loading

    $.ajax "#{@project.url}.json",
      success: (project) =>
        @dynamic_portion.empty()
        @renderCommits project.commits
      error: =>
        @dynamic_portion.empty()
        $('<i/>').addClass('fa fa-exclamation-circle').appendTo @dynamic_portion

  renderSummary: ->
    div = $('<div/>').addClass('project-summary')
    @renderHeader().appendTo div
    div

  renderDetails: ->
    div = $('<div/>').addClass('project-details')
    @renderHeader().appendTo div
    @dynamic_portion = $('<div/>').appendTo(div)
    @renderFooter().appendTo div
    div

  renderHeader: ->
    h1 = $('<h1/>')
    $('<a/>').text(' ' + @project.name).addClass('toggle').appendTo h1
    @renderButtons().appendTo h1
    h1

  renderFooter: ->
    div = $('<div/>')
    footer = $('<form/>').
      addClass('form-inline').
      attr({action: @project.commits_url, method: 'POST'}).
      text("Localize a commit: ").
      appendTo(div)
    sha = $('<input/>').addClass('input-small').attr('type', 'text').appendTo(footer).attr
      name: 'commit[revision]'
      placeholder: 'SHA'
      maxlength: 40
    footer.append ' '
    $('<input/>').attr({type: 'submit', value: 'Add'}).addClass('btn btn-primary btn-small').appendTo footer
    new SmartForm footer, (xhr) =>
      @reload()
      success_div = $('<div/>').addClass('alert alert-success').text(xhr.message).insertBefore(footer)
      $('<a/>').addClass('close').attr('data-dismiss', 'alert').html('&times;').prependTo success_div
      sha.val ''
    div

  renderButtons: ->
    buttons = $('<span/>').addClass('buttons pull-right')
    edit = $('<a/>').attr({href: @project.edit_url, title: 'Edit'}).appendTo(buttons)
    $('<i/>').addClass('fa fa-pencil-square-o').appendTo edit
    buttons

  renderCommits: (commits) ->
    for commit in commits
      do (commit) =>
        commitDiv = $('<div/>').addClass('commit').appendTo @dynamic_portion
        new Commit(this, commit, commitDiv)

# @private
class Commit
  constructor: (@project, @commit, @element) ->
    summary = @renderSummary().appendTo(@element)
    details = @renderDetails().appendTo(@element).hide()

    summary.click ->
      summary.hide()
      details.show()
    details.find('a.toggle').click ->
      details.hide()
      summary.show()

    @updateProgress()
    @setRefreshTimer() if @commit.loading || @commit.translations_total == 0

  renderSummary: ->
    @summary_progress = @renderProgress()
    @summary_progress.find('.text-progress').text "#{@commit.revision[0..6]}: #{@commit.message[0..40]}"
    @summary_progress

  renderDetails: ->
    div = $('<div/>').addClass('commit-details')
    h3 = $('<h3/>').appendTo(div)

    header = $('<div/>').appendTo(h3)

    $('<a/>').addClass('fa fa-chevron-up toggle').attr('href', '#').appendTo(header)
    header.append ' '

    link = $('<a/>').text("Commit ").attr({href: @commit.github_url, target: '_blank'}).appendTo(header)
    $('<strong/>').text(@commit.revision[0..6]).appendTo link

    @string_count = $('<span/>').addClass('badge pull-right').appendTo(header)
    @string_count.addClass("ready") if @commit.ready
    $('<span/>').text(" (" + @commit.committed_at[0..9] + ", " + @commit.committed_at[11..15] + ")").appendTo(h3)
    $('<pre/>').text(@commit.message).appendTo div

    @details_progress = @renderProgress().appendTo(div)
    @renderImportForm().appendTo div

    div

  renderProgress: ->
    progress = $('<div/>').addClass('progress')
    $('<div/>').addClass('bar').appendTo progress
    $('<span/>').addClass('text-progress').appendTo(progress)
    progress

  renderImportForm: ->
    importForm = $('<form/>').addClass('form-inline').attr({method: 'POST', action: @commit.import_url})
    label = $('<label/>').text('Import and approve a localization: ').appendTo(importForm)

    localeField = $('<input/>').attr({type: 'text', name: 'locale'}).addClass('locale-field').appendTo(label)
    if window.localesLoaded
      new LocaleField(localeField)
    else
      $(document).bind 'locales_loaded', -> new LocaleField(localeField)

    importForm.append ' '
    $('<input/>').addClass('btn btn-primary').val("Import").attr('type', 'submit').appendTo importForm

    new SmartForm importForm, => @project.reload()
    @renderButtons().appendTo importForm

    importForm


  renderButtons: ->
    buttons = $('<span/>').addClass('pull-right')

    $('<a/>').attr('href', '#').text("Redo Import").addClass('btn btn-mini disable-when-loading').appendTo(buttons).click =>
      $.ajax @commit.redo_url,
             type: 'POST'
             success: => @setRefreshTimer()
             error: -> alert("Couldn’t re-import that commit.")
      false
    buttons.append ' '

    $('<a/>').attr('href', @commit.status_url).addClass('btn btn-mini').text('Status').appendTo buttons
    buttons.append ' '

    $('<a/>').attr({href: @commit.url, 'data-method': 'DELETE', 'data-confirm': "Are you sure you want to delete this commit?"}).addClass('btn btn-mini btn-danger disable-when-loading').text('Delete').appendTo buttons

    buttons

  setRefreshTimer: ->
    @element.everyTime 1000, 'refresh', =>
      $.ajax "#{@commit.url}.json",
        success: (commit) =>
          @commit = commit
          @updateProgress()
          @element.stopTime('refresh') unless @commit.loading

  updateProgress: ->
    @summary_progress.removeClass
    @details_progress.removeClass

    if @commit.loading
      @element.find('.disable-when-loading').attr 'disabled', 'disabled'
      @summary_progress.addClass 'progress-striped progress-warning active'
      @details_progress.addClass 'progress-striped progress-warning active'
    else if @commit.translations_done == @commit.translations_total
      @summary_progress.addClass 'progress-success'
      @details_progress.addClass 'progress-success'
    else
      @element.find('.disable-when-loading').removeAttr 'disabled'

    @string_count.text numberWithDelimiter(@commit.strings_total)
    if @commit.ready
      @string_count.addClass("ready")
    else
      @string_count.removeClass("ready")

    @summary_progress.find('.bar').css('width', "#{if @commit.loading then 100 else @commit.percent_done}%")
    @details_progress.find('.bar').css('width', "#{if @commit.loading then 100 else @commit.percent_done}%")
    @details_progress.find('.text-progress').text "#{numberWithDelimiter @commit.translations_done} / #{numberWithDelimiter @commit.translations_total}"
