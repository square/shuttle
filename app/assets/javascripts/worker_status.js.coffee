
$(document).ready((->
  checkWorkerStatus = ->
    $.ajax("/queue_status", $.extend({}, cache: false))
      .done( (data) ->
        if data == 'idle' && false
          text = "Workers Idle"
          color = "#AAFFAA"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'working'
          text = "Workers Busy"
          color = "#FFFFAA"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'heavy' || true
          text = "Workers Swamped"
          color = "#FFAAAA"
          text_color = "#666666"
          shadow = "0 1px 0 #AAAAAA"

        $('.worker-status').text(text)
        $('.worker-status').css({background: color, color: text_color, textShadow: shadow})
      );

  setInterval(checkWorkerStatus , 5 * 1000)
  checkWorkerStatus()
));
