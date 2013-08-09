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

$(window).ready ->
  commitSearchForm = $('#commit-search-form')
  commitTable = $('#commits')
  makeCommitURL = -> "#{commitTable.data('url')}?#{commitSearchForm.serialize()}"
  
  commitScroll = commitTable.infiniteScroll makeCommitURL,
    windowScroll: true
    renderer: (commits) ->
      formatTable(commitTable)
      for commit in commits
        do (commit) -> addCommit(commitTable, commit)
    dataSourceOptions: {type: 'GET'}

  commitSearchForm.submit ->
    commitScroll.reset()
    $.ajax commitTable.data('url'),
      data: commitSearchForm.serialize()
      success: (commits) ->
        commitScroll.loadNextPage()
      error: =>
        $('<div/>').addClass('alert alert-error').text("Couldn't load search results").appendTo($('flashes'))
    false

  formatTable = (commitTable) ->
    commitTable.empty()
    thead = $('<thead/>').appendTo(commitTable)
    header = $('<tr/>').appendTo(thead)
    $('<th/>').text('SHA').appendTo(header)
    $('<th/>').text('Project').appendTo(header)
    $('<th/>').text('Status').appendTo(header)


  addCommit = (commitTable, commit) ->
    tr = $('<tr/>').appendTo(commitTable)
    commitTD = $('<td/>').appendTo(tr)
    $('<a/>').text(commit.revision).attr('href', commit.url).appendTo(commitTD)

    $('<br/>').appendTo(commitTD)
    $('<td/>').text(commit.project).appendTo(tr)

    td = $('<td/>').appendTo(tr)
    klass = if commit.ready
      'commit-ready'
    else if commit.loading
      'commit-loading'
    else
      '' # In progress
    td.text(commit.status).addClass(klass).appendTo(tr)


