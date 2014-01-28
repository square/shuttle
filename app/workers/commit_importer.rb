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

# Calls {Commit#import_strings}.

class CommitImporter
  include Sidekiq::Worker
  sidekiq_options queue: :high

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit.
  # @param [Hash] options Additional options.
  # @option options [String] locale The RFC 5646 code of a locale to import
  #   existing translations from. If `nil`, the base locale is imported as
  #   base translations.

  def perform(commit_id, options={})
    locale = options[:locale] ? Locale.from_rfc5646(options[:locale]) : nil

    commit = Commit.find(commit_id)
    commit.import_strings(locale: locale)
  end

  include SidekiqLocking
end
