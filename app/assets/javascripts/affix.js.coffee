do ($ = window.jQuery) ->
  $.fn.affix = (offsetTop = 0, options) ->
    affixTop = this.offset().top
    affixWidth = this.width()

    $(window).scroll =>
      windowTop = $(window).scrollTop()
      if affixTop < windowTop
        this.addClass("shadow") if options['shadow']
        this.css
          position: 'fixed'
          width: affixWidth
          top: offsetTop
      else
        this.removeClass("shadow")
        this.css
          position: 'static'
    return this