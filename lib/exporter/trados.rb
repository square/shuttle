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

  # Exports the translated strings of a Commit for use with the TRADOS
  # translation tool.

  class Trados < Base

    # Exports the translated strings to a TRADOS-ready RTF file in the locale
    # provided.
    #
    # @raise [NoLocaleProvidedError] If a single locale is not provided.

    def export(io, *locales)
      raise NoLocaleProvidedError, "Trados files can only be for a single locale" unless locales.size == 1
      locale = locales.first

      io.puts preamble
      translations = Translation.in_commit(@commit).
          where(rfc5646_locale: locale.rfc5646, translated: true).
          sort_by { |t| t.key.key }
      translations.each { |translation| io.puts entry(translation) }
      io.close
    end

    def self.request_format() :trados end
    def self.multilingual?() false end

    private

    def preamble
      <<-XML.chomp
<TWBExportFile version="7.0" generator="TW4Win" build="8.3.0.863">
<RTF Preamble>
<FontTable>
{\\fonttbl
{\\f1 \\fmodern\\fprq1 \\fcharset0 Courier New;}
{\\f2 \\fswiss\\fprq2 \\fcharset0 Arial;}
{\\f3 \\fcharset0 Arial Unicode MS;}
{\\f4 \\fcharset0 MS Mincho;}
{\\f5 \\froman\\fprq2 \\fcharset0 Times New Roman;}}
<StyleSheet>
{\\stylesheet
{\\St \\s0 {\\StN Normal}}
{\\St \\cs1 {\\StB \\v\\f1\\fs24\\sub\\cf12 }{\\StN tw4winMark}}
{\\St \\cs2 {\\StB \\cf4\\fs40\\f1 }{\\StN tw4winError}}
{\\St \\cs3 {\\StB \\f1\\cf11\\lang1024 }{\\StN tw4winPopup}}
{\\St \\cs4 {\\StB \\f1\\cf10\\lang1024 }{\\StN tw4winJump}}
{\\St \\cs5 {\\StB \\f1\\cf15\\lang1024 }{\\StN tw4winExternal}}
{\\St \\cs6 {\\StB \\f1\\cf6\\lang1024 }{\\StN tw4winInternal}}
{\\St \\cs7 {\\StB \\cf2 }{\\StN tw4winTerm}}
{\\St \\cs8 {\\StB \\f1\\cf13\\lang1024 }{\\StN DO_NOT_TRANSLATE}}
{\\St \\cs9 \\additive {\\StN Default Paragraph Font}}}
</RTF Preamble>
      XML
    end

    def entry(translation)
      translation_date = I18n.l(translation.updated_at, format: :trados) if translation
      translator       = translation.try!(:translator).try!(:first_name).try!(:upcase)
      base_copy        = translation.source_copy
      translated_copy  = translation.try!(:copy)
      target_locale  = (translation.try!(:locale) || locale).rfc5646

      fence_copy! translation.key.fencers, base_copy
      fence_copy! translation.key.fencers, translated_copy if translated_copy

      <<-XML.chomp
<TrU>
<CrD>#{translation_date}</CrD>
<CrU>#{translator}</CrU>
<Seg L=#{@commit.project.base_rfc5646_locale.upcase}>#{base_copy}</Seg>
<Seg L=#{target_locale.upcase}>#{translated_copy}</Seg>
</TrU>
      XML
    end

    private

    def fence_copy!(fencers, copy)
      # in order to handle both fencing and escaping (especially for mustache,
      # which uses braces to fence, which, when not used as fences, should be
      # escaped), we're going to have to do the fencing twice. the first time is
      # just to get the ranges of characters we should NOT escape. we escape all
      # characters outside that range. the second time is to do the actual
      # fencing.

      # so, on that note, first get the ranges of characters we will not be
      # escaping
      dont_escape_ranges = Fencer.multifence(fencers, copy).values.flatten
      # invert the ranges to get the ranges we will escape
      escape_ranges      = Range.invert(copy.range, dont_escape_ranges)
      # we need to work backwards, so that modifications to the string don't
      # affect unprocessed ranges
      escape_ranges.sort_by! { |range| -range.first }
      # for each range, escape that portion of the string
      escape_ranges.each do |range|
        copy[range] = copy[range].gsub('{', '\\{').gsub('}', '\\}')
      end

      # next, load the fences...
      fences = Fencer.multifence(fencers, copy)
      # we have to do it backwards, so that earlier ranges don't mess up later
      # ranges.
      fences = fences.inject([]) { |ary, (token, ranges)| ranges.each { |range| ary << [token, range] }; ary }
      fences.sort_by! { |(_, range)| -range.first }
      # ... and wrap each fence with a {\cs1 ...} tag.r
      fences.each do |(token, range)|
        token = token.gsub('{', '\\{').gsub('}', '\\}')
        copy[range] = "{\\cs6\\f1\\cf6\\lang1024 #{token}}"
      end
    end
  end
end
