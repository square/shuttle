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
# inherited from the {Key}'s KeyGroup or Project.

module InheritedSettingsForKey

  # If this {Key} belongs to a {KeyGroup}, the required locales are pulled from the
  # KeyGroup's settings. Otherwise, project's settings are used.
  #
  # @return [Array<Locale>] array of {Locales} this {Key} must be translated to.

  def required_locales
    key_group ? key_group.required_locales : project.required_locales
  end

  # If this {Key} belongs to a {KeyGroup}, the KeyGroup is checked to see if the key
  # should be skipped. Otherwise, project is checked.
  #
  # @return [Boolean] whether or not this {Key} should be skipped.

  def skip_key?(locale)
    key_group ? key_group.skip_key?(self, locale) : project.skip_key?(self.key, locale)
  end

  # If this {Key} belongs to a {KeyGroup}, the base locale is pulled from the
  # KeyGroup's settings. Otherwise, project's settings are used.
  #
  # @return [Locale] base {Locale} of this {Key}

  def base_locale
    key_group ? key_group.base_locale : project.base_locale
  end

  # If this {Key} belongs to a {KeyGroup}, the targeted_locales are pulled from the
  # KeyGroup's settings. Otherwise, project's settings are used.
  #
  # @return [Array<Locale>] array of {Locales} this {Key} is targeted to.

  def targeted_locales
    key_group ? key_group.targeted_locales : project.targeted_locales
  end

end