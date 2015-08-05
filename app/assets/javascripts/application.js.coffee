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

# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
#
# WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
# GO AFTER THE REQUIRES BELOW.
#
#= require jquery
#= require jquery-ui
#= require jquery-autosize
#= require jquery-chosen
#= require jquery-cookie
#= require jquery_ujs
#= require jquery-timers
#= require jquery-leanModal
#= require jquery-qtip
#= require jquery-highlight
#= require jquery-highlighter
#= require jquery-prettyTextDiff
#= require jquery-gallery
#= require jquery-scrollTo
#= require jquery-swipebox
#= require purl
#= require datepicker
#= require twitter/typeahead
#= require modernizr
#= require xregexp
#= require diff_match_patch.js
#= require spin.js
#= require dropzone
#
#= require d3
#= require nvd3
#
#= require hogan
#= require utilities
#
#= require buttons
#= require dynamic_search_field
#= require data_source_builder
#= require fencer
#= require infinite_scroll
#= require live_update
#= require smart_form
#= require scroll_to_with_data_attrs
#= require selectize
#= require selectize_with_defaults
#= require select2

#
#= require_tree ../templates
#= require_tree ./application

Dropzone.autoDiscover = false

$(document).ready ->
  # enable leanModal on all modal links
  $("button[rel*=modal]").leanModal closeButton: ".close"
  $("textarea.resize").autosize()

  $(".tooltip-parent").each () ->
    tooltip_settings = {
      content:
        text: $($(this).data("tooltip"))
      position:
        my: 'center left'
        at: 'center right'
      show: 'mouseenter'
      hide: 'mouseleave'
    }

    if $(this).data('tooltip-show')
      tooltip_settings.show = $(this).data('tooltip-show')
    if $(this).data('tooltip-hide')
      tooltip_settings.hide = $(this).data('tooltip-hide')
    if $(this).data('tooltip-position-at')
      tooltip_settings.position.at = $(this).data('tooltip-position-at')
    if $(this).data('tooltip-position-my')
      tooltip_settings.position.my = $(this).data('tooltip-position-my')

    $(this).qtip(tooltip_settings)