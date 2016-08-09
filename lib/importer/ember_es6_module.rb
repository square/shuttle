# Copyright 2016 Square Inc.
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
require 'importer/ember'

module Importer

  # Parses localizable strings from JavaScript files with Ember
  # I18n string hashes.

  class EmberES6Module < Ember
    protected

    def import_file?
      file.path =~ /\/locales\/#{Regexp.escape base_rfc5646_locale}\/translations\.js$/
    end

    def has_translations_for_locale?(_)
      file.contents.include?('export default')
    end

    private

    def extract_hash_from_file(contents, rfc)
      contents.sub! 'export default', 'var out = '
      context = ExecJS.compile contents

      context.eval('out').to_hash
    end
  end
end
