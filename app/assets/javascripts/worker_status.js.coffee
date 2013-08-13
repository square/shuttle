
$(document).ready((->
  checkWorkerStatus = ->
    $.ajax("/queue_status", $.extend({}, cache: false))
      .done( (data) ->
        if data == 'idle' && false
          color = "#AAFFAA"
          text = "Workers Idle"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'working'
          color = "#FFFFAA"
          text = "Workers Busy"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'heavy' || true
          color = "#FFAAAA"
          text = "Workers Swamped"
          text_color = "#666666"
          shadow = "0 1px 0 #AAAAAA"

        $('.worker-status').text(text)
        $('.worker-status').css("background", color)
        $('.worker-status').css("color", text_color)
        $('.worker-status').css("text-shadow", shadow)
      );

  setInterval(checkWorkerStatus , 5 * 1000)
  checkWorkerStatus()
));
