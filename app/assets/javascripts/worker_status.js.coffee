
$(document).ready((->
  checkWorkerStatus = ->
    $.ajax("/queue_status", $.extend({}, cache: false))
      .done( (data) ->
        if data == 'idle'
          text = "Workers Idle"
          color = "#AAFFAA"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'working'
          text = "Workers Busy"
          color = "#FFFFAA"
          text_color = "#777777"
          shadow = "0 1px 0 #FFFFFF"
        else if data == 'heavy'
          text = "Workers Swamped"
          color = "#FFAAAA"
          text_color = "#666666"
          shadow = "0 1px 0 #AAAAAA"

        $('.worker-status a').text(text)
        $('.worker-status').css({background: color, color: text_color, textShadow: shadow})
      );

  minPerQuery = 1
  setInterval(checkWorkerStatus , 60 * 1000 * minPerQuery)
  checkWorkerStatus()
));
