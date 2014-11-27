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

require 'spec_helper'

describe Exporter::Trados do
  context "[exporting]" do
    before :each do
      @project = FactoryGirl.create(:project)
      @en      = Locale.from_rfc5646('en-US')
      @de      = Locale.from_rfc5646('de-DE')
      person   = FactoryGirl.create(:user)

      key1 = FactoryGirl.create(:key,
                                project: @project,
                                key:     "rammstein.1",
                                fencers: %w(Mustache))
      key2 = FactoryGirl.create(:key,
                                project: @project,
                                key:     "rammstein.2",
                                fencers: %w(Mustache))
      key3 = FactoryGirl.create(:key,
                                project: @project,
                                key:     "rammstein.3",
                                fencers: %w(Mustache))
      key4 = FactoryGirl.create(:key,
                                project: @project,
                                key:     "rammstein.4",
                                fencers: %w(Mustache))

      FactoryGirl.create :translation,
                         key:           key1,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   "Deep wells must one dig",
                         copy:          "Tiefe Brunnen muss man graben",
                         updated_at:    Time.at(1234567890),
                         translator:    person
      FactoryGirl.create :translation,
                         key:           key2,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   "When {{one}} wants clear water",
                         copy:          "Wenn {{one}} klares Wasser will",
                         updated_at:    Time.at(1234567890),
                         translator:    person
      FactoryGirl.create :translation,
                         key:           key3,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   "Rose-red, {oh} rose-red",
                         copy:          "Rosenrot, {oh} Rosenrot",
                         updated_at:    Time.at(1234567890),
                         translator:    person
      FactoryGirl.create :translation,
                         key:           key4,
                         source_locale: @en,
                         locale:        @de,
                         source_copy:   "{Deep} {{water}} {isn't} {{still}}",
                         copy:          "{Tiefe} {{water}} {sind nicht} {{still}}",
                         updated_at:    Time.at(1234567890),
                         translator:    person

      @commit1      = FactoryGirl.create(:commit, project: @project)
      @commit1.keys = [key1]
      @commit2      = FactoryGirl.create(:commit, project: @project)
      @commit2.keys = [key2]
      @commit3      = FactoryGirl.create(:commit, project: @project)
      @commit3.keys = [key3]
      @commit4      = FactoryGirl.create(:commit, project: @project)
      @commit4.keys = [key4]
    end

    it "should export a basic Trados file" do
      exporter = Exporter::Trados.new(@commit1)
      strio    = StringIO.new
      exporter.export(strio, @de)

      expect(strio.string).to eql(<<-XML)
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
<TrU>
<CrD>13022009, 15:31:30</CrD>
<CrU>SANCHO</CrU>
<Seg L=EN-US>Deep wells must one dig</Seg>
<Seg L=DE-DE>Tiefe Brunnen muss man graben</Seg>
</TrU>
      XML
    end

    it "should properly fence tokens" do
      exporter = Exporter::Trados.new(@commit2)
      strio    = StringIO.new
      exporter.export(strio, @de)

      expect(strio.string).to eql(<<-XML)
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
<TrU>
<CrD>13022009, 15:31:30</CrD>
<CrU>SANCHO</CrU>
<Seg L=EN-US>When {\\cs6\\f1\\cf6\\lang1024 \\{\\{one\\}\\}} wants clear water</Seg>
<Seg L=DE-DE>Wenn {\\cs6\\f1\\cf6\\lang1024 \\{\\{one\\}\\}} klares Wasser will</Seg>
</TrU>
      XML
    end

    it "should properly escape special characters" do
      exporter = Exporter::Trados.new(@commit3)
      strio    = StringIO.new
      exporter.export(strio, @de)

      expect(strio.string).to eql(<<-XML)
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
<TrU>
<CrD>13022009, 15:31:30</CrD>
<CrU>SANCHO</CrU>
<Seg L=EN-US>Rose-red, \\{oh\\} rose-red</Seg>
<Seg L=DE-DE>Rosenrot, \\{oh\\} Rosenrot</Seg>
</TrU>
      XML
    end

    it "should properly escape a string with multiple tokens and escapable characters" do
      exporter = Exporter::Trados.new(@commit4)
      strio    = StringIO.new
      exporter.export(strio, @de)

      expect(strio.string).to eql(<<-XML)
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
<TrU>
<CrD>13022009, 15:31:30</CrD>
<CrU>SANCHO</CrU>
<Seg L=EN-US>\\{Deep\\} {\\cs6\\f1\\cf6\\lang1024 \\{\\{water\\}\\}} \\{isn't\\} {\\cs6\\f1\\cf6\\lang1024 \\{\\{still\\}\\}}</Seg>
<Seg L=DE-DE>\\{Tiefe\\} {\\cs6\\f1\\cf6\\lang1024 \\{\\{water\\}\\}} \\{sind nicht\\} {\\cs6\\f1\\cf6\\lang1024 \\{\\{still\\}\\}}</Seg>
</TrU>
      XML
    end
  end
end
