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

do ($ = window.jQuery) ->
  $.fn.affix = (offsetTop = 0, options) ->
    affixTop = this.offset().top
    affixNextElement = this.next()
    affixHeight = this.outerHeight()
    affixWidth = this.width()

    $(window).scroll =>
      windowTop = $(window).scrollTop()
      if affixTop < windowTop
        this.addClass("shadow") if options['shadow']
        affixNextElement.css
          'margin-top': affixHeight
        this.css
          position: 'fixed'
          width: affixWidth
          top: offsetTop
      else
        this.removeClass("shadow")
        affixNextElement.css
          'margin-top': 0
        this.css
          position: 'static'
    return this
