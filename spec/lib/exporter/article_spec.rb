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

require 'spec_helper'

describe Exporter::Article do
  describe "#export" do
    before :all do
      @fr_locale = Locale.from_rfc5646('fr')
      @es_locale = Locale.from_rfc5646('es')
      @ja_locale = Locale.from_rfc5646('ja')
    end

    before :each do
      @project = FactoryGirl.create(:project, repository_url: nil)
      @article = FactoryGirl.create(:article, project: @project, ready: false,
                                      sections_hash: { "title" => "a", "body" => "<p>hello</p><p>world</p>" },
                                      base_rfc5646_locale: 'en',
                                      targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
      expect(@article.reload.keys.count).to eql(3)

      @title_section = @article.sections.for_name("title").first
      @body_section = @article.sections.for_name("body").first

      @title_fr_translations = @title_section.translations.in_locale(@fr_locale).order("keys.index_in_section")
      @title_es_translations = @title_section.translations.in_locale(@es_locale).order("keys.index_in_section")
      @title_ja_translations = @title_section.translations.in_locale(@ja_locale).order("keys.index_in_section")
      @body_fr_translations = @body_section.translations.in_locale(@fr_locale).order("keys.index_in_section")
      @body_es_translations = @body_section.translations.in_locale(@es_locale).order("keys.index_in_section")
      @body_ja_translations = @body_section.translations.in_locale(@ja_locale).order("keys.index_in_section")

      @title_fr_translations[0].update! copy: "b", approved: true
      @title_es_translations[0].update! copy: "c", approved: true
      @body_fr_translations[0].update! copy: "<p>bonjour</p>", approved: true
      @body_es_translations[0].update! copy: "<p>hola</p>", approved: true
      @body_fr_translations[1].update! copy: "<p>monde</p>", approved: true
      @body_es_translations[1].update! copy: "<p>mundo</p>", approved: true

      @article.keys.reload.each(&:recalculate_ready!)
      expect(@article.reload).to be_ready
    end

    it "raises InputError if no locales are provided" do
      expect { Exporter::Article.new(@article).send(:export, []) }.to raise_error(Exporter::Article::InputError, "No Locale(s) Inputted")
    end

    it "raises InputError if an invalid locale in rfc5646 representation is provided" do
      expect { Exporter::Article.new(@article).send(:export, "fr, invalid-locale") }.to raise_error(Exporter::Article::InputError, "Locale 'invalid-locale' could not be found.")
    end

    it "raises InputError if one of the requested locales is not a required locale" do
      expect { Exporter::Article.new(@article).send(:export, [@fr_locale, @ja_locale]) }.to raise_error(Exporter::Article::InputError, "Inputted locale 'ja' is not one of the required locales for this article.")
    end

    it "raises NotReadyError if Article is not ready" do
      @title_fr_translations[0].update! approved: false
      @title_fr_translations[0].key.reload.recalculate_ready!
      expect(@article.reload).to_not be_ready
      expect { Exporter::Article.new(@article).send(:export) }.to raise_error(Exporter::Article::NotReadyError)
    end

    it "returns the correct translations when string locales are provided" do
      expect(Exporter::Article.new(@article).send(:export, "fr, es")).to eql(
                                   { 'fr' => { "title" => "b", "body" => "<p>bonjour</p><p>monde</p>" },
                                     'es' => { "title" => "c", "body" =>"<p>hola</p><p>mundo</p>" } })
    end

    it "returns the correct translations when only some of the required locales are requested" do
      expect(Exporter::Article.new(@article).send(:export, [@fr_locale])).to eql({ 'fr' => { "title" => "b", "body" => "<p>bonjour</p><p>monde</p>" } })
    end

    it "returns the correct translations for all required locales when no locales are specified" do
      expect(Exporter::Article.new(@article).send(:export)).to eql(
                                   { 'fr' => { "title" => "b", "body" => "<p>bonjour</p><p>monde</p>" },
                                     'es' => { "title" => "c", "body" =>"<p>hola</p><p>mundo</p>" } })
    end
  end

  describe "#export_locale" do
    it "exports translations in one locale" do
      @fr_locale = Locale.from_rfc5646('fr')

      @project = FactoryGirl.create(:project, repository_url: nil)
      @article = FactoryGirl.create(:article, project: @project,
                                    sections_hash: { "title" => "a", "body" => "<p>hello</p><p>world</p>" },
                                    base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'fr' => true })

      @article.translations.update_all copy: "<p>translated</p>", approved: true
      expect(Exporter::Article.new(@article).send(:export_locale, @fr_locale)).to eql({"body"=>"<p>translated</p><p>translated</p>", "title"=>"<p>translated</p>"})
    end
  end

  describe "#export_section_locale" do
    before :all do
      @fr_locale = Locale.from_rfc5646('fr')
    end

    before :each do
      @project = FactoryGirl.create(:project, repository_url: nil)
      @article = FactoryGirl.create(:article, project: @project,
                                    sections_hash: { "main" => "<p>hello</p><p>world</p>" },
                                    base_rfc5646_locale: 'en',
                                    targeted_rfc5646_locales: { 'fr' => true, 'es' => true })
      @section = @article.sections.last
      expect(@section.keys.count).to eql(2)
      @fr_translations = @section.translations.in_locale(@fr_locale).order("keys.index_in_section")
    end

    it "returns the full translation of Section in the given locale" do
      @fr_translations[0].update! copy: "<p>bonjour</p>"
      @fr_translations[1].update! copy: "<p>monde</p>"
      expect(Exporter::Article.new(@article).send(:export_section_locale, @section, @fr_locale)).to eql("<p>bonjour</p><p>monde</p>")
    end

    it "raises MissingTranslation error if a translation is missing from this locale" do
      @fr_translations[0].update! copy: "<p>bonjour</p>"
      @fr_translations[1].delete

      expect { Exporter::Article.new(@article).send(:export_section_locale, @section, @fr_locale) }.to raise_error(Exporter::Article::MissingTranslation)
    end
  end
end
