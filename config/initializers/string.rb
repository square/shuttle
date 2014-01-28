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

class String

  # http://stackoverflow.com/questions/9528035/ruby-stringscan-equivalent-to-return-matchdata
  #
  # Adds the ability to return multiple MatchDatas for a regexp that matches
  # more than once.

  def matches(re)
    start_at = 0
    matches  = []
    while (m = match(re, start_at))
      matches.push(m)
      start_at = m.end(0)
    end
    matches
  end
end
