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

require 'rails_helper'

RSpec.describe SectionImporter do
  describe "#perform" do
    it "calls import_strings on the Core model" do
      allow_any_instance_of(Article).to receive(:import!)
      section = FactoryBot.create(:section)
      expect(SectionImporter::Core).to receive(:new).and_call_original
      expect_any_instance_of(SectionImporter::Core).to receive(:import_strings)

      SectionImporter.new.perform(section.id)
    end
  end
end

RSpec.describe SectionImporter::Core do
  describe "import_strings" do
    before(:each) { allow_any_instance_of(Article).to receive(:import!) } # prevent automatic import

    it "doesn't call rebase_existing_keys or deactivate_all_keys if this is the initial import" do
      section = FactoryBot.create(:section)
      importer = SectionImporter::Core.new(section)
      expect(importer).to_not receive(:rebase_existing_keys)
      expect(importer).to_not receive(:deactivate_all_keys)
      expect(importer).to receive(:split_into_paragraphs).and_call_original
      importer.import_strings
    end

    it "splits source_copy into paragraphs, creates Keys for each paragraph, creates base & targeted Translations for each Key" do
      article = FactoryBot.create(:article, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false })
      section = FactoryBot.create(:section, article: article, source_copy: "<p>a</p><p>b</p>")
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)

      expect(keys.length).to eql(6)
      expect(keys[0].source_copy).to eql("<p>")
      expect(keys[0].index_in_section).to eql(0)
      expect(keys[1].source_copy).to eql("a")
      expect(keys[1].index_in_section).to eql(1)

      expect(section.translations.length).to eql(18)
      keys.each do |key|
        expect(key.project).to eql(section.project)
        expect(key.translations.map(&:rfc5646_locale).sort).to eql(%w(en fr es).sort)

        key.translations.not_block_tag.each do |translation|
          expect(key).to_not  be_ready
        end

        key.translations.each do |translation|
          expect(translation.source_copy).to eql(key.source_copy) # check source copies
          expect(translation.source_rfc5646_locale).to eql('en')
        end

        key.translations.not_base.not_block_tag.each do |translation|
          expect(translation.copy).to eql(nil) # check copies
        end

        key.translations.base.each do |translation|
          expect(translation).to be_approved
          expect(translation.copy).to eql(key.source_copy)
        end
      end
    end

    it "re-imports a Section, uses untouched paragraphs by default, unapproves them if their neighbors have changed" do
      article = FactoryBot.create(:article, targeted_rfc5646_locales: { 'fr' => true, 'es' => false })
      section = FactoryBot.create(:section, article: article, source_copy: "<p>a</p><p>b</p><p>c</p><p>d</p><p>e</p>")
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)
      expect(keys.length).to eql(15)
      expect(section.translations.length).to eql(45)

      keys[1].translations.in_locale(Locale.from_rfc5646('fr')).first.update! copy: "<p>translated</p>", approved: true
      keys[1].translations.in_locale(Locale.from_rfc5646('es')).first.update! copy: "<p>translated</p>"
      keys[2].translations.in_locale(Locale.from_rfc5646('es')).first.update! copy: "<p>translated</p>", approved: true

      keys.each(&:recalculate_ready!)

      expect(keys[1].reload).to be_ready

      article.update! targeted_rfc5646_locales: { 'ja' => true, 'fr' => false }
      section.update! source_copy: "<p>x</p><p>a</p><p>b</p><p>c</p><p>y</p>"
      SectionImporter::Core.new(section).import_strings

      keys = section.reload.keys.order(:index_in_section)
      expect(keys.length).to eql(17) # with the old unused keys

      expect(section.active_translations.length).to eql(54)
      expect(section.active_translations.not_base.approved.count).to eql(28)
      expect(section.translations.not_base.approved.count).to eql(28)
    end
  end

  describe "#rebase_existing_keys" do
    before(:each) { allow_any_instance_of(Article).to receive(:import!) } # prevent automatic import

    before :each do
      @article = FactoryBot.create(:article,
                                    targeted_rfc5646_locales: { 'fr' => true },
                                    last_import_requested_at: 2.hours.ago,
                                    last_import_finished_at: 1.hour.ago)
      @section = FactoryBot.create(:section, article: @article, source_copy: "<p>a</p><p>b</p><p>c</p>")
    end

    it "calls reset_approved_if_neighbor_changed! & update_indexes_of_unchanged_keys!" do
      importer = SectionImporter::Core.new(@section)

      expect(importer).to receive(:reset_approved_if_neighbor_changed!)
      expect(importer).to receive(:update_indexes_of_unchanged_keys!)
      importer.send :rebase_existing_keys, ["<p>x</p>", "<p>a</p>", "<p>b</p>", "<p>c</p>"]
    end

    it "handles addition to the start" do
      SectionImporter.new.perform(@section.id)
      expect(@section.reload.keys.count).to eql(9)

      @section.translations.not_base.each do |translation|
        translation.update_attributes! copy: "<p>translated</p>", approved: true
      end
      @section.keys.each(&:recalculate_ready!)
      expect(@article.reload.tap(&:recalculate_ready!)).to be_ready
      SectionImporter::Core.new(@section).send :rebase_existing_keys, ["<p>x</p>", "<p>a</p>", "<p>b</p>", "<p>c</p>"]

      existing_keys = @section.reload.sorted_active_keys_with_translations
      expect(existing_keys[0].key).to start_with('0:')
      expect(existing_keys[1].key).to start_with('1:')
      expect(existing_keys[2].key).to start_with('2:')
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
        tagged_existing_paragraphs = original_existing_paragraphs.map { |prgh| "<#{tag}>#{prgh}</#{tag}>" }

        allow_any_instance_of(Article).to receive(:import!)
        article = FactoryBot.create(:article, targeted_rfc5646_locales: { 'fr' => true })
        section = FactoryBot.create(:section, article: article, source_copy: tagged_existing_paragraphs.join)
        SectionImporter.new.perform(section.id)

        existing_keys = section.reload.sorted_active_keys_with_translations.reject(&:is_block_tag)
        section.translations.each { |key| key.update! approved: true, copy: key.key.is_block_tag ? key.source_copy : 'translated' }
        expect(section.reload.translations.all? { |t| t.approved? }).to be_truthy
        existing_paragraphs = existing_keys.map(&:source_copy)

        expect(existing_paragraphs).to eql(original_existing_paragraphs)
        sdiff = Diff::LCS.sdiff(existing_paragraphs, new_paragraphs)

        SectionImporter::Core.new(section).send :reset_approved_if_neighbor_changed!, existing_keys.reject(&:is_block_tag), sdiff

        existing_keys = section.reload.sorted_active_keys_with_translations # reload them to get the latest changes

        expected_approved_states.each_with_index do |expected_approved_state, index|
          existing_keys.reject(&:is_block_tag)[index].translations.not_base.each do |translation|
            expect(translation.approved?).to eql(expected_approved_state)
          end
        end
      end
    end
  end

  describe "#update_indexes_of_unchanged_keys!" do
    before(:each) { allow_any_instance_of(Article).to receive(:import!) } # prevent automatic import

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
        tagged_existing_paragraphs = original_existing_paragraphs.map { |prgh| ["<#{tag}>", prgh, "</#{tag}>"] }.flatten

        article = FactoryBot.create(:article, targeted_rfc5646_locales: { 'fr' => true })
        section = FactoryBot.create(:section, article: article, source_copy: tagged_existing_paragraphs.join)
        SectionImporter.new.perform(section.id)

        existing_keys = section.reload.sorted_active_keys_with_translations
        expect(existing_keys.count).to eql(original_existing_paragraphs.count * 3)
        existing_paragraphs_with_tags = existing_keys.map(&:source_copy)
        new_paragraphs_with_tags = new_paragraphs.map { |prgh| ["<#{tag}>", prgh, "</#{tag}>"] }.flatten

        sdiff = Diff::LCS.sdiff(existing_paragraphs_with_tags, new_paragraphs_with_tags)

        tagged_existing_paragraphs.each_with_index do |paragraph, index|
          expect(existing_keys[index].index_in_section).to eql(index)
          expect(existing_keys[index].key).to eql(SectionKeyCreator.generate_key_name(existing_keys[index].source_copy, existing_keys[index].index_in_section))
        end

        SectionImporter::Core.new(section).send :update_indexes_of_unchanged_keys!, existing_keys, sdiff

        tagged_existing_paragraphs.each_with_index do |_, index|
          next if existing_keys[index].is_block_tag
          expect(existing_keys[index].reload.key).to eql(SectionKeyCreator.generate_key_name(existing_keys[index].source_copy, (expected_new_indexes_in_key_name.shift * 3) + 1))
        end
      end
    end

    it "removes conflicting keys before the rebase" do
      article = FactoryBot.create(:article, targeted_rfc5646_locales: { 'fr' => true })
      section = FactoryBot.create(:section, article: article, source_copy: "a")
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
          paragraphs: ["<p>", "paragraph a", "</p>"]},
        { text:        "<span>paragraph a</span><span>paragraph b</span>",
          paragraphs: ["<span>paragraph a</span><span>paragraph b</span>"]},
        { text:        "<body><p>paragraph a</p><p>paragraph b</p><p>paragraph c</p></body>",
          paragraphs: ["<body>", "<p>", "paragraph a", "</p>", "<p>", "paragraph b", "</p>", "<p>", "paragraph c", "</p>", "</body>"]},
        { text:        "<html><meta bla=bla> \>   <body>   <p>paragraph a</p>  \n\n <div>paragraph b</div>paragraph c<ul>  \n <li>paragraph d</li></ul>  paragraph e</body></html>",
          paragraphs: ["<html>", "<meta bla=bla> \>", "   <body>   ", "<p>", "paragraph a", "</p>  \n\n ", "<div>", "paragraph b", "</div>", "paragraph c", "<ul>  \n ", "<li>", "paragraph d", "</li>", "</ul>  ", "paragraph e", "</body>", "</html>"]},
        { text:        "<html><body><div>paragraph a<p>paragraph b</p>paragraph c</div></body></html>",
          paragraphs: ["<html>", "<body>", "<div>", "paragraph a", "<p>", "paragraph b", "</p>", "paragraph c", "</div>", "</body>", "</html>"]},
        { text:        "<html><body><div>paragraph a <img src='fake' alt='hello' /></div></body></html>",
          paragraphs: ["<html>", "<body>", "<div>", "paragraph a <img src='fake' alt='hello' />", "</div>", "</body>", "</html>"]},
        { text:        "<html><body><table><thead><th>header</th></thead><tbody><tr><td>data</td></tr></tbody></body></html>",
          paragraphs: ["<html>", "<body>", "<table>", "<thead>","<th>", "header", "</th>", "</thead>", "<tbody>", "<tr>", "<td>", "data", "</td>", "</tr>", "</tbody>", "</body>", "</html>"]},
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
      article = FactoryBot.create(:article, sections_hash: { "main" => "<p>a</p><p>b</p><p>c</p>" })
      section = article.sections.first
      expect(section.reload.keys.where('index_in_section IS NOT NULL').count).to eql(9)
      expect(section.keys.where('index_in_section IS NULL').count).to eql(0)
      SectionImporter::Core.new(section).send :deactivate_all_keys
      expect(section.reload.keys.where('index_in_section IS NOT NULL').count).to eql(0)
      expect(section.keys.where('index_in_section IS NULL').count).to eql(9)
    end
  end
end
