# Copyright 2013 Square Inc.
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

# The primary controller for Glossary landing page.

class GlossaryController < ApplicationController
  before_filter :authenticate_user!
  
  # Renders the list of glossary entries that enable translator and reviewers
  # to look over, edit, and approve copy translations.
  #
  # Routes
  # ------
  #
  # * `GET /glossary`
  
  def index
    @source_locale = convert_locale(Locale.new(Shuttle::Configuration.locales.source_locale))
    @target_locales = Project.all.map(&:targeted_locales).flatten.uniq.map {|locale| convert_locale(locale)}
    @target_locales.delete(@source_locale)
  end

  private 

  # Converts a locale object to a form readable for the glossary list

  def convert_locale(locale)
    {rfc: locale.rfc5646, locale: locale.name, flagUrl: nil}
  end 

end
