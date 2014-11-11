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

class TranslationUpdateMediator

  # @param [Translation] primary_translation that will be updated
  # @param [User] user who is making the changes
  # @param [ActionController::Parameters] params that will be used to update the translation

  def initialize(primary_translation, user, params)
    @primary_translation, @user, @params = primary_translation, user, params
  end

  # Updates this translation and its associated translations
  def update
    update_single_translation(@primary_translation, @params[:blank_string], @params.require(:translation).permit(:copy, :notes))
    # TODO (yunus): update user specified associated translations
  end

  private

  # Updates a single translation.
  #
  # @param [Translation] translation that will be updated
  # @param [true, false] is_blank_string true if the translation should be updated as an empty string, false otherwise
  # @param [ActionController::Parameters] permitted_params that will be used to update the translation

  def update_single_translation(translation, is_blank_string, permitted_params)
    translation.freeze_tracked_attributes
    translation.modifier = @user
    translation.assign_attributes(permitted_params)

    # un-translate translation if empty but blank_string is not specified
    if translation.copy.blank? && !is_blank_string
      untranslate(translation)
    else
      translation.translator = @user if translation.copy != translation.copy_was
      if @user.reviewer?
        translation.reviewer = @user
        translation.approved = true
        translation.preserve_reviewed_status = true
      end
    end
    translation.save
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