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

# Worker that locates any cached manifests that would be affected by an updated
# Translation, and expires those manifests. This worker is used if a
# Translation's copy is updated but it remains approved, thus the Commit's
# readiness is not affected, thus the normal Commit hooks are not run.

class TranslationCachedManifestExpirer
  include Sidekiq::Worker
  sidekiq_options queue: :low

  # Runs this worker.
  #
  # @param [Integer] translation_id The ID of a {Translation} that was just
  #   updated.

  def perform(translation_id)
    translation = Translation.find(translation_id)
    translation.key.commits.each do |commit|
      Exporter::Base.implementations.each do |exporter|
        Shuttle::Redis.del ManifestPrecompiler.new.key(commit, exporter.request_mime)
      end
      Shuttle::Redis.del LocalizePrecompiler.new.key(commit)
    end
  end

  include SidekiqLocking
end
