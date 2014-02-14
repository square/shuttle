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

# Table Accordion class for the glossary list view.
#
class root.TableAccordion
  constructor: (@element, @options) ->
    @options ||= {
      closeOthers: true
    }

    @animation_time = 400

    @element.find(".accordion-body").hide()
    @element.find(".accordion-body").find("td > div").hide()
    @element.find(".accordion-toggle").click (e) =>
      accordion_toggle = $(e.currentTarget)
      accordion_target = $(accordion_toggle.data("target"))

      if accordion_toggle.hasClass("active") 
        this.collapseTarget(accordion_target, accordion_toggle)
      else 
        if @options.closeOthers 
          this.closeOthers()
        this.expandTarget(accordion_target, accordion_toggle)

  expandTarget: (target, toggle) ->
    toggle.addClass("active")
    target.show()

    target.find("td > div").slideDown( 
      @animation_time, 
      () ->
        $(this).show()
    )

  collapseTarget: (target, toggle) ->
    target.find("td > div").slideUp( 
      @animation_time, 
      () ->
        $(this).hide()

        toggle.removeClass("active")
        target.hide()
    )

  closeOthers: ->
    $.each @element.find(".accordion-toggle.active"), (i, toggle_element) => 
      accordion_toggle = $(toggle_element)
      accordion_target = $($(accordion_toggle).data("target"))
      this.collapseTarget(accordion_target, accordion_toggle)
