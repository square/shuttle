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
require 'models/concerns/common_locale_logic_spec'

RSpec.describe Group do
  # ======== START BASIC CRUD RELATED CODE =============================================================================
  describe "[validations]" do
    it "doesn't allow creating 2 Groups in the same project with the same name" do
      group = FactoryBot.create(:group, name: "hello")
      group_new = FactoryBot.build(:group, name: "hello", project: group.project).tap(&:save)
      expect(group_new).to_not be_persisted
      expect(group_new.errors.messages).to eql({:name =>["already taken"]})
    end

    it "allows creating 2 Groups with the same name under different projects" do
      FactoryBot.create(:group, name: "hello")
      group_new = FactoryBot.build(:group, name: "hello", project: FactoryBot.create(:project)).tap(&:save)
      expect(group_new).to be_persisted
      expect(group_new.errors).to_not be_any
    end

    it "doesn't allow creating without a name" do
      group = FactoryBot.build(:group, name: nil).tap(&:save)
      expect(group).to_not be_persisted
      expect(group.errors.messages).to eql({name: ["can’t be blank"]})
    end

    it "doesn't allow name to be 'new'" do
      group = FactoryBot.build(:group, name: 'new').tap(&:save)
      expect(group.errors.full_messages).to include("Name reserved")
    end
  end

  describe '[scopes]' do
    context '#hidden' do
      let!(:group1) { FactoryBot.create(:group, hidden: true) }
      let!(:group2) { FactoryBot.create(:group, hidden: false) }

      it 'returns only the hidden groups' do
        expect(Group.hidden).to match_array([group1])
      end

      it '#showing returns only the showing groups' do
        expect(Group.showing).to match_array([group2])
      end
    end

    context '#ready' do
      let!(:group1) { FactoryBot.create(:group, ready: true) }
      let!(:group2) { FactoryBot.create(:group, ready: false) }

      it 'returns only the ready groups' do
        expect(Group.ready).to match_array([group1])
      end

      it '#not_ready returns only the ready groups' do
        expect(Group.not_ready).to match_array([group2])
      end
    end
  end

  context '#loading' do
    let!(:group1) { FactoryBot.create(:group, loading: true) }
    let!(:group2) { FactoryBot.create(:group, loading: false) }

    it 'returns only the loading groups' do
      expect(Group.loading).to match_array([group1])
    end
  end
  # ======== END BASIC CRUD RELATED CODE ===============================================================================

  describe '#project' do
    let(:project) { FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
    let(:group) { FactoryBot.create(:group, project: project) }

    it 'has proper project' do
      expect(group.project).to eq(project)
    end
  end

  describe '#articles' do
    let(:project) { FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
    let(:group) { FactoryBot.create(:group, project: project) }

    let(:article1) { FactoryBot.create(:article, targeted_rfc5646_locales: {'fr' => true}) }
    let(:article2) { FactoryBot.create(:article, targeted_rfc5646_locales: {'fr' => true}) }

    let!(:article_group1) { FactoryBot.create(:article_group, article: article1, group: group, index_in_group: 2) }
    let!(:article_group2) { FactoryBot.create(:article_group, article: article2, group: group, index_in_group: 1) }

    it 'has proper articles' do
      expect(Group.find(group.id).articles).to match_array([article1, article2])
    end

    it 'destroys its article_groups after group is destroyed' do
      group.destroy

      expect(ArticleGroup.where(group_id: group.id)).to eq([])
    end
  end

  describe '#to_param' do
    let(:group) { FactoryBot.create(:group, loading: true) }

    it 'returns name of group' do
      expect(group.to_param).to eq(group.display_name)
    end
  end

  describe '#recalculate_ready!' do
    let(:project) { FactoryBot.create(:project, repository_url: nil, base_rfc5646_locale: 'en', targeted_rfc5646_locales: { 'fr' => true, 'es' => false } ) }
    let(:group) { FactoryBot.create(:group, project: project) }

    let(:article1) { FactoryBot.create(:article, targeted_rfc5646_locales: {'fr' => true}) }
    let(:article2) { FactoryBot.create(:article, targeted_rfc5646_locales: {'fr' => true}) }

    let!(:article_group1) { FactoryBot.create(:article_group, article: article1, group: group, index_in_group: 2) }
    let!(:article_group2) { FactoryBot.create(:article_group, article: article2, group: group, index_in_group: 1) }

    it 'article observer callback is triggered' do
      expect(group.ready).to be_falsey

      article1.update(ready: true)
      expect(group.reload.ready).to be_falsey

      article2.update(ready: true)
      expect(group.reload.ready).to be_truthy

      article1.update(ready: false)
      expect(group.reload.ready).to be_falsey
    end
  end
end
