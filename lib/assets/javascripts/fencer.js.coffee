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

class root.Fencer
  constructor: (@type, @fences) ->

  missingFences: (copy) ->
    missing = []
    for own key, _ of @fences
      do (key) =>
        fence = this.fenceFormat(key)
        return unless fence?
        if fence instanceof RegExp
          missing.push key unless copy.match(fence)
        else
          missing.push key if copy.indexOf(fence) == -1
    return missing

  fenceFormat: (fence) ->
    switch @type
      when 'MessageFormat'
        fence_index = fence.match(/^\{(\d+)[,}]/)[1]
        new RegExp("\\{#{fence_index}(,[^}]+)?\\}")
      when 'Erb', 'Html', 'Strftime'
        # these are all optional fences
        null
      else
        fence
