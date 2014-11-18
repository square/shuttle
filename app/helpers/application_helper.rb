# encoding: utf-8

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

# Helper methods that apply to all views.

module ApplicationHelper
  LANGUAGES_FOR_COUNTRIES_HASH = YAML.load_file(Rails.root.join('data', 'locale_countries.yml').to_s)

  # A composition of `pluralize` and `number_with_delimiter.`
  #
  # @param [Fixnum] count The number of things.
  # @param [String] singular The name of a thing.
  # @param [String] plural The name of two or more things.
  # @return [String] A pluralized description of the things.

  def pluralize_with_delimiter(count, singular, plural=nil)
    "#{number_with_delimiter(count) || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
  end

  # Given a locale, returns a path to the image that is that country's flag
  #
  # @param [Locale] locale The locale relating to the country we want the flag image of.
  # @return [String, nil] The path to the flag image.
  def locale_image_path(locale)
    country = locale.region || LANGUAGES_FOR_COUNTRIES_HASH[locale.iso639]

    return nil unless country
    return nil unless Rails.root.join('app', 'assets', 'images', 'country-flags', country.downcase + '.png')

    image_path "country-flags/#{country.downcase}.png"
  end
end
