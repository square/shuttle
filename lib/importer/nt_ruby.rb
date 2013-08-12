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

require 'digest'
module Importer

  # Parses translatable strings from Ruby i18n `.rb` files.

  class NtRuby < NtBase
    def self.fencers() %w(RubyI18n) end

    protected

    def import_file?(locale=nil)
      ::File.extname(file.path) == '.rb' # Import all .rb files?
    end

    def import_strings(receiver)
      nt_call_regex = /[^a-zA-Z0-9_](nt\((?<args>[^)]*)\))/
      string_regex = /"((?:[^\\"]|\\.)*)"|'((?:[^\\']|\\.)*)'/

      file.contents.scan(nt_call_regex) do |match|
        puts match.inspect
        args = match[0]
        message = args.match(string_regex)
        comment = message.post_match.match(string_regex)

        receiver.add_nt_string(key_for_message_comment(message, comment), message, comment)
      end
    end
  end
end
