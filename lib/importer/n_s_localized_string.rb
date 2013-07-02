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

module Importer

  # Parses translatable strings from `NSLocalizedString` routine calls (and
  # others in the family of routines) in C/Objective-C source files.

  class NSLocalizedString < Base
    def self.fencers() %w(Printf) end

    protected

    def import_file?(locale=nil)
      return false if locale # custom locale imports are not supported
      file.path =~ /\.mm?$/
    end

    def import_strings(receiver)
      Genstrings.new.search(file.contents) do |entry|
        key   = entry[:key]
        value = entry[:value] || entry[:key]
        receiver.add_string "#{file.path}:#{key}:#{entry[:comment]}", value,
                            context:      entry[:comment],
                            original_key: key
      end
    end
  end
end
