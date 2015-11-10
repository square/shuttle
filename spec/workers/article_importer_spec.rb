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

describe ArticleImporter do
  describe "#perform" do
    before :each do
      Article.any_instance.stub(:import!) # prevent auto imports
      @article = FactoryGirl.create(:article, sections_hash: { "title" => "a", "body" => "<p>b</p><p>c</p>" })
      ArticleImporter.new.perform(@article.id) # first import
      @sections = @article.reload.sections
    end

    it "sets ready to false, and last_import_started_at to current Time" do
      ArticleImporter::Finisher.any_instance.stub(:on_success) # prevent import from finishing
      ArticleImporter.new.perform(@article.id)

      expect(@article).to_not be_ready
      expect(@article.last_import_started_at).to_not be_nil
    end

    context "[create/update Sections]" do
      it "creates new Sections with provided source_copy and sets active to true" do
        article = FactoryGirl.create(:article, sections_hash: { "title" => "a", "body" => "<p>b</p><p>c</p>" })
        ArticleImporter.new.perform(article.id)
        sections = article.reload.sections
        expect(sections.map { |section| [section.name, section.source_copy, section.active] }.sort).to eql(
            [["title", "a", true], ["body", "<p>b</p><p>c</p>", true]].sort)
      end

      it "updates the existing Section if it exists" do
        title_section = @article.reload.sections.for_name("title").first
        @article.update! sections_hash: { "title" => "x" }
        ArticleImporter.new.perform(@article.id)
        expect(title_section.reload.source_copy).to eql("x")
        expect(title_section).to be_active
      end

      it "deactivates existing Sections which aren't seen in the most recent Article sections_hash" do
        body_section = @article.reload.sections.for_name("body").first
        @article.update! sections_hash: { "title" => "x" }
        ArticleImporter.new.perform(@article.id)
        expect(body_section.reload.source_copy).to eql("<p>b</p><p>c</p>")
        expect(body_section).to_not be_active
      end
    end

    context "[calling SectionImporter]" do
      it "calls SectionImporter for all sections if this is the first time this Article is being imported" do
        article = FactoryGirl.create(:article, sections_hash: { "title" => "a", "body" => "<p>b</p><p>c</p>" })
        expect(SectionImporter).to receive(:perform_once).twice
        ArticleImporter.new.perform(article.id) # first import
      end

      it "calls SectionImporter only for active sections" do
        title_section = @article.reload.sections.for_name("title").first
        body_section = @article.reload.sections.for_name("body").first
        @article.update! sections_hash: { "title" => "x" }

        expect(SectionImporter).to receive(:perform_once).with(title_section.id)
        expect(SectionImporter).to_not receive(:perform_once).with(body_section.id)
        ArticleImporter.new.perform(@article.id)
      end

      it "calls SectionImporter if force_import_sections is set to true even if source_copy didn't change" do
        @sections.each do |section|
          expect(SectionImporter).to receive(:perform_once).with(section.id)
        end
        ArticleImporter.new.perform(@article.id, true)
      end

      it "calls SectionImporter if source_copy changed" do
        @article.update! sections_hash: { "title" => "x" }
        ArticleImporter.new.perform(@article.id)
        title_section = @article.reload.sections.for_name("title").first

        @article.update! sections_hash: { "title" => "y" }

        expect(SectionImporter).to receive(:perform_once).with(title_section.id)
        ArticleImporter.new.perform(@article.id)
      end

      it "calls SectionImporter if section is activated by being re-added to the Article's sections_hash" do
        title_section = @article.reload.sections.for_name("title").first
        body_section = @article.reload.sections.for_name("body").first
        @article.update! sections_hash: { "title" => "x" }
        ArticleImporter.new.perform(@article.id)

        @article.update! sections_hash: { "title" => "x", "body" => "<p>b</p><p>c</p>" }

        expect(SectionImporter).to_not receive(:perform_once).with(title_section.id)
        expect(SectionImporter).to receive(:perform_once).with(body_section.id)
        ArticleImporter.new.perform(@article.id)
      end

      it "doesn't call SectionImporter if source_copy and activeness didn't change, and force_import_sections is not set" do
        @article.update! sections_hash: { "title" => "a", "body" => "<p>b</p><p>c</p>" }

        expect(SectionImporter).to_not receive(:perform_once)
        ArticleImporter.new.perform(@article.id)
      end
    end
  end
end

describe ArticleImporter::Finisher do
  describe "#on_success" do
    before :each do
      # creation triggers the initial import
      @article = FactoryGirl.create(:article, sections_hash: { "main" => "<p>hello</p><p>world</p>" }, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
      expect(@article.reload.keys.count).to eql(2)
      expect(@article.translations.count).to eql(8)
      @article.reload
    end

    it "sets Article's ready = false if this is an initial import" do
      expect(@article).to_not be_ready
    end

    it "sets Article's and its Keys ready = false if this is a re-import and there are not-approved translations" do
      @article.keys.update_all ready: true
      @article.update! ready: true
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id}) # finish re-import
      expect(@article.reload).to_not be_ready
      expect(@article.keys.where(ready: true).exists?).to_not be_true
    end

    it "sets Article's ready = true at the end of a re-import if all translations were  already approved" do
      @article.translations.in_locale(*@article.required_locales).each do |translation|
        translation.update! copy: "<p>test</p>", approved: true
      end
      @article.reload.update! ready: false

      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id}) # finish re-import
      expect(@article.reload).to be_ready
    end

    it "finishes loading" do
      @article.update! last_import_requested_at: 1.day.ago, last_import_finished_at: nil
      expect(@article.reload).to be_loading
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})
      expect(@article.reload).to_not be_loading
      expect(@article.last_import_finished_at).to_not be_nil
    end

    it "sets import_batch_id to false" do
      @article.update! import_batch_id: "something"
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})
      expect(@article.reload.import_batch_id).to be_nil
    end

    it "sets first_import_finished_at at the end of the first import, and doesn't set it again on re-imports" do
      @article.update! first_import_finished_at: nil # clear this field for a clean start
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})

      original_first_import_finished_at = @article.reload.first_import_finished_at
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})
      expect(@article.reload.first_import_finished_at).to eql(original_first_import_finished_at)
    end

    it "sets last_import_finished_at at the end of the last import, and re-sets it again on every re-import" do
      expect(@article.last_import_finished_at).to_not be_nil
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})

      original_last_import_finished_at = @article.reload.last_import_finished_at
      ArticleImporter::Finisher.new.on_success(nil, {'article_id' => @article.id})
      expect(@article.reload.last_import_finished_at).to_not eql(original_last_import_finished_at)
    end
  end
end
