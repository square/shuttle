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
  # Exports the translated strings of a KeyGroup to a json representation.

  class KeyGroup
    # Initializes the importer with the given `key_group`.
    # Caches the sorted keys which include their respective translations.
    # Caches the sorted translations by locale.

    def initialize(key_group)
      @key_group = key_group
      @sorted_keys = @key_group.sorted_active_keys_with_translations
      @sorted_translations_indexed_by_locale = @sorted_keys.map do |key|
        key.translations.index_by { |t| t.locale }
      end # Array<Hash<Locale, Translation>> ---> [{ Locale('es') ->  Translation(of key1), Locale('fr') -> Translation(of key1) }, { Locale('es') ->  Translation(of key2), Locale('fr') -> Translation(of key2) }]
    end

    # Exports Translations for KeyGroup in every requested locale as long as
    #   - the requested locales are valid locales,
    #   - the requested locales are among the required locales of this KeyGroup,
    #   - the KeyGroup is not ready
    #
    # @param [Array<Locale|String>] locales An array of {Locale Locales} or rfc5646 String representations
    #     of {Locale Locales}.
    # @return [Hash<String, String>] A hash of locales' rfc5646 to translation in that locale
    # @raise [InputError] If given `locales` array is empty, or contains an unknown locale, or
    #     at least one of the `locales` is not a required locale of the KeyGroup
    # @raise [NotReadyError] If KeyGroup is not ready

    def export(locales = @key_group.required_locales)
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
        raise InputError.new("Inputted locale '#{locale.rfc5646}' is not one of the required locales for this key group.") unless @key_group.required_locales.include?(locale)
      end

      raise NotReadyError unless @key_group.ready?

      locales.inject({}) do |hsh, locale|
        hsh[locale.rfc5646] = export_locale(locale)
        hsh
      end
    end

    private

    # Assumes locale is valid and required in this key_group
    #
    # @return [String] concatenated translation copies in the right order, for the given `locale`,
    #     i.e. KeyGroup's source_copy's translation in the given locale
    # @raise [MissingTranslation] If there is at least one required translation that is missing

    def export_locale(locale)
      copies = @sorted_translations_indexed_by_locale.map.with_index do |locales_hsh, index|
        translation = locales_hsh[locale]
        raise MissingTranslation.new("Missing translation in locale #{locale} for key #{@sorted_keys[index]}") unless translation # Q: why do this check? A: key.recalculate_ready? doesn't verify all translation records exist.
        translation.copy
      end
      copies.join
    end

    # ======== START ERRORS ==============================================================================================
    class Error < StandardError; end
    class NotReadyError < Error; end # Raised when a KeyGroup is not marked as ready.
    class MissingTranslation < Error; end # Raised when a Translation was missing during export.
    class InputError < Error; end
    # ======== END ERRORS ================================================================================================
  end
end
