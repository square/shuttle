# Worker that locates any cached manifests that would be affected by an updated
# Translation, and expires those manifests. This worker is used if a
# Translation's copy is updated but it remains approved, thus the Commit's
# readiness is not affected, thus the normal Commit hooks are not run.

class TranslationCachedManifestExpirer
  include Sidekiq::Worker

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
