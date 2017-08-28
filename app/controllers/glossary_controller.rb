# Copyright 2016 Square Inc.
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

# The primary controller for the glossary landing page.

class GlossaryController < ApplicationController

  # Renders the list of glossary entries that enable translator and reviewers to
  # look over, edit, and approve them.
  #
  # Routes
  # ------
  #
  # * `GET /glossary`

  def index
    locales = params[:target_locales] || current_user.approved_locales.map(&:rfc5646)
    locales = locales.blank? ? Shuttle::Configuration.locales.default_filter_locales : locales
    @source_locale  = Shuttle::Configuration.locales.source_locale
    @target_locales = Project.all.map(&:targeted_locales).flatten.uniq.select do |locale|
      locales.include?(locale.rfc5646)
    end
    @target_locales.delete(@source_locale)

    # This will give us the following
    #
    # {
    #   '#' => ['2-factor-authentication']
    #   'A' => ['aardvark', 'apple'],
    #   'S' => ['Square', 'szechuan']
    # }
    #
    # Note that these are SourceGlossaryEntries not pure strings.
    alphabet = ('A'..'Z').to_a
    @grouped_source_entries = SourceGlossaryEntry
      .includes(:locale_glossary_entries)
      .sort_by { |se| se.source_copy.downcase }
      .group_by do |se|
        first_letter = se.source_copy[0].upcase
        if alphabet.include?(first_letter)
          first_letter
        else
          '#'
        end
      end

    # [
    #   ['#', 'glossary-table-#]
    #   ['A', 'glossary-table-A]
    #   ['B', 'glossary-table-B]
    #   ['C', 'glossary-table-C]
    #   ['Z', 'glossary-table-Z]
    # ]
    @anchors = (['#'] + alphabet).map do |letter|
      [letter, "glossary-table-#{letter}"]
    end
  end
end

