# Copyright 2013 Square Inc.
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
