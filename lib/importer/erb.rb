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

module Importer

  # Parses translatable strings from localized text-based ERb files.

  class Erb < Base
    def self.fencers() %w(Erb) end

    protected

    def import_file?
      ::File.basename(file.path) =~ /\.#{Regexp.escape base_rfc5646_locale}\..+?\.erb$/
    end

    def import_strings
      # build a key that's the file name less the locale
      path       = ::File.dirname(file.path)
      name_parts = ::File.basename(file.path).split('.')
      ext        = name_parts.pop
      output_ext = name_parts.pop
      _locale    = name_parts.pop
      key        = "#{path}/#{name_parts.join('.')}.#{output_ext}.#{ext}"

      fencers = self.class.fencers
      fencers << 'Html' if ::File.basename(file.path) =~ /\.html\.erb$/
      add_string key, file.contents, fencers: fencers
    end
  end
end
