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

require 'ripper'
require 'natural_translation/importer/method_finder'

module Importer

  # Parses translatable strings from Ruby `.rb` files.

  class NtErb < NtBase

    def self.fencers() %w(RubyNt) end

    protected

    def import_file?(locale=nil)
      ::File.extname(file.path) == '.erb' # Import all .rb files?
    end

    def import_strings(receiver)
      ruby_locations = Fencer::Erb.fence(file.contents).values.reduce([], :+).sort { |x, y| x.begin <=> y.begin }
      ruby_code = ruby_locations.map { |range|
        file.contents[range].match(/<%[=#\-]?(.*)-?%>/m)
      }.select { |m| m }.map { |m| m[1] }.join("\n")

      MethodFinder.new(ruby_code).args_to("nt").each do |args|
        message, comment = args[0..1]
        receiver.add_nt_string(message, comment)
      end
    end
  end
end
