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

module Localizer

  # @abstract
  #
  # Generic localizer that exports strings imported from the
  # {Importer::Plaintext Plaintext importer}. Given a string imported from a
  # file such as `javascript/templates/hello.en-US.mustache`, will export a
  # localized file such as `javascript/templates/hello.fr-FR.mustache`.
  # Subclasses of this class specify the extension to use (in this case,
  # `.mustache`).
  #
  # Localized variants are placed in the same directory as the source file.

  class Plaintext < Base
    abstract!

    # @return [String] The file extension (including dot) this localizer uses.
    cattr_accessor :extension
    self.extension = nil

    def self.localizable?(project, key)
      key.source.end_with?(".#{project.base_rfc5646_locale}#{extension}")
    end

    def localize(input_file, output_file, locale)
      translation = @translations.detect { |t| t.key.key == '/' + input_file.path } or return

      output_file.path    = input_file.path.sub(/\.#{Regexp.escape @project.base_rfc5646_locale}#{Regexp.escape self.class.extension}/,
                                                ".#{locale.rfc5646}#{self.class.extension}")
      output_file.content = translation.copy
    end
  end
end
