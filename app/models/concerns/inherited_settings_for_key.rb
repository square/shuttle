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

# A concern for {Key} that providers helpers for a lot of settings that would be
# inherited from the {Key}'s Article or Project.

module InheritedSettingsForKey

  # If this {Key} belongs to an {Article}, the required locales are pulled from the
  # Article's settings. Otherwise, project's settings are used.
  #
  # @return [Array<Locale>] An array of {Locale Locales} this {Key} must be translated to.

  def required_locales
    article ? article.required_locales : project.required_locales
  end

  # If this {Key} belongs to a {Article}, the Article is checked to see if the key
  # should be skipped. Otherwise, project is checked.
  #
  # @return [Boolean] Whether or not this {Key} should be skipped.

  def skip_key?(locale)
    article ? article.skip_key?(self, locale) : project.skip_key?(self.key, locale)
  end

  # If this {Key} belongs to a {Article}, the base locale is pulled from the
  # Article's settings. Otherwise, project's settings are used.
  #
  # @return [Locale] Base {Locale} of this {Key}

  def base_locale
    article ? article.base_locale : project.base_locale
  end

  # If this {Key} belongs to a {Article}, the targeted_locales are pulled from the
  # Article's settings. Otherwise, project's settings are used.
  #
  # @return [Array<Locale>] Array of {Locale Locales} this {Key} is targeted to.

  def targeted_locales
    article ? article.targeted_locales : project.targeted_locales
  end

end
