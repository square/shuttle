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

$(document).ready ->
    # A simple helper function which shows and hides some elements when
    # a button is clicked in the issues section of the page.
    $(document).on 'click', '#issues form .cancel-button', (event) ->
        form_wrapper = $(@).closest('.form-wrapper')
        form_wrapper.hide()
        form_wrapper.siblings('.show-issue-wrapper').show()
        form_wrapper.siblings('.show-form-button').show()
        preventDefaultAndStopPropagation(event)

    $(document).on 'click', '#issues .show-form-button', (event) ->
        btn = $(@)
        btn.hide()
        btn.siblings('.show-issue-wrapper').hide()
        $(@).siblings('.form-wrapper').show()
        preventDefaultAndStopPropagation(event)

########################################################################################################################

    # Adds an overlay over the wrapper to prevent UI interaction with wrapper.
    # Adds a spinner to the overlay.
    addLoadingOverlay = (submit_button) ->
      wrapper = $(submit_button).closest('.loading-overlayable')
      wrapper.children().addClass('overlayed')
      overlay = $('<div>').addClass('loading-overlay')
      wrapper.append(overlay);

      spinner = new Spinner(color: '#336077', length: 0, trail: 20, radius: 30, width: 10, speed: 2).spin();
      overlay.append(spinner.el);

    $(document).on 'click', '#issues .loading-overlayable input[type=submit]', (event) ->
      addLoadingOverlay(@)

########################################################################################################################

    # If the url contains an anchor is something like "...#issue-wrapper-12?...",
    # finds the add comment form within that anchor, and imitates a click on it
    # This is used when we guess that user might be interested in writing a comment more than usual.
    showAddCommentFormIfIssueAnchorExistsInUrl = () ->
      anchor_and_params = document.location.toString().split("#")[1];
      if anchor_and_params
        anchor_value = anchor_and_params.split("?")[0];
        $('#' + anchor_value).closest('.issue-wrapper').find(".comments .show-form-button").click()

    showAddCommentFormIfIssueAnchorExistsInUrl()

########################################################################################################################

    # Selectize subscribed_emails field
    userSearchUrl = $('#issues').data('search-url')
    autoFillEnabled = $('#issues').data('auto-fill')

    selectizeSubscribedEmails = (elt) ->
        $(elt).find('input.issue-subscribed-emails').selectizeWithDefaults({
                    create: true,
                    openOnFocus: false,
                    selectOnTab: true,
                    createOnBlur: true,
                    delimiter: ', ',
                    valueField: 'email',
                    labelField: 'email',
                    searchField: ['name', 'email'],
                    loadThrottle: 100,
                    maxOptions: 5,
                    render: {
                            item: (item, escape) ->
                                '<div>' +
                                    (if item.name then '<span class="name">' + escape(item.name) + '</span>' else '') +
                                    (if item.email then '<span class="email">' + escape(item.email) + '</span>' else '') +
                                '</div>';
                            ,
                            option: (item, escape) ->
                                label = item.name || item.email;
                                caption = if item.name then item.email else null;
                                '<div>' +
                                    '<span class="label">' + escape(label) + '</span>' +
                                    (if caption then '<span class="caption">' + escape(caption) + '</span>' else '') +
                                '</div>';
                            },
                    load: (query, callback) ->
                            return callback() if query.length < 2
                            $.ajax({
                                url: userSearchUrl + '?query=' + encodeURIComponent(query),
                                type: 'GET',
                                dataType: 'json',
                                error: () -> callback(),
                                success: (res) -> callback(res)
                            }) if autoFillEnabled
                    ,
                    createFilter: (input) ->
                        match = input.match(/^\S+@\S+\.\S+$/)
                        if match then !this.options.hasOwnProperty(match[0]) else false
        })

    # Subscribe to 'render' events in #issues so that we can re-selectize email fields after an issue is created or updated
    $(document).on('render', '#issues .issue-form', (event) -> selectizeSubscribedEmails(this))
    # Manually trigger 'render' event on all issue forms to set up selectized email fields after a full page reload
    $('#issues .issue-form').trigger('render')
