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

module Fencer

  # Fences out `printf()` interpolation tokens, as used in Objective-C .strings
  # files (such as "%s"). See {Fencer}.

  module Printf
    extend self

    def fence(string)
      tokens  = Hash.new { |hsh, k| hsh[k] = [] }
      PrintfTokenizer.tokenize(string) do |type, value, range|
        next unless type == :token
        tokens[value] << range
      end

      return tokens
    end
  end
end
