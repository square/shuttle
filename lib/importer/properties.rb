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

require 'strscan'

module Importer

  # Parses translatable strings from Java .properties files.

  class Properties < Base
    def self.fencers() %w(MessageFormat) end

    protected

    def import_file?
      ::File.basename(file.path) =~ /#{(Regexp.escape(base_rfc5646_locale)).sub('-', '_')}\.properties$/
    end

    def import_strings
      file.contents.scan(/^(.+?)=(.+)$/u).each do |(key, value)|
        add_string key, value
      end
    end
  end
end
