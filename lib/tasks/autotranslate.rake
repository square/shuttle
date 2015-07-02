namespace :autotranslate do
  desc "Updates touchdown branches"
  task en_gb: :environment do
    Rails.logger.info "[autotranslate:en_gb] Autotranslating en-GB."

    source_locale = Locale.from_rfc5646('en-US')
    target_locale = Locale.from_rfc5646('en-GB')

    word_substitutor = WordSubstitutor.new(source_locale, target_locale)
    untranslated_strings = Translation.in_locale(target_locale).not_translated

    untranslated_strings.includes(:key).each do |translation|
      copy = word_substitutor.substitutions(translation.source_copy).string
      begin
        translation.update!(copy: copy)
      rescue => e
        Rails.logger.info "[autotranslate:en_gb] Autotranslation failed for translation #{translation.id} due to #{e}"
        translation.update(copy: translation.source_copy)
      end
    end

    Rails.logger.info "[autotranslate:en_gb] Autotranslation finished.  #{untranslated_strings.count} strings translated."
  end
end
