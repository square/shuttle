require 'spec_helper'

describe LocaleProjectsShowForm do
  describe '#process_params' do
    let (:project) { FactoryGirl.create(:project) }
    it 'should use the provided include flags if some specified' do
      params = { id: project.to_param, include_translated: '1' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:include_translated]).to be true

      params = { id: project.to_param, include_approved: '1' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:include_approved]).to be true

      params = { id: project.to_param, include_new: '1' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:include_new]).to be true
    end

    it 'should default to include_translated and include_new if no flags specified' do
      form = LocaleProjectsShowForm.new({ id: project.to_param })
      expect(form[:include_new]).to be true
      expect(form[:include_approved]).to be false
      expect(form[:include_translated]).to be true
    end

    it 'should use the page specified or default to page 1' do
      form = LocaleProjectsShowForm.new({ id: project.to_param })
      expect(form[:page]).to be 1

      form = LocaleProjectsShowForm.new({ id: project.to_param, page: 2 })
      expect(form[:page]).to be 2
    end

    it 'should get the filter' do
      params = { id: project.to_param, filter: 'test filter :D' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:query_filter]).to eql 'test filter :D'
    end

    it 'should get the filter source' do
      params = { id: project.to_param, filter_source: 'Source' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:filter_source]).to eql 'Source'
    end

    it 'should extract and set the project information' do
      params = { id: project.to_param }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:project]).to eql project
      expect(form[:project_id]).to eql project.id
    end

    it 'should set the commit information' do
      proj = FactoryGirl.create(:project,
                                base_rfc5646_locale:      'en',
                                targeted_rfc5646_locales: { 'fr' => true },
                                repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)

      commit = proj.commit!('HEAD', skip_import: true)
      key = FactoryGirl.create(:key, project: proj, ready: false)
      key.add_pending_translations
      commit.keys = [key]
      params = { id: proj.to_param, commit: commit.to_param }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:commit]).to eql commit.to_param
      expect(form[:translation_ids_in_commit].size).to eql 2
    end

    it 'should get the article id if article id specified' do
      article = FactoryGirl.create(:article, project: project)
      section = FactoryGirl.create(:section, article: article)
      params = { id: project.to_param, article_id: article.id, section_id: section.id }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:article_id]).to eql article.id
      expect(form[:section_id]).to eql section.id
    end

    it 'should get the article id if article name specified' do
      article = FactoryGirl.create(:article, project: project)
      section = FactoryGirl.create(:section, article: article)
      params = { id: project.to_param, article_name: article.name, section_id: section.id }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:article_id]).to eql article.id
      expect(form[:section_id]).to eql section.id
    end

    it 'builds a locale from the specified locale' do
      params = { id: project.to_param, locale_id: 'en' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:locale]).to eql Locale.from_rfc5646('en')

      params = { id: project.to_param, locale_id: 'en123123' }
      form = LocaleProjectsShowForm.new(params)
      expect(form[:locale]).to be nil
    end
  end
end
