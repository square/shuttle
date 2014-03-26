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


$(document).ready((->
  $('.worker-status.clickable').click () ->
    window.location = "/sidekiq"

  checkWorkerStatus = ->
    $.ajax("/queue_status", $.extend({}, cache: false))
      .done( (data) ->
        if data == 'idle'
          klass = 'worker-status-idle'
        else if data == 'working'
          klass = 'worker-status-busy'
        else if data == 'heavy'
          klass = 'worker-status-swamped'

        $('.worker-status').addClass(klass)
      );

  minPerQuery = 1
  setInterval(checkWorkerStatus , 60 * 1000 * minPerQuery)
  checkWorkerStatus()
));
