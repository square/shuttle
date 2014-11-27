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

# Handles the business logic of translations#update endpoint.
#
# Fields
# ======
#
# |                       |                                                                                           |
# |:----------------------|:------------------------------------------------------------------------------------------|
# | `primary_translation` | primary {Translation} that {User} is attempting to update, ex: from translation workbench |
# | `user`                | {User} who is making the change                                                           |
# | `params`              | params from controller                                                                    |

class TranslationUpdateMediator < BasicMediator

  # @param [Translation] primary_translation that will be updated
  # @param [User] user who is making the changes
  # @param [ActionController::Parameters] params that will be used to update the translation

  def initialize(primary_translation, user, params)
    super()
    @primary_translation, @user, @params = primary_translation, user, params
  end

  # Updates this translation and its associated translations
  def update!
    copy_to_translations = translations_that_should_be_multi_updated
    return if failure?

    Translation.transaction do
      copy_to_translations.each do |translation|
        update_single_translation!(translation)
      end
      update_single_translation!(@primary_translation)
    end

    KeyRecalculator.perform_once(@primary_translation.key_id) # Readiness hooks were skipped in the transaction above, now we gotta run them.
  rescue ActiveRecord::RecordInvalid => err
    add_errors(err.record.errors.full_messages.map { |msg| "(#{err.record.rfc5646_locale}): #{msg}" })
  end

  # Finds all translations that is allowed to be updated alongside the inputted {Translation} with the same copy,
  # based on {LocaleAssociation LocaleAssociations}. Doesn't include self, or base translation.
  #
  # These translations are the keys of the returned hash. The values are the {LocaleAssociation LocaleAssociations}
  # that tie the associated translations to the inputted translation.
  #
  # This should be used in 2 places:
  # - in the Translation Workbench when determining for which locales the checkboxes should appear
  # - in validating that the locales that a translation should be copied to are valid
  #
  # For the first reason above, this is a class method.
  #
  # @return [Hash<Translation, LocaleAssociation>] a hash of associated multi updateable translations to the locale associations.

  def self.multi_updateable_translations_to_locale_associations_hash(translation)
    hsh = {}
    translation.key.translations.each do |t| # translations should already loaded before this point, so don't run a new sql query. ie. prevent n+1 queries
      if (t.id != translation.id) && !t.base_translation?
        locale_association = translation.locale_associations.detect { |la| la.target_rfc5646_locale == t.rfc5646_locale }
        hsh[t] = locale_association if locale_association
      end
    end
    hsh
  end

  private

  # Retrive all translations that should be updated alongside the primary translation, based on the `copyToLocales`
  # field in user provided params. It maps the user provided `copyToLocales` to {Translation} objects.
  #
  # If one of the requested locales are not allowed to be updated, it adds an error and breaks out of the loop.
  #
  # The consumer of this function should check for errors before proceeding.
  #
  # @return [Array<Translation>] array of translations that should be updated alongside the primary translation

  def translations_that_should_be_multi_updated
    return [] unless @params[:copyToLocales]
    translations_indexed_by_rfc5646_locale = self.class.multi_updateable_translations_to_locale_associations_hash(@primary_translation).keys.index_by(&:rfc5646_locale)
    @params[:copyToLocales].map do |rfc5646_locale|
      unless translations_indexed_by_rfc5646_locale.key?(rfc5646_locale)
        add_error("Cannot update translation in locale #{rfc5646_locale}")
        break
      end
      translations_indexed_by_rfc5646_locale[rfc5646_locale]
    end
  end

  # @return [Hash<String, Translation>] a hash of rfc5646_locale to translations that is allowed to be updated alongside the primary translation.
  def multi_updateable_translations_indexed_by_rfc5646_locale
    @multi_updateable_translations_indexed_by_rfc5646_locale ||=
        self.class.multi_updateable_translations_to_locale_associations_hash(@primary_translation).keys.index_by(&:rfc5646_locale)
  end

  # Updates a single translation.
  #
  # @param [Translation] translation that will be updated
  # @raise [ActiveRecord::RecordInvalid] if translation is invalid

  def update_single_translation!(translation)
    translation.modifier = @user
    translation.assign_attributes(@params.require(:translation).permit(:copy, :notes))

    # un-translate translation if empty but blank_string is not specified
    if translation.copy.blank? && !@params[:blank_string].parse_bool
      untranslate(translation)
    else
      translation.translator = @user if translation.copy != translation.copy_was
      if @user.reviewer?
        translation.reviewer = @user
        translation.approved = true
        translation.preserve_reviewed_status = true
      end
    end
    translation.save!
  end

  # Untranslates a translation, but doesn't call `save`.
  #
  # @param [Translation] translation that will be untranslated

  def untranslate(translation)
    translation.copy = nil
    translation.translator = nil
    translation.approved = nil
    translation.reviewer = nil
  end
end
