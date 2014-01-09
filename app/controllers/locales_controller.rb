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

# Works with information about the application's locale database. This
# information is used by the front-end `LocaleField` class to intelligently
# display a list of locale options.

class LocalesController < ApplicationController

  # Returns a list of known locales and their variants, scripts, etc.
  #
  # Routes
  # ------
  #
  # * `GET /locales`

  def index
    render json: t('locale').to_json
  end

  # Returns a hash mapping a locale code to the country it is most typically
  # associated with. This is used to choose a flag icon to display next to the
  # locale.
  #
  # Routes
  # ------
  #
  # * `GET /locales/countries`

  def countries
    countries = YAML.load_file(Rails.root.join('data', 'locale_countries.yml'))
    countries.select! { |_, flag| File.exist? Rails.root.join('app', 'assets', 'images', 'country-flags', "#{flag.downcase}.png") }
    # apply potential region values too
    Dir.glob(Rails.root.join('app', 'assets', 'images', 'country-flags', '*.png')).each do |file|
      base = File.basename(file, '.png')
      next if base.starts_with?('_')
      countries[base.upcase] = base
    end

    countries.each { |key, flag| countries[key] = view_context.image_path("country-flags/#{flag.downcase}.png") }

    render json: countries.to_json
  end
end
