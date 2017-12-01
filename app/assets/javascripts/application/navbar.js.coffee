$('.navbar-toggler').click ->
  $this = $(this)
  target = $this.data('target')
  $target = $('#' + target)

  if $target.hasClass('navbar-collapse')
    $target.removeClass('navbar-collapse')
  else
    $target.addClass('navbar-collapse')

$('.dropdown-toggle').click (e) ->
  e.preventDefault()
  $this = $(this)

  $next = $this.next('.dropdown-menu')

  $('.dropdown-menu').not($next).removeClass('open')

  $next.toggleClass('open')
