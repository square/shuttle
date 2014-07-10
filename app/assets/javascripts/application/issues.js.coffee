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
