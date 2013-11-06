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