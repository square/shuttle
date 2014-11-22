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

# A concern for {Commit} that records errors that happen during commit importing.

module ImportErrors
  extend ActiveSupport::Concern

  included do
    # The format to store import errors is [Array<Pair<String, String>>]
    # The first string of the pair is error class name, other is the error message.
    # Ex: [["IncorrectSha", "BlobImporter couldn't find your sha"]]
    serialize :import_errors, Array

    extend SetNilIfBlank
    set_nil_if_blank :import_errors # easier to query to check for `nil` rows

    # Find commits which errored during an import
    scope :errored_during_import, -> { where("import_errors IS NOT NULL") }
  end

  # Adds an import error to a commit
  #   @param [Error] err The error object.
  #   @param [String] addition_message The error message to record in addition to the
  #       actual error message. If provided, it will be added to the end, in paranthesis.

  def add_import_error(err, addition_message = nil)
    message = addition_message ? "#{err.message} (#{addition_message})" : err.message
    # Since another worker might be adding errors as well, we should reload to get the most up-to-date data.
    # However, instead of calling `reload` on self, load a new commit instance in order to
    # preserve dirty attributes/changes out of respect to observers.
    existing_import_errors = Commit.find(self.id).import_errors
    update_column :import_errors, existing_import_errors.push([err.class.to_s, message])
  end

  # Removes all previous import errors postgres.
  def clear_import_errors!
    update!(import_errors: nil)
  end

  # Returns `true` if no import errors exist on this commit.
  #
  # @return [true, false] Whether there are any errors associated with this commit.

  def errored_during_import?
    import_errors.present?
  end
end
