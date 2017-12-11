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

  # @abstract
  #
  # Imports entire files as localizable content. The full contents of the file
  # is taken as the localizable string. The file must include the project's base
  # locale and the appropriate extension in the name (e.g.,
  # `hello.en-US.mustache`). Subclasses supply the extension to use (`.mustacce`
  # in this example).

  class Plaintext < Base
    abstract!

    # @return [String] The file extension (including dot) this importer uses.
    cattr_accessor :extension
    self.extension = nil

    protected

    def import_file?
      file.path.end_with?(".#{base_rfc5646_locale}#{extension}")
    end

    def import_strings
      add_string file.path, file.contents
    end
  end
end
