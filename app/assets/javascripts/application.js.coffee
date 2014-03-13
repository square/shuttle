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
#= require jquery-cookie
#= require jquery_ujs
#= require jquery-timers
#= require jquery-leanModal
#= require jquery-qtip
#= require jquery-chosen
#= require jquery-highlighter
#= require purl
#= require datepicker
#= require twitter/typeahead
#= require modernizr
#= require xregexp
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
#
#= require_tree ../templates
#= require_tree ./application 

$(document).ready ->
  $('.filter-bar').affix(0, { shadow: true }) if $('.filter-bar').length > 0
  # enable leanModal on all modal links
  $("a[rel*=modal]").leanModal closeButton: ".close"
  $("button[rel*=modal]").leanModal closeButton: ".close"
  $("textarea.resize").autosize()
