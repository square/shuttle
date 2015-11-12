# Copyright 2015 Square Inc.
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

describe Article do
  # ======== START BASIC CRUD RELATED CODE =============================================================================
  describe "[before_validations on create]" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "copies base_rfc5646_locale from project if it is blank" do
      project = FactoryGirl.create(:project, base_rfc5646_locale: 'es')
      article = FactoryGirl.create(:article, base_rfc5646_locale: '', project: project)
      expect(article.base_rfc5646_locale).to eql('es')
    end

    it "copies targeted_rfc5646_locales from project if it is blank" do
      project = FactoryGirl.create(:project, targeted_rfc5646_locales: {'fr' => true})
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: {}, project: project)
      expect(article.targeted_rfc5646_locales).to eql({'fr' => true})
    end
  end

  describe "[validations]" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "doesn't allow creating 2 Articles in the same project with the same name" do
      article = FactoryGirl.create(:article, name: "hello")
      article_new = FactoryGirl.build(:article, name: "hello", project: article.project).tap(&:save)
      expect(article_new).to_not be_persisted
      expect(article_new.errors.messages).to eql({:name =>["already taken"]})
    end

    it "allows creating 2 Articles with the same name under different projects" do
      FactoryGirl.create(:article, name: "hello")
      article_new = FactoryGirl.build(:article, name: "hello", project: FactoryGirl.create(:project)).tap(&:save)
      expect(article_new).to be_persisted
      expect(article_new.errors).to_not be_any
    end

    it "doesn't allow creating without a name" do
      article = FactoryGirl.build(:article, name: nil).tap(&:save)
      expect(article).to_not be_persisted
      expect(article.errors.messages).to eql({:name_sha=>["is not a valid SHA2 digest"], :name=>["can’t be blank"]})
    end

    it "doesn't allow updating base_rfc5646_locale to be blank" do
      article = FactoryGirl.create(:article, base_rfc5646_locale: 'es')
      article.update base_rfc5646_locale: nil
      expect(article.errors.full_messages).to include("source locale can’t be blank")
      expect(article.reload.base_rfc5646_locale).to eql('es')
      article.update base_rfc5646_locale: ''
      expect(article.errors.full_messages).to include("source locale can’t be blank")
      expect(article.reload.base_rfc5646_locale).to eql('es')
    end

    it "doesn't allow updating targeted_rfc5646_locales to be blank" do
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: {'fr' => true})
      article.update targeted_rfc5646_locales: nil
      expect(article.errors.full_messages).to include("targeted localizations can’t be blank")
      expect(article.reload.targeted_rfc5646_locales).to eql({'fr' => true})
      article.update targeted_rfc5646_locales: {}
      expect(article.errors.full_messages).to include("targeted localizations can’t be blank")
      expect(article.reload.targeted_rfc5646_locales).to eql({'fr' => true})
    end

    it "doesn't allow sections_hash to be ill-formatted" do
      article = FactoryGirl.build(:article, sections_hash: "test").tap(&:save)
      expect(article.errors.full_messages).to include("Sections hash wrong format")
    end

    it "doesn't allow blank section source_copy" do
      article = FactoryGirl.build(:article, sections_hash: { "test" => ""}).tap(&:save)
      expect(article.errors.full_messages).to include("Sections hash wrong format")
    end

    it "doesn't allow name to be 'new'" do
      article = FactoryGirl.build(:article, name: 'new').tap(&:save)
      expect(article.errors.full_messages).to include("Name reserved")
    end
  end

  describe '[scopes]' do
    describe '#loading?' do
      before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

      it 'returns only the loading articles' do
        a1 = FactoryGirl.create(:article, last_import_requested_at: nil, last_import_finished_at: nil)
        a2 = FactoryGirl.create(:article, last_import_requested_at: 1.hour.ago, last_import_finished_at: nil)
        a3 = FactoryGirl.create(:article, last_import_requested_at: nil, last_import_finished_at: 1.hour.ago)
        a4 = FactoryGirl.create(:article, last_import_requested_at: 1.hours.ago, last_import_finished_at: 2.hour.ago)
        FactoryGirl.create(:article, last_import_requested_at: 2.hours.ago, last_import_finished_at: 1.hour.ago)
        now = Time.now
        FactoryGirl.create(:article, last_import_requested_at: now, last_import_finished_at: now)

        expect(Article.loading).to match_array([a1, a2, a3, a4])
      end
    end
  end
  # ======== END BASIC CRUD RELATED CODE ===============================================================================

  # ======== START LOCALE RELATED CODE =================================================================================
  it_behaves_like "CommonLocaleLogic"

  describe "#base_locale" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    let(:project) { FactoryGirl.create(:project, repository_url: nil, base_rfc5646_locale: 'en') }

    it "returns the base_locale of the Article if it is set for the Article" do
      article = FactoryGirl.create(:article, project: project, base_rfc5646_locale: 'en-US')
      expect(article.base_rfc5646_locale).to eql('en-US')
    end

    it "returns the base_locale of the Project if Article's base_locale is not set" do
      article = FactoryGirl.create(:article, project: project)
      expect(article.base_rfc5646_locale).to eql('en')
    end
  end

  describe "#locale_requirements" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    let(:project) { FactoryGirl.create(:project, repository_url: nil, targeted_rfc5646_locales: { 'fr' => true } ) }

    it "returns the locale_requirements of the Article if they are set for the Article" do
      article = FactoryGirl.create(:article, project: project, targeted_rfc5646_locales: { 'ja' => true })
      expect(article.targeted_rfc5646_locales).to eql({'ja' => true })
    end

    it "returns the locale_requirements of the Project if Article's locale_requirements are not set" do
      article = FactoryGirl.create(:article, project: project)
      expect(article.targeted_rfc5646_locales).to eql({'fr' => true })
    end
  end
  # ======== END LOCALE RELATED CODE ===================================================================================

  # ======== START KEY & READINESS RELATED CODE ========================================================================
  describe "#find_by_name" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "returns nil if the given string name is nil" do
      expect(Article.find_by_name(nil)).to be_nil
    end

    it "returns nil if no Article matches the given string name" do
      Article.delete_all
      expect(Article.find_by_name("doesnotexist")).to be_nil
    end

    it "returns the Article if key matches one" do
      article = FactoryGirl.create(:article, name: "exists")
      expect(Article.find_by_name("exists")).to eql(article)
    end

    it "returns the Article if key matches one in the same project" do
      Article.delete_all
      project = FactoryGirl.create(:project)
      article = FactoryGirl.create(:article, name: "exists", project: project)
      expect(project.articles.find_by_name("exists")).to eql(article)
    end

    it "returns nil if there is a Article with same key, but under a different project" do
      article = FactoryGirl.create(:article, name: "exists")
      expect(FactoryGirl.create(:project).articles.find_by_name("exists")).to be_nil
    end
  end

  describe "#active_sections" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "returns the active keys (keys which has their index_in_section set in active sections)" do
      article = FactoryGirl.create(:article)
      active_section1 = FactoryGirl.create(:section, article: article, active: true)
      active_section2 = FactoryGirl.create(:section, article: article, active: true)
      inactive_section = FactoryGirl.create(:section, article: article, active: false)
      expect(article.reload.active_sections.to_a.sort).to eql([active_section1, active_section2].sort)
    end
  end

  describe "#inactive_sections" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "returns the active keys (keys which has their index_in_section set in active sections)" do
      article = FactoryGirl.create(:article)
      active_section = FactoryGirl.create(:section, article: article, active: true)
      inactive_section1 = FactoryGirl.create(:section, article: article, active: false)
      inactive_section2 = FactoryGirl.create(:section, article: article, active: false)
      expect(article.reload.inactive_sections.to_a.sort).to eql([inactive_section1, inactive_section2].sort)
    end
  end

  describe "#active_keys" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "returns the active keys (keys which has their index_in_section set in active sections)" do
      article = FactoryGirl.create(:article)
      active_section = FactoryGirl.create(:section, article: article, active: true)
      inactive_section = FactoryGirl.create(:section, article: article, active: false)

      active_section_active_key1 = FactoryGirl.create(:key, section: active_section, project: article.project, index_in_section: 0)
      active_section_active_key2 = FactoryGirl.create(:key, section: active_section, project: article.project, index_in_section: 1)
      active_section_inactive_key = FactoryGirl.create(:key, section: active_section, project: article.project, index_in_section: nil)

      inactive_section_active_key1 = FactoryGirl.create(:key, section: inactive_section, project: article.project, index_in_section: 0)
      inactive_section_active_key2 = FactoryGirl.create(:key, section: inactive_section, project: article.project, index_in_section: 1)
      inactive_section_inactive_key = FactoryGirl.create(:key, section: inactive_section, project: article.project, index_in_section: nil)

      expect(article.reload.keys.to_a.sort).to eql([active_section_active_key1, active_section_active_key2, active_section_inactive_key,
                                                    inactive_section_active_key1, inactive_section_active_key2, inactive_section_inactive_key].sort)
      expect(article.active_keys.to_a.sort).to eql([active_section_active_key1, active_section_active_key2].sort)
    end
  end

  describe "#recalculate_ready!" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    before :each do
      @article = FactoryGirl.create(:article,
                                    name: "test",
                                    ready: false,
                                    last_import_finished_at: 3.hours.ago,
                                    last_import_requested_at: 4.hour.ago)
      @active_section = FactoryGirl.create(:section, article: @article, active: true)
      @inactive_section = FactoryGirl.create(:section, article: @article, active: false)
    end

    it "sets ready=true if all active key are ready, and ignores the inactive keys" do
      FactoryGirl.create(:key, section: @active_section, project: @article.project, index_in_section: 0, ready: true)
      FactoryGirl.create(:key, section: @active_section, project: @article.project, index_in_section: 1, ready: true)
      FactoryGirl.create(:key, section: @active_section, project: @article.project, index_in_section: nil, ready: false)
      FactoryGirl.create(:key, section: @inactive_section, project: @article.project, index_in_section: 0, ready: false)
      expect(@article.keys.count).to eql(4)

      expect(@article.reload).to_not be_ready
      @article.recalculate_ready!
      expect(@article.reload).to be_ready
    end

    it "sets ready=false if at least one active key is not ready" do
      FactoryGirl.create(:key, section: @active_section, project: @article.project, index_in_section: 0, ready: true)
      FactoryGirl.create(:key, section: @active_section, project: @article.project, index_in_section: 1, ready: false)
      @article.update! ready: true
      @article.recalculate_ready!
      expect(@article.reload).to_not be_ready
    end

    it "sets ready=false if the import is in progress" do
      @article.reload.keys.each { |key| key.update! ready: true }
      @article.update! last_import_requested_at: 1.hour.ago
      @article.recalculate_ready!
      expect(@article.reload).to_not be_ready
    end

    it "sets first_completed_at when it becomes ready for the first time, and doesn't re-set it on later completions" do
      expect(@article).to_not be_ready
      @article.recalculate_ready!
      expect(@article.reload).to be_ready
      expect(@article.first_completed_at).to be_present
      original_first_completed_at = @article.first_completed_at

      Timecop.freeze(original_first_completed_at + 1.day) do
        @article.update! ready: false
        expect(@article).to_not be_ready
        @article.recalculate_ready!
        expect(@article.first_completed_at).to eql(original_first_completed_at)
      end
    end

    it "sets last_completed_at every time it becomes ready" do
      expect(@article).to_not be_ready
      @article.recalculate_ready!
      expect(@article.reload).to be_ready
      expect(@article.first_completed_at).to be_present
      original_last_completed_at = @article.last_completed_at

      Timecop.freeze(Date.today + 1) do
        @article.update! ready: false
        expect(@article).to_not be_ready
        @article.recalculate_ready!
        expect(@article.last_completed_at).to be_present
        expect(@article.last_completed_at).to_not eql(original_last_completed_at)
      end
    end
  end

  describe "#full_reset_ready!" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "resets the ready field of the Article and all of its Keys" do
      article = FactoryGirl.create(:article, name: "test", ready: true)
      section = FactoryGirl.create(:section, article: article)

      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: 0,   ready: true)
      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: 1,   ready: true)
      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: nil, ready: true)

      article.full_reset_ready!
      expect(article).to_not be_ready
      expect(article.keys.ready.exists?).to be_false
    end
  end

  describe "#skip_key?" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent auto imports

    it "skips key for a locale that is not a targeted_locale" do
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      expect(article.skip_key?("test", Locale.from_rfc5646('ja'))).to be_true
    end

    it "does not skip key for locales that are targeted locales" do
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true, 'es' => false } )
      expect(article.skip_key?("test", Locale.from_rfc5646('fr'))).to be_false
      expect(article.skip_key?("test", Locale.from_rfc5646('es'))).to be_false
    end
  end
  # ======== END KEY & READINESS RELATED CODE ==========================================================================

  # ======== START IMPORT RELATED CODE =================================================================================
  describe "#import!" do
    it "updates requested_at fields, resets ready fields, and calls ArticleImporter" do
      article = FactoryGirl.create(:article, name: "test", ready: true)
      section = FactoryGirl.create(:section, article: article)
      Key.delete_all

      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: 0,   ready: true)
      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: 1,   ready: true)
      FactoryGirl.create(:key, section: section, project: section.project, index_in_section: nil, ready: true)
      article.reload

      expect(ArticleImporter).to receive(:perform_once).with(article.id, false).once
      ArticleImporter::Finisher.any_instance.stub(:on_success)

      article.import!

      expect(article.first_import_requested_at).to be_present
      expect(article.last_import_requested_at).to be_present
      expect(article.loading?).to be_true
      expect(article).to_not be_ready
      expect(article.keys.ready.exists?).to be_false
    end

    it "raises a Article::LastImportNotFinished if the previous import is not yet finished" do
      article = FactoryGirl.create(:article)
      article.update! last_import_requested_at: 10.minutes.ago, last_import_finished_at: nil
      expect { article.import! }.to raise_error(Article::LastImportNotFinished)
    end
  end
  
  describe "#import_batch" do
    it "creates a new batch and updates import_batch_id of the Article if import_batch_id is initially nil" do
      article = FactoryGirl.build(:article, name: "test")
      article.stub(:import!) # prevent the import because we want to create the related keys manually
      article.save!

      expect(article.import_batch_id).to be_nil
      expect(article.import_batch).to be_an_instance_of(Sidekiq::Batch)
      expect(article.import_batch_id).to_not be_nil
    end

    it "returns the existing import_batch if there is one" do
      article = FactoryGirl.build(:article, name: "test")
      article.stub(:import!) # prevent the import because we want to create the related keys manually
      article.save!

      article.import_batch.jobs { sleep 3 }
      bid = article.import_batch_id
      article.import_batch # this should re-use the existing batch
      expect(article.import_batch_id).to eql(bid)
    end
  end

  describe "#update_import_requested_at!" do
    before :each do
      @article = FactoryGirl.build(:article, name: "test")
      @article.stub(:import!) # prevent the import because we want to create the related keys manually
      @article.save!
    end

    it "sets first_import_requested_at when it is requested for the first time, and doesn't re-set it on later requests" do
      expect(@article.first_import_requested_at).to be_nil
      @article.send :update_import_requested_at!

      expect(@article.first_import_requested_at).to be_present
      original_first_import_requested_at = @article.first_import_requested_at

      Timecop.freeze(original_first_import_requested_at + 1.day) do
        @article.send :update_import_requested_at!
        expect(@article.first_import_requested_at).to eql(original_first_import_requested_at)
      end
    end

    it "sets last_import_requested_at every time it becomes ready" do
      expect(@article.last_import_requested_at).to be_nil
      @article.send :update_import_requested_at!

      expect(@article.last_import_requested_at).to be_present
      original_last_import_requested_at = @article.last_import_requested_at

      Timecop.freeze(original_last_import_requested_at + 1.day) do
        @article.send :update_import_requested_at!
        expect(@article.last_import_requested_at).to_not eql(original_last_import_requested_at)
      end
    end
  end

  describe "#update_import_starting_fields!" do
    before :each do
      @article = FactoryGirl.build(:article, name: "test")
      @article.stub(:import!) # prevent the import because we want to create the related keys manually
      @article.save!
    end

    it "sets ready to false" do
      @article.update! ready: true
      expect(@article.ready).to be_true
      @article.send :update_import_starting_fields!
      expect(@article.ready).to be_false
    end

    it "sets first_import_started_at when it is started for the first time, and doesn't re-set it on later requests" do
      expect(@article.first_import_started_at).to be_nil
      @article.send :update_import_starting_fields!

      expect(@article.first_import_started_at).to be_present
      original_first_import_started_at = @article.first_import_started_at

      Timecop.freeze(original_first_import_started_at + 1.day) do
        @article.send :update_import_starting_fields!
        expect(@article.first_import_started_at).to eql(original_first_import_started_at)
      end
    end

    it "sets last_import_started_at every time it is started" do
      expect(@article.last_import_started_at).to be_nil
      @article.send :update_import_starting_fields!

      expect(@article.last_import_started_at).to be_present
      original_last_import_started_at = @article.last_import_started_at

      Timecop.freeze(original_last_import_started_at + 1.day) do
        @article.send :update_import_starting_fields!
        expect(@article.last_import_started_at).to_not eql(original_last_import_started_at)
      end
    end
  end

  describe "#update_import_finishing_fields!" do
    before :each do
      @article = FactoryGirl.build(:article, name: "test")
      @article.stub(:import!) # prevent the import because we want to create the related keys manually
      @article.save!
    end

    it "sets import_batch_id to nil" do
      @article.update! import_batch_id: "123"
      @article.send :update_import_finishing_fields!
      expect(@article.import_batch_id).to be_nil
    end

    it "sets first_import_finished_at when it is finished for the first time, and doesn't re-set it on later times" do
      expect(@article.first_import_finished_at).to be_nil
      @article.send :update_import_finishing_fields!

      expect(@article.first_import_finished_at).to be_present
      original_first_import_finished_at = @article.first_import_finished_at

      Timecop.freeze(original_first_import_finished_at + 1.day) do
        @article.send :update_import_finishing_fields!
        expect(@article.first_import_finished_at).to eql(original_first_import_finished_at)
      end
    end

    it "sets last_import_finished_at every time it is finished" do
      expect(@article.last_import_finished_at).to be_nil
      @article.send :update_import_finishing_fields!

      expect(@article.last_import_finished_at).to be_present
      original_last_import_finished_at = @article.last_import_finished_at

      Timecop.freeze(original_last_import_finished_at + 1.day) do
        @article.send :update_import_finishing_fields!
        expect(@article.last_import_finished_at).to_not eql(original_last_import_finished_at)
      end
    end
  end

  describe "#loading?" do
    before :each do
      @article = FactoryGirl.build(:article, name: "test")
      @article.stub(:import!) # prevent the import because we want to handle this manually
      @article.save!
    end

    it "returns true if neither `last_import_requested_at` nor `last_import_finished_at` is set" do
      @article.update! last_import_requested_at: nil, last_import_finished_at: nil
      expect(@article.loading?).to be_true
    end

    it "returns true if `last_import_requested_at` is set but `last_import_finished_at` is not set (after a Article is first created)" do
      @article.update! last_import_requested_at: Time.now, last_import_finished_at: nil
      expect(@article.loading?).to be_true
    end

    it "returns false if `last_import_finished_at` is greater than `last_import_requested_at` (after an import is finished)" do
      @article.update! last_import_requested_at: 2.minutes.ago, last_import_finished_at: 1.minutes.ago
      expect(@article.loading?).to be_false
    end

    it "returns true if `last_import_finished_at` is less than `last_import_requested_at` (after a re-import is scheduled)" do
      @article.update! last_import_requested_at: 1.minutes.ago, last_import_finished_at: 2.minutes.ago
      expect(@article.loading?).to be_true
    end

    it "returns false if `last_import_finished_at` is equal to `last_import_requested_at` (an import finished very fast)" do
      t = Time.now
      @article.update! last_import_requested_at: t, last_import_finished_at: t
      expect(@article.loading?).to be_false
    end
  end

  # ======== END IMPORT RELATED CODE ===================================================================================

  # ======== START ERRORS RELATED CODE =================================================================================

  describe Article::LastImportNotFinished do
    describe "#initialize" do
      it "creates a Article::LastImportNotFinished which is a kind of StandardError that has a message derived from the given Article" do
        article = FactoryGirl.create(:article)
        err = Article::LastImportNotFinished.new(article)
        expect(err).to be_a_kind_of(StandardError)
      end
    end
  end

  # ======== END ERRORS RELATED CODE ===================================================================================

  # ======== START INTEGRATION TESTS ===================================================================================

  it "Article's ready is set to true when the last Translation is translated, but not before" do
    article = FactoryGirl.create(:article, ready: false, sections_hash: { "main" => "<p>hello</p><p>world</p>" }, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
    expect(article.reload.keys.count).to eql(2)

    last_es_translation = article.translations.in_locale(Locale.from_rfc5646('es')).last

    (article.translations.to_a - [last_es_translation]).each do |translation|
      translation.update! copy: "<p>test</p>", approved: true
      expect(article.reload).to_not be_ready # expect Article to be not ready if not all required translations are approved
    end

    last_es_translation.update! copy: "<p>test</p>", approved: true
    article.keys.reload.each(&:recalculate_ready!)
    expect(article.reload).to be_ready
  end

  it "Article's ready is set to false when all Translations were initially approved but one of them gets unapproved" do
    article = FactoryGirl.create(:article, ready: false, sections_hash: { "main" => "<p>hello</p><p>world</p>" }, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => true, 'ja' => false })
    expect(article.reload.keys.count).to eql(2)

    article.translations.where(approved: nil).each { |translation| translation.update!  copy: "<p>test</p>", approved: true }
    article.keys.reload.each(&:recalculate_ready!)
    expect(article.reload).to be_ready

    last_es_translation = article.translations.in_locale(Locale.from_rfc5646('es')).last

    last_es_translation.update! approved: false
    article.keys.reload.each(&:recalculate_ready!)
    expect(article.reload).to_not be_ready
  end

  # ======== END INTEGRATION TESTS =====================================================================================
end
