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

# Note that this requires qTip and jQuery

$(document).ready( ->
  if (!Modernizr.formvalidation)
    validate_form = (form) ->
      invalid = false
      focused = false
      $.each $(form).find("input:required"), (index, field) ->
        if !$(field).val()
          invalid = true

          $(field).focus() if !focused
          focused = true

          $(field).addClass("alert")
          $(field).qtip(
            content:
              text: "This field is required"
            position:
              my: 'bottom left'
              at: 'top right'
            hide: ''
            style: { classes: 'qtip-red' }
          ).qtip("show")
          $(field).keypress ->
            $(this).removeClass("alert")
            $(this).qtip("destroy")

      return false if invalid

    $("input[type='submit']").click ->
      validate_form $(this).closest("form")

    $(document).on 'leanModal.hidden', ->
      $("input:required").removeClass("alert")
      $("input:required").qtip("destroy")
);
