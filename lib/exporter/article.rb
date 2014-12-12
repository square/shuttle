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

module Exporter
  # Exports the translated strings of an Article to a json representation.

  class Article
    # Initializes the importer with the given `article`.
    # Caches the sorted keys which include their respective translations.
    # Caches the sorted translations by locale.

    def initialize(article)
      @article = article
      @sections_hash = {}
      # Hash<Section, Hash<Key, Hash<Locale, Translation>>> --->
      # { Section1 -> { Key1 -> { Locale('es') -> Translation(of key1 in 'es'),
      #                           Locale('fr') -> Translation(of key1 in 'fr') },
      #               { Key2 -> { Locale('es') -> Translation(of key2 in 'es'),
      #                           Locale('fr') -> Translation(of key2 in 'fr') } },
      # { Section2 -> { Key3 -> { Locale('es') -> Translation(of key3 in 'es'),
      #                           Locale('fr') -> Translation(of key3 in 'fr') },
      #               { Key4 -> { Locale('es') -> Translation(of key4 in 'es'),
      #                           Locale('fr') -> Translation(of key4 in 'fr') } },

      article.active_sections.each do |section|
        @sections_hash[section] = section.sorted_active_keys_with_translations.reduce({}) do |memo, key|
          memo[key] = key.translations.index_by { |t| t.locale }
          memo
        end
      end
    end

    # Exports Translations for Article in every requested locale as long as
    #   - the requested locales are valid locales,
    #   - the requested locales are among the required locales of this Article,
    #   - the Article is ready
    #
    # @param [Array<Locale|String>] locales An array of {Locale Locales} or rfc5646 String representations
    #     of {Locale Locales}.
    # @return [Hash<String, String>] A hash of locales' rfc5646 to translation in that locale
    # @raise [InputError] If given `locales` array is empty, or contains an unknown locale, or
    #     at least one of the `locales` is not a required locale of the Article
    # @raise [NotReadyError] If Article is not ready

    def export(locales = @article.required_locales)
      raise InputError.new("No Locale(s) Inputted") unless locales.present?

      if locales.is_a? String
        locales = locales.split(",").map(&:strip).map do |rfc5646|
          locale = Locale.from_rfc5646(rfc5646)
          raise InputError.new("Locale '#{rfc5646}' could not be found.") unless locale
          locale
        end
      end

      # check if all requested locales are among the required locales
      locales.each do |locale|
        raise InputError.new("Inputted locale '#{locale.rfc5646}' is not one of the required locales for this article.") unless @article.required_locales.include?(locale)
      end

      raise NotReadyError unless @article.ready?

      locales.inject({}) do |hsh, locale|
        hsh[locale.rfc5646] = export_locale(locale)
        hsh
      end
    end

    private

    # Assumes locale is valid and required in this Article
    #
    # @return [String] concatenated translation copies in the right order, for the given `locale`,
    #     i.e. Article's source_copy's translation in the given locale
    # @raise [MissingTranslation] If there is at least one required translation that is missing

    def export_locale(locale)
      @sections_hash.keys.reduce({}) do |memo, section|
        memo[section.name] = export_section_locale(section, locale)
        memo
      end
    end

    def export_section_locale(section, locale)
      @sections_hash[section].map do |key, locales_hsh|
        translation = locales_hsh[locale]
        raise MissingTranslation.new("Missing translation in locale #{locale} for key #{key}") unless translation # Q: why do this check? A: key.recalculate_ready? doesn't verify all translation records exist.
        translation.copy
      end.join
    end

    # ======== START ERRORS ==============================================================================================
    class Error < StandardError; end
    class NotReadyError < Error; end # Raised when an Article is not marked as ready.
    class MissingTranslation < Error; end # Raised when a Translation was missing during export.
    class InputError < Error; end
    # ======== END ERRORS ================================================================================================
  end
end
