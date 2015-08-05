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
require 'fileutils'

describe CommitsController do
  shared_examples_for "returns error string if repository_url is blank" do |action|
    it "should return an error string if repository_url is blank" do
      user = FactoryGirl.create(:user, :confirmed, role: 'monitor')
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in user

      project = FactoryGirl.create(:project, repository_url: nil)
      post action, project_id: project.to_param, id: 'HEAD', format: 'json'
      expect(response.body).to include("This project does not have a repository url. This action only applies to projects that have a repository.")
    end
  end


  describe "#manifest" do
    before :each do
      @project      = FactoryGirl.create(:project,
                                         base_rfc5646_locale:      'en-US',
                                         targeted_rfc5646_locales: {'en-US' => true, 'en' => true, 'fr' => true, 'de' => false},
                                         repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit       = @project.commit!('HEAD^', skip_import: true)
      @newer_commit = @project.commit!('HEAD', skip_import: true)

      @commit.update_attributes(loading: false, loaded_at: Time.now)
      @newer_commit.update_attributes(loading: false, loaded_at: Time.now)

      key1 = FactoryGirl.create(:key,
                                project: @project,
                                key:     'key1',
                                context: "Universal Greeting",
                                source:  'foo/bar.txt')
      key2 = FactoryGirl.create(:key,
                                project: @project,
                                key:     'key2',
                                context: "Shopping cart contents",
                                source:  'foo/bar.txt')

      @commit.keys = [key1, key2]

      FactoryGirl.create :translation,
                         key:                   key1,
                         source_copy:           "Hi {name}! You have {count} items.",
                         copy:                  "Hi {name}! You have {count} items.",
                         source_rfc5646_locale: 'en-US',
                         rfc5646_locale:        'en',
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key1,
                         source_copy:           "Hi {name}! You have {count} items.",
                         copy:                  "Bonjour {name}! Avec anninas fromage {count} la bouches.",
                         source_rfc5646_locale: 'en-US',
                         rfc5646_locale:        'fr',
                         approved:              true

      FactoryGirl.create :translation,
                         key:                   key2,
                         source_copy:           "Your cart has {count} items",
                         copy:                  "Your cart has {count} items",
                         source_rfc5646_locale: 'en-US',
                         rfc5646_locale:        'en',
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key2,
                         source_copy:           "Hi {name}! You have {count} items.",
                         copy:                  "Tu avec carté {count} itém has",
                         source_rfc5646_locale: 'en-US',
                         rfc5646_locale:        'fr',
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key2,
                         source_copy:           "Hi {name}! You have {count} items.",
                         copy:                  "Hallo {name}! Du hast {count} Itemen.",
                         source_rfc5646_locale: 'en-US',
                         rfc5646_locale:        'de',
                         approved:              true

      @commit.update_column :ready, true
    end

    context '[formats]' do
      it "should export a YAML file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.yaml"')
        expect(response.body).to eql(<<-YAML)
---
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
        YAML
      end

      it "should export a YAML file in the multiple locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'en,fr', format: 'yaml'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.yaml"')
        expect(response.body).to eql(<<-YAML)
---
en:
  key1: Hi {name}! You have {count} items.
  key2: Your cart has {count} items
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
        YAML
      end

      it "should export a YAML file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'yaml'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.yaml"')
        expect(response.body).to eql(<<-YAML)
---
en:
  key1: Hi {name}! You have {count} items.
  key2: Your cart has {count} items
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
        YAML
      end

      it "should export an Ember.js file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'js'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.js"')
        expect(response.body).to eql(<<-JS)
Ember.I18n.locales.translations.fr = {
  "key1": "Bonjour {name}! Avec anninas fromage {count} la bouches.",
  "key2": "Tu avec carté {count} itém has"
};
        JS
      end

      it "should export an Ember.js file in multiple locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'en,fr', format: 'js'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.js"')
        expect(response.body).to eql(<<-JS)
Ember.I18n.locales.translations.en = {
  "key1": "Hi {name}! You have {count} items.",
  "key2": "Your cart has {count} items"
};
Ember.I18n.locales.translations.fr = {
  "key1": "Bonjour {name}! Avec anninas fromage {count} la bouches.",
  "key2": "Tu avec carté {count} itém has"
};
        JS
      end

      it "should export an Ember.js file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.js"')
        expect(response.body).to eql(<<-JS)
Ember.I18n.locales.translations.en = {
  "key1": "Hi {name}! You have {count} items.",
  "key2": "Your cart has {count} items"
};
Ember.I18n.locales.translations.fr = {
  "key1": "Bonjour {name}! Avec anninas fromage {count} la bouches.",
  "key2": "Tu avec carté {count} itém has"
};
        JS
      end

      it "should export a UTF-16 Strings file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'strings'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.strings"')
        expect(response.headers['Content-Type']).to eql('text/plain; charset=utf-16le')
        expect(response.body.encoding.to_s).to eql('UTF-16LE')

        body = response.body.encode('UTF-8')
        expect(body).to include(<<-C)
/* Universal Greeting */
"key1" = "Bonjour {name}! Avec anninas fromage {count} la bouches.";
        C
        expect(body).to include(<<-C)
/* Shopping cart contents */
"key2" = "Tu avec carté {count} itém has";
        C
      end

      it "should export a Java properties file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'properties'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.properties"')

        expect(response.body).to include(<<-C)
key1=Bonjour {name}! Avec anninas fromage {count} la bouches.
        C
        expect(response.body).to include(<<-C)
key2=Tu avec carté {count} itém has
        C
      end

      it "should export an iOS tarball manifest" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'ios'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.tar.gz"')
        # check body?
      end

      it "should export a Ruby file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'rb'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.rb"')
        expect(response.body).to eql(<<-RUBY)
{"fr"=>
  {"key1"=>"Bonjour {name}! Avec anninas fromage {count} la bouches.",
   "key2"=>"Tu avec carté {count} itém has"}}
        RUBY
      end

      it "should export a Ruby file in multiple locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'en,fr', format: 'rb'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.rb"')
        expect(response.body).to eql(<<-RUBY)
{"en"=>
  {"key1"=>"Hi {name}! You have {count} items.",
   "key2"=>"Your cart has {count} items"},
 "fr"=>
  {"key1"=>"Bonjour {name}! Avec anninas fromage {count} la bouches.",
   "key2"=>"Tu avec carté {count} itém has"}}
        RUBY
      end

      it "should export a Ruby file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'rb'
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.rb"')
        expect(response.body).to eql(<<-RUBY)
{"en"=>
  {"key1"=>"Hi {name}! You have {count} items.",
   "key2"=>"Your cart has {count} items"},
 "fr"=>
  {"key1"=>"Bonjour {name}! Avec anninas fromage {count} la bouches.",
   "key2"=>"Tu avec carté {count} itém has"}}
        RUBY
      end
    end

    it "should include a header with the git revision" do
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js'
      expect(response.headers['X-Git-Revision']).to eql(@commit.revision)
    end

    it "should 400 if an unknown locale is provided" do
      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'sploops', format: 'yaml'
      expect(response.status).to eql(400)
    end

    it "should 404 if an incomplete locale is provided" do
      @commit.update_column :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml'
      expect(response.status).to eql(404)
    end

    it "should 404 if an invalid commit SHA is provided" do
      get :manifest, project_id: @project.to_param, id: 'deadbeef', format: 'yaml'
      expect(response.status).to eql(404)
    end

    it "should not 404 if the partial param is set" do
      @commit.update_column :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml', partial: 'true'
      expect(response.status).to eql(200)
      expect(response.body).to eql(<<-YAML)
---
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
      YAML
    end

    it "should include non-required locales if partial param is set" do
      @commit.update_attribute :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'yaml', partial: 'true'
      expect(response.status).to eql(200)
      expect(response.body).to eql(<<-YAML)
---
en:
  key1: Hi {name}! You have {count} items.
  key2: Your cart has {count} items
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
de:
  key2: Hallo {name}! Du hast {count} Itemen.
      YAML
    end

    it "should 400 if a single locale is required and no locales are given" do
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'strings'
      expect(response.status).to eql(400)
    end

    it "should 400 if a single locale is required and multiple locales are given" do
      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr,de', format: 'strings'
      expect(response.status).to eql(400)
    end

    it "should 404 with the commit not found in git repo error message if the commit is in db, but not found in git repo" do
      allow_any_instance_of(Git::Base).to receive(:object).and_return(nil) # fake a CommitNotFoundError error
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'strings'

      expect(response.status).to eql(404)
      expect(response.body).to eql("Commit with sha '#{@commit.revision}' could not be found in git repo. It may have been rebased away. Please submit the new sha to get your strings translated.")
    end

    it_behaves_like "returns error string if repository_url is blank", :manifest
  end

  describe '#localize' do
    before :each do
      @project = FactoryGirl.create(:project,
                                    base_rfc5646_locale:      'en',
                                    targeted_rfc5646_locales: {'en' => true, 'de' => true, 'fr' => true, 'zh' => false},
                                    repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit  = @project.commit!('HEAD', skip_import: true)

      key1 = FactoryGirl.create(:key,
                                project:      @project,
                                key:          'file-en.svg:/*/*[1]',
                                original_key: '/*/*[1]',
                                source:       'file-en.svg')
      key2 = FactoryGirl.create(:key,
                                project:      @project,
                                key:          'file-en.svg:/*/*[2]/*',
                                original_key: '/*/*[2]/*',
                                source:       'file-en.svg')

      FactoryGirl.create :translation,
                         key:                   key1,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'de',
                         source_copy:           "Hello, world!",
                         copy:                  "Hallo, Welt!",
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key2,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'de',
                         source_copy:           "Grouped text",
                         copy:                  "Gruppierten text",
                         approved:              true

      FactoryGirl.create :translation,
                         key:                   key1,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'fr',
                         source_copy:           "Hello, world!",
                         copy:                  "Bonjour tut le monde!",
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key2,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'fr',
                         source_copy:           "Grouped text",
                         copy:                  "Texte groupé",
                         approved:              true

      FactoryGirl.create :translation,
                         key:                   key1,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'zh',
                         source_copy:           "Hello, world!",
                         copy:                  "你好，世界！",
                         approved:              true
      FactoryGirl.create :translation,
                         key:                   key2,
                         source_rfc5646_locale: 'en',
                         rfc5646_locale:        'zh',
                         source_copy:           "Grouped text",
                         copy:                  "分组文本",
                         approved:              true

      @svg = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
    "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" width="292px"
	 height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hello, world!</text>
  <g>
    <text>Grouped text</text>
  </g>
</svg>
      XML
    end

    before :each do
      pending "Bug in RSpec causes this test to fail"

      allow_any_instance_of(Git::Base).to receive(:object).and_call_original
      allow_any_instance_of(Git::Base).to receive(:object).with('2dc20c984283bede1f45863b8f3b4dd9b5b554cc^{tree}:file-en.svg').
                                              and_return(double('Git::Object::Blob', contents: @svg))
    end

    it "should create a tarball of localized files" do
      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz'
      expect(response.status).to eql(200)
      expect(response.headers['Content-Disposition']).to eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          expect(entry).to be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      expect(entries.size).to eql(2)
      expect(entries['file-de.svg']).to eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hallo, Welt!</text>
  <g>
    <text>Gruppierten text</text>
  </g>
</svg>
      XML
      expect(entries['file-fr.svg']).to eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Bonjour tut le monde!</text>
  <g>
    <text>Texte groupé</text>
  </g>
</svg>
      XML
    end

    it "should create a tarball of localized files in a specific locale" do
      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz', locale: 'de'
      expect(response.status).to eql(200)
      expect(response.headers['Content-Disposition']).to eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          expect(entry).to be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      expect(entries.size).to eql(1)
      expect(entries['file-de.svg']).to eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hallo, Welt!</text>
  <g>
    <text>Gruppierten text</text>
  </g>
</svg>
      XML
    end

    it "should include non-required locales if partial param is set" do
      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz', partial: true
      expect(response.status).to eql(200)
      expect(response.headers['Content-Disposition']).to eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          expect(entry).to be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      expect(entries.size).to eql(3)
      expect(entries['file-zh.svg']).to eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">你好，世界！</text>
  <g>
    <text>分组文本</text>
  </g>
</svg>
      XML
    end

    it "should 404 if an invalid commit SHA is provided" do
      get :localize, project_id: @project.to_param, id: 'deadbeef', format: 'yaml'
      expect(response.status).to eql(404)
    end

    it "should 404 with the commit not found in git repo error message if the commit is in db, but not found in git repo" do
      allow_any_instance_of(Git::Base).to receive(:object).and_return(nil) # fake a CommitNotFoundError error
      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'strings'

      expect(response.status).to eql(404)
      expect(response.body).to eql("Commit with sha '#{@commit.revision}' could not be found in git repo. It may have been rebased and garbage collected in git. Please submit the new sha to be able to download the translations.")
    end

    it_behaves_like "returns error string if repository_url is blank", :localize
  end

  describe '#search' do
    before :each do
      reset_elastic_search

      @project = FactoryGirl.create(:project,
                                    base_rfc5646_locale:      'en',
                                    targeted_rfc5646_locales: { 'en' => true, 'fr' => true, 'es' => false },
                                    repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)

      @commit = @project.commit!('HEAD', skip_import: true)
      other_commit = FactoryGirl.create(:commit, project: @project)
      other_commit.keys = [FactoryGirl.create(:key, project: @project).tap(&:add_pending_translations)]
      @keys = FactoryGirl.create_list(:key, 51, project: @project, ready: false).sort_by(&:key)
      @keys.each &:add_pending_translations
      @commit.keys = @keys

      @user = FactoryGirl.create(:user, :activated)

      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
      sleep 2
    end

    it 'should return the first page of keys if page not specified' do
      get :search, project_id: @project.to_param, id: @commit.to_param
      expect(response.status).to eql(200)
      keys = assigns(:keys)
      expect(keys.length).to eql 50
    end

    it 'should return up to PER_PAGE (50) keys from the specified page' do
      get :search, project_id: @project.to_param, id: @commit.to_param, page: 2
      expect(response.status).to eql(200)
      keys = assigns(:keys)
      expect(keys.length).to eql 1
    end

    it 'should filter by the key name' do
      new_key = FactoryGirl.create(:key, project: @project, key: 'test_key').tap(&:add_pending_translations)
      @commit.keys = @keys << new_key
      sleep 1

      get :search, project_id: @project.to_param, id: @commit.to_param, filter: 'test_key'
      expect(response.status).to eql 200
      keys = assigns(:keys)
      expect(keys.length).to eql 1
    end

    it 'filters by requested status' do
      approved_key = FactoryGirl.create(:key, project: @project, key: 'approved_key', ready: true)
      @commit.keys = @keys << approved_key
      sleep 1

      get :search, project_id: @project.to_param, id: @commit.to_param, status: 'approved'
      expect(response.status).to eql 200
      keys = assigns(:keys)
      expect(keys.length).to eql 1

      get :search, project_id: @project.to_param, id: @commit.to_param, status: 'pending'
      expect(response.status).to eql 200
      keys = assigns(:keys)
      expect(keys.length).to eql 50
    end


  end

  describe '#create' do
    before :each do
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s,
                                    skip_imports: Importer::Base.implementations.map(&:ident) - %w(yaml))

      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'monitor')
      sign_in @user

      keys = Shuttle::Redis.keys('submitted_revision:*')
      Shuttle::Redis.del(*keys) unless keys.empty?
    end

    it "should strip the commit revision of whitespace" do
      post :create, project_id: @project.to_param, commit: {revision: "  HEAD     "}, format: 'json'
      expect(response.status).to eql(200)
    end

    it "should associate the commit with the current user" do
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(@project.commits.first.user).to eql(@user)
    end

    it "should allow the description, due date, and pull request URL to be set" do
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD', description: 'desc', pull_request_url: 'url', due_date: '1/1/2100'}, format: 'json'
      expect(@project.commits.first.description).to eql('desc')
      expect(@project.commits.first.pull_request_url).to eql('url')
      expect(@project.commits.first.due_date).to eql(Date.civil(2100, 1, 1))
    end

    it "should allow to import the same revision twice in quick succession" do
      expect(CommitCreator).to receive(:perform_once).once
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(JSON.parse(response.body)['success']).to include('has been received')

      expect(CommitCreator).to receive(:perform_once).once
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(JSON.parse(response.body)['success']).to include('has been received')
    end

    it "should not call CommitCreator if repository_url is blank" do
      project = FactoryGirl.create(:project, repository_url: nil)
      expect(CommitCreator).to_not receive(:perform_once)
      post :create, project_id: project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(response.body).to include("This project does not have a repository url. This action only applies to projects that have a repository.")
    end

    it "sends an email to current user if invalid sha is submitted or sha goes invalid before CommitCreator is run" do
      ActionMailer::Base.deliveries.clear
      expect { post :create, project_id: @project.to_param, commit: {revision: 'xyz123'}, format: 'json' }.to_not raise_error
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql([@user.email])
      expect(mail.subject).to eql("[Shuttle] Import Failed for sha: xyz123")
      expect(mail.body).to include("Error Class:   Git::CommitNotFoundError", "Error Message: Commit not found in git repo: xyz123")
      expect(mail.body).to include("Shuttle couldn't find your sha 'xyz123' in the git repo. This typically happens when your commit gets rebased away or the sha was invalid. Please submit the new sha to be able to get your strings translated.")
    end

    it "sends an email to current user and the commit author if valid sha is submitted but sha goes invalid after CommitCreator finished and before import is finished" do
      project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository-broken.git').to_s)
      ActionMailer::Base.deliveries.clear

      allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).and_call_original
      allow_any_instance_of(Project).to receive(:find_or_fetch_git_object).with("88e5b52732c23a4e33471d91cf2281e62021512a").and_return(nil) # fake a Git::BlobNotFoundError in CommitImporter
      allow_any_instance_of(Commit).to receive(:skip_key?).with("how_are_you").and_raise(Git::CommitNotFoundError, "fake_sha") # fake a CommitNotFoundError error in CommitKeyCreator failure
      expect { post :create, project_id: project.to_param, commit: {revision: 'e5f5704af3c1f84cf42c4db46dcfebe8ab842bde'}, format: 'json' }.to_not raise_error

      commit = project.commits.last
      blob_not_found = commit.blobs.with_sha("88e5b52732c23a4e33471d91cf2281e62021512a").first
      blob_for_which_commit_not_found = commit.blobs.with_sha("b80d7482dba100beb55e65e82c5edb28589fa045").first

      expected_errors = [["ExecJS::RuntimeError", "[stdin]:2:5: error: unexpected this\n    this is some invalid javascript code\n    ^^^^ (in /ember-broken/en-US.coffee)"],
                         ["Git::BlobNotFoundError", "Blob not found in git repo: 88e5b52732c23a4e33471d91cf2281e62021512a (failed in BlobImporter for commit_id #{commit.id} and blob_id #{blob_not_found.id})"],
                         ["Git::CommitNotFoundError", "Commit not found in git repo: fake_sha (failed in CommitKeyCreator for commit_id #{commit.id} and blob_id #{blob_for_which_commit_not_found.id})"],
                         ["Psych::SyntaxError", "(<unknown>): did not find expected key while parsing a block mapping at line 1 column 1 (in /config/locales/ruby/broken.yml)"],
                         ["V8::Error", "Unexpected identifier at <eval>:2:12 (in /ember-broken/en-US.js)"]]

      # expect to persist errors
      expect(commit.ready? || commit.tap(&:recalculate_ready!).ready? ).to be_falsey
      expect(commit.import_errors.sort).to eql(expected_errors.sort)

      # expect sending email
      expect(ActionMailer::Base.deliveries.size).to eql(1)
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eql(["yunus@squareup.com", @user.email])
      expect(mail.subject).to eql("[Shuttle] Error(s) occurred during the import")
      expected_errors.each do |err_class, err_message|
        expect(mail.body).to include("#{err_class} - #{err_message}")
      end
      expect(mail.body).to include("Shuttle couldn't find at least one sha from your commit in the git repo. This typically happens when your commit gets rebased away. Please submit the new sha to be able to get your strings translated.")
    end
  end

  describe '#destroy' do
    before :each do
      @project = FactoryGirl.create(:project, repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit                        = @project.commit!('HEAD', skip_import: true)
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @user = FactoryGirl.create(:user, :confirmed, role: 'admin')
      sign_in @user
    end

    it "should require a monitor" do
      @user.update_attribute :role, 'translator'
      delete :destroy, project_id: @commit.project.to_param, id: @commit.to_param, format: 'json'
      expect(response.status).to eql(403)
      expect { @commit.reload }.not_to raise_error
    end

    it "should delete a commit" do
      delete :destroy, project_id: @commit.project.to_param, id: @commit.to_param, format: 'json'
      expect(response.status).to eql(204)
      expect { @commit.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#issues" do
    render_views

    before :each do
      @user = FactoryGirl.create(:user, :confirmed, role: 'monitor', first_name: "Foo", last_name: "Bar")
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should return the issues" do
      commit = FactoryGirl.create(:commit)
      project = commit.project
      key = FactoryGirl.create(:key, project: project)
      commit.keys << key
      translation = FactoryGirl.create(:translation, key: key)

      issues = 3.times.map { FactoryGirl.create(:issue).tap{|issue| translation.issues << issue } }

      get :issues, project_id: translation.key.project.to_param, id: commit.to_param, format: 'html'
      expect(response).to be_ok
      expect(response.body.to_s).to include(*issues.map{|issue| "#issue-wrapper-#{issue.id}"})
    end
  end

  describe "#sync" do
    it_behaves_like "returns error string if repository_url is blank", :sync
  end

  describe "#recalculate" do
    it_behaves_like "returns error string if repository_url is blank", :recalculate
  end

  describe "#ping_stash" do
    it_behaves_like "returns error string if repository_url is blank", :ping_stash
  end
end
