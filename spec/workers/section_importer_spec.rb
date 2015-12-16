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

describe SectionImporter do
  describe "#perform" do
    it "calls import_strings on the Core model" do
      Article.any_instance.stub(:import!)
      section = FactoryGirl.create(:section)
      expect(SectionImporter::Core).to receive(:new).and_call_original
      SectionImporter::Core.any_instance.should_receive(:import_strings)

      SectionImporter.new.perform(section.id)
    end
  end
end

describe SectionImporter::Core do
  describe "import_strings" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent automatic import

    it "doesn't call rebase_existing_keys or deactivate_all_keys if this is the initial import" do
      section = FactoryGirl.create(:section)
      importer = SectionImporter::Core.new(section)
      expect(importer).to_not receive(:rebase_existing_keys)
      expect(importer).to_not receive(:deactivate_all_keys)
      expect(importer).to receive(:split_into_paragraphs).and_call_original
      importer.import_strings
    end

    it "splits source_copy into paragraphs, creates Keys for each paragraph, creates base & targeted Translations for each Key" do
      article = FactoryGirl.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false })
      section = FactoryGirl.create(:section, article: article, source_copy: "<p>a</p><p>b</p>")
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)

      expect(keys.length).to eql(2)
      expect(keys[0].source_copy).to eql("<p>a</p>")
      expect(keys[0].index_in_section).to eql(0)
      expect(keys[1].source_copy).to eql("<p>b</p>")
      expect(keys[1].index_in_section).to eql(1)

      expect(section.translations.length).to eql(6)
      keys.each do |key|
        expect(key).to_not be_ready
        expect(key.project).to eql(section.project)
        expect(key.translations.map(&:rfc5646_locale).sort).to eql(%w(en fr es).sort)

        key.translations.each do |translation|
          expect(translation.source_copy).to eql(key.source_copy) # check source copies
          expect(translation.source_rfc5646_locale).to eql('en')
        end

        key.translations.not_base.each do |translation|
          expect(translation.copy).to eql(nil) # check copies
        end

        key.translations.base.each do |translation|
          expect(translation).to be_approved
          expect(translation.copy).to eql(key.source_copy)
        end
      end
    end

    it "re-imports a Section, uses untouched paragraphs by default, unapproves them if their neighbors have changed" do
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true, 'es' => false })
      section = FactoryGirl.create(:section, article: article, source_copy: "<p>a</p><p>b</p><p>c</p><p>d</p><p>e</p>")
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)
      expect(keys.length).to eql(5)
      expect(section.translations.length).to eql(15)

      keys[1].translations.in_locale(Locale.from_rfc5646('fr')).first.update! copy: "<p>translated</p>", approved: true
      keys[1].translations.in_locale(Locale.from_rfc5646('es')).first.update! copy: "<p>translated</p>"
      keys[2].translations.in_locale(Locale.from_rfc5646('es')).first.update! copy: "<p>translated</p>", approved: true

      keys.each(&:recalculate_ready!)

      expect(keys[1].reload).to be_ready

      article.update! targeted_rfc5646_locales: { 'ja' => true, 'fr' => false }
      section.update! source_copy: "<p>x</p><p>a</p><p>b</p><p>c</p><p>y</p>"
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)
      expect(keys.length).to eql(7) # with the old unused keys

      expect(section.active_translations.length).to eql(17)
      expect(section.active_translations.not_base.approved.count).to eql(1)
      expect(section.translations.not_base.approved.count).to eql(1)
    end
  end

  describe "#rebase_existing_keys" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent automatic import

    before :each do
      @article = FactoryGirl.create(:article,
                                    targeted_rfc5646_locales: { 'fr' => true },
                                    last_import_requested_at: 2.hours.ago,
                                    last_import_finished_at: 1.hour.ago)
      @section = FactoryGirl.create(:section, article: @article, source_copy: "<p>a</p><p>b</p><p>c</p>")
    end

    it "calls reset_approved_if_neighbor_changed! & update_indexes_of_unchanged_keys!" do
      importer = SectionImporter::Core.new(@section)

      expect(importer).to receive(:reset_approved_if_neighbor_changed!)
      expect(importer).to receive(:update_indexes_of_unchanged_keys!)
      importer.send :rebase_existing_keys, ["<p>x</p>", "<p>a</p>", "<p>b</p>", "<p>c</p>"]
    end

    it "handles addition to the start" do
      SectionImporter.new.perform(@section.id)
      expect(@section.reload.keys.count).to eql(3)

      @section.translations.not_base.each { |translation| translation.update! copy: "<p>translated</p>", approved: true }
      @section.keys.each(&:recalculate_ready!)
      expect(@article.reload.tap(&:recalculate_ready!)).to be_ready
      SectionImporter::Core.new(@section).send :rebase_existing_keys, ["<p>x</p>", "<p>a</p>", "<p>b</p>", "<p>c</p>"]

      existing_keys = @section.reload.sorted_active_keys_with_translations
      expect(existing_keys[0].key).to start_with('1:')
      expect(existing_keys[1].key).to start_with('2:')
      expect(existing_keys[2].key).to start_with('3:')
    end
  end

  describe "#reset_approved_if_neighbor_changed!!" do
    SCENARIOS_REGARDING_NEIGHBOR_RESETING = [
        [ %w(a), %w(x a), [false], "handles simple insertion to the start" ],
        [ %w(a b), %w(x a b), [false, true], "handles simple insertion to the start" ],
        [ %w(a b), %w(a x b), [false, false], "handles simple insertion to the middle" ],
        [ %w(a b), %w(a b x), [true, false], "handles simple insertion to the end" ],
        [ %w(a b c), %w(b c), [false, false, true], "handles simple removal from the start" ],
        [ %w(a b c), %w(a c), [false, false, false], "handles simple removal from the middle" ],
        [ %w(a b c), %w(a b), [true, false, false], "handles simple removal from the end" ],
        [ %w(a b c), %w(a x c), [false, false, false], "handles simple edit in the middle" ],
        [ %w(a b c), %w(b a c), [false, false, false], "handles simple order change" ],
        [ %w(a b c c c), %w(a b c c), [true, true, true, false, false], "handles multiple removals with duplicate paragraphs" ],
        [ %w(a b c c c), %w(a c), [false, false, false, false, false], "handles multiple removals with duplicate paragraphs" ],
        [ %w(a b c d e), %w(a g e), [false, false, false, false, false], "handles complex cases" ],
        [ %w(a a a), %w(a a), [true, false, false], "handles edge cases" ],
        [ %w(a b c d e f g h i j), %w(a b c x y g h i), [true, true, false, false, false, false, false, true, false], "handles complex cases" ],
    ]

    SCENARIOS_REGARDING_NEIGHBOR_RESETING.each do |original_existing_paragraphs, new_paragraphs, expected_approved_states, handles_what|
      it handles_what do
        tag = "p"
        original_existing_paragraphs = original_existing_paragraphs.map { |prgh| "<#{tag}>#{prgh}</#{tag}>" }
        new_paragraphs = new_paragraphs.map { |prgh| "<#{tag}>#{prgh}</#{tag}>" }

        Article.any_instance.stub(:import!)
        article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true })
        section = FactoryGirl.create(:section, article: article, source_copy: original_existing_paragraphs.join)
        SectionImporter.new.perform(section.id)

        existing_keys = section.reload.sorted_active_keys_with_translations
        section.translations.each { |key| key.update! approved: true, copy: "<#{tag}>translated</#{tag}>" }
        expect(section.reload.translations.all? { |t| t.approved? }).to be_true
        existing_paragraphs = existing_keys.map(&:source_copy)

        expect(existing_paragraphs).to eql(original_existing_paragraphs)
        sdiff = Diff::LCS.sdiff(existing_paragraphs, new_paragraphs)

        SectionImporter::Core.new(section).send :reset_approved_if_neighbor_changed!, existing_keys, sdiff

        existing_keys = section.reload.sorted_active_keys_with_translations # reload them to get the latest changes

        expected_approved_states.each_with_index do |expected_approved_state, index|
          existing_keys[index].translations.not_base.each do |translation|
            expect(translation.approved?).to eql(expected_approved_state)
          end
        end
      end
    end
  end

  describe "#update_indexes_of_unchanged_keys!" do
    before(:each) { Article.any_instance.stub(:import!) } # prevent automatic import

    SCENARIOS_REGARDING_INDEX_UPDATES = [
        [ %w(a b), %w(x a b), [1, 2], "handles simple insertion to the start" ],
        [ %w(a b c), %w(c), [0, 1, 0], "handles simple removal from the start" ],
        [ %w(a a), %w(c a a), [1, 2], "handles edge case" ],
        [ %w(c a a), %w(a a), [0, 0, 1], "handles edge case" ],
        [ %w(a b c d e), %w(a x d e f), [0, 1, 2, 2, 3], "handles edge case" ],
    ]

    SCENARIOS_REGARDING_INDEX_UPDATES.each do |original_existing_paragraphs, new_paragraphs, expected_new_indexes_in_key_name, handles_what|
      it handles_what do
        tag = "p"
        original_existing_paragraphs = original_existing_paragraphs.map { |prgh| "<#{tag}>#{prgh}</#{tag}>" }
        new_paragraphs = new_paragraphs.map { |prgh| "<#{tag}>#{prgh}</#{tag}>" }

        article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true })
        section = FactoryGirl.create(:section, article: article, source_copy: original_existing_paragraphs.join)
        SectionImporter.new.perform(section.id)

        existing_keys = section.reload.sorted_active_keys_with_translations
        expect(existing_keys.count).to eql(original_existing_paragraphs.count)
        existing_paragraphs = existing_keys.map(&:source_copy)

        sdiff = Diff::LCS.sdiff(existing_paragraphs, new_paragraphs)

        original_existing_paragraphs.each_with_index do |paragraph, index|
          expect(existing_keys[index].index_in_section).to eql(index)
          expect(existing_keys[index].key).to eql(SectionKeyCreator.generate_key_name(existing_keys[index].source_copy, index))
        end

        SectionImporter::Core.new(section).send :update_indexes_of_unchanged_keys!, existing_keys, sdiff

        original_existing_paragraphs.each_with_index do |_, index|
          expect(existing_keys[index].reload.key).to eql(SectionKeyCreator.generate_key_name(existing_keys[index].source_copy, expected_new_indexes_in_key_name[index]))
        end
      end
    end

    it "removes conflicting keys before the rebase" do
      article = FactoryGirl.create(:article, targeted_rfc5646_locales: { 'fr' => true })
      section = FactoryGirl.create(:section, article: article, source_copy: "a")
      SectionImporter.new.perform(section.id)

      section.keys.create! key: "_old_:#{section.reload.keys.first.key}", project: section.project # creates a conflicting key for the first part of the rebase

      section.keys.create! key: "1:#{section.keys.first.key.split(':').last}", project: section.project # creates a conflicting key for the second part of the rebase

      SectionImporter::Core.new(section).send :update_indexes_of_unchanged_keys!,
                                              section.reload.sorted_active_keys_with_translations,
                                              Diff::LCS.sdiff(%w(a), %w(x a))
    end
  end

  describe "#split_into_paragraphs" do
    TEXT_TO_EXPECTED_PARAGRAPHS = [
        { text:        "<p>paragraph a</p>",
          paragraphs: ["<p>paragraph a</p>"]},
        { text:        "<span>paragraph a</span><span>paragraph b</span>",
          paragraphs: ["<span>paragraph a</span><span>paragraph b</span>"]},
        { text:        "<body><p>paragraph a</p><p>paragraph b</p><p>paragraph c</p></body>",
          paragraphs: ["<body>", "<p>paragraph a</p>", "<p>paragraph b</p>", "<p>paragraph c</p>", "</body>"]},
        { text:        "<html><meta bla=bla> \>   <body>   <p>paragraph a</p>  \n\n <div>paragraph b</div>paragraph c<ul>  \n <li>paragraph d</li></ul>  paragraph e</body></html>",
          paragraphs: ["<html><meta bla=bla> >   <body>   ", "<p>paragraph a</p>", "<div>paragraph b</div>", "paragraph c<ul>  \n ", "<li>paragraph d</li>", "</ul>  paragraph e</body></html>"]},
        { text:        "<html><body><div>paragraph a<p>paragraph b</p>paragraph c</div></body></html>",
          paragraphs: ["<html><body>", "<div>paragraph a", "<p>paragraph b</p>", "paragraph c</div>", "</body></html>"]},
        { text:        "<html><body><div>paragraph a <img src='fake' alt='hello' /></div></body></html>",
          paragraphs: ["<html><body>", "<div>paragraph a <img src='fake' alt='hello' /></div>", "</body></html>"]},
        { text:        "<html><body><table><thead><th>header</th></thead><tbody><tr><td>data</td></tr></tbody></body></html>",
          paragraphs: ["<html><body><table>", "<thead>","<th>header</th>", "</thead><tbody><tr>", "<td>data</td>", "</tr></tbody></body></html>"]},
    ]

    let(:importer) { SectionImporter::Core.new(nil) }

    TEXT_TO_EXPECTED_PARAGRAPHS.each do |text_and_paragraphs_hash|
      it "should split up into right paragraphs" do
        expect(importer.send(:split_into_paragraphs, text_and_paragraphs_hash.fetch(:text))).to eql(text_and_paragraphs_hash.fetch(:paragraphs))
      end
    end
  end

  describe "#deactivate_all_keys" do
    it "inactivates all Keys in an Article" do
      article = FactoryGirl.create(:article, sections_hash: { "main" => "<p>a</p><p>b</p><p>c</p>" })
      section = article.sections.first
      expect(section.reload.keys.where('index_in_section IS NOT NULL').count).to eql(3)
      expect(section.keys.where('index_in_section IS NULL').count).to eql(0)
      SectionImporter::Core.new(section).send :deactivate_all_keys
      expect(section.reload.keys.where('index_in_section IS NOT NULL').count).to eql(0)
      expect(section.keys.where('index_in_section IS NULL').count).to eql(3)
    end
  end
end
