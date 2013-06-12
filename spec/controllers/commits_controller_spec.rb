# encoding: utf-8

# Copyright 2013 Square Inc.
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

# encoding: utf-8

require 'spec_helper'
require 'fileutils'

describe CommitsController do
  describe "#manifest" do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project      = FactoryGirl.create(:project,
                                         base_rfc5646_locale:      'en-US',
                                         targeted_rfc5646_locales: {'en-US' => true, 'en' => true, 'fr' => true, 'de' => false},
                                         repository_url:           Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
      @commit       = @project.commit!('HEAD^', skip_import: true)
      @newer_commit = @project.commit!('HEAD', skip_import: true)

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
    end

    context '[formats]' do
      it "should export a YAML file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="fr.yaml"')
        response.body.should eql(<<-YAML)
---
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
        YAML
      end

      it "should export a YAML file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'yaml'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="manifest.yaml"')
        response.body.should eql(<<-YAML)
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
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="fr.js"')
        response.body.should eql(<<-JS)
Ember.I18n.locales.translations.fr = {
  "key1": "Bonjour {name}! Avec anninas fromage {count} la bouches.",
  "key2": "Tu avec carté {count} itém has"
};
        JS
      end

      it "should export an Ember.js file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="manifest.js"')
        response.body.should eql(<<-JS)
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
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="fr.strings"')
        response.headers['Content-Type'].should eql('text/plain; charset=utf-16le')
        response.body.encoding.to_s.should eql('UTF-16LE')

        body = response.body.encode('UTF-8')
        body.should include(<<-C)
/* Universal Greeting */
"key1" = "Bonjour {name}! Avec anninas fromage {count} la bouches.";
        C
        body.should include(<<-C)
/* Shopping cart contents */
"key2" = "Tu avec carté {count} itém has";
        C
      end

      it "should export a Java properties file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'properties'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="fr.properties"')

        response.body.should include(<<-C)
key1=Bonjour {name}! Avec anninas fromage {count} la bouches.
        C
        response.body.should include(<<-C)
key2=Tu avec carté {count} itém has
        C
      end

      it "should export an iOS tarball manifest" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'ios'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="manifest.tar.gz"')
        # check body?
      end

      it "should export an Android tarball manifest" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'android'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="manifest.tar.gz"')
        # check body?
      end

      it "should export a Ruby file in one locale" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'rb'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="fr.rb"')
        response.body.should eql(<<-RUBY)
{"fr"=>
  {"key1"=>"Bonjour {name}! Avec anninas fromage {count} la bouches.",
   "key2"=>"Tu avec carté {count} itém has"}}
        RUBY
      end

      it "should export a Ruby file in all locales" do
        get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'rb'
        response.status.should eql(200)
        response.headers['Content-Disposition'].should eql('attachment; filename="manifest.rb"')
        response.body.should eql(<<-RUBY)
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
      response.headers['X-Git-Revision'].should eql(@commit.revision)
    end

    it "should use a cached manifest if available" do
      mime = Mime::Type.lookup('application/javascript')
      File.open(ManifestPrecompiler.new.path(@commit, mime), 'w') { |f| f.puts "hello, world!" }
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js'
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="manifest.js"')
      response.body.should eql("hello, world!\n")
      FileUtils.rm_f ManifestPrecompiler.new.path(@commit, mime)
    end

    it "should not use a cached manifest if force=true" do
      mime = Mime::Type.lookup('application/javascript')
      File.open(ManifestPrecompiler.new.path(@commit, mime), 'w') { |f| f.puts "hello, world!" }
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js', force: 'true'
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="manifest.js"')
      response.body.should eql(<<-JS)
Ember.I18n.locales.translations.en = {
  "key1": "Hi {name}! You have {count} items.",
  "key2": "Your cart has {count} items"
};
Ember.I18n.locales.translations.fr = {
  "key1": "Bonjour {name}! Avec anninas fromage {count} la bouches.",
  "key2": "Tu avec carté {count} itém has"
};
      JS
      FileUtils.rm_f ManifestPrecompiler.new.path(@commit, mime)
    end

    it "should 400 if an unknown locale is provided" do
      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'sploops', format: 'yaml'
      response.status.should eql(400)
    end

    it "should 404 if an incomplete locale is provided" do
      @commit.update_attribute :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml'
      response.status.should eql(404)
    end

    it "should 404 if an invalid commit SHA is provided" do
      @commit.update_attribute :ready, false

      get :manifest, project_id: @project.to_param, id: 'deadbeef', format: 'yaml'
      response.status.should eql(404)
    end

    it "should not 404 if the partial param is set" do
      @commit.update_attribute :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, locale: 'fr', format: 'yaml', partial: 'true'
      response.status.should eql(200)
      response.body.should eql(<<-YAML)
---
fr:
  key1: Bonjour {name}! Avec anninas fromage {count} la bouches.
  key2: Tu avec carté {count} itém has
      YAML
    end

    it "should include non-required locales if partial param is set" do
      @commit.update_attribute :ready, false

      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'yaml', partial: 'true'
      response.status.should eql(200)
      response.body.should eql(<<-YAML)
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
  end

  describe '#localize' do
    before :all do
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
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

      Git::Base.any_instance.stub(:object).and_call_original
      Git::Base.any_instance.stub(:object).with('2dc20c984283bede1f45863b8f3b4dd9b5b554cc^{tree}:file-en.svg').
          and_return(mock('Git::Object::Blob', contents: @svg))
    end

    it "should create a tarball of localized files" do
      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz'
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          entry.should be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      entries.size.should eql(2)
      entries['file-de.svg'].should eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hallo, Welt!</text>
  <g>
    <text>Gruppierten text</text>
  </g>
</svg>
      XML
      entries['file-fr.svg'].should eql(<<-XML)
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
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          entry.should be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      entries.size.should eql(1)
      entries['file-de.svg'].should eql(<<-XML)
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
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          entry.should be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      entries.size.should eql(3)
      entries['file-zh.svg'].should eql(<<-XML)
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

    it "should use a cached localization if available" do
      File.open(LocalizePrecompiler.new.path(@commit), 'w') { |f| f.puts "hello, world!" }

      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz'
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="localized.tar.gz"')
      response.body.should eql("hello, world!\n")

      FileUtils.rm LocalizePrecompiler.new.path(@commit)
    end

    it "should not use a cached localization if force=true" do
      File.open(LocalizePrecompiler.new.path(@commit), 'w') { |f| f.puts "hello, world!" }

      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz', force: 'true'
      response.status.should eql(200)
      response.headers['Content-Disposition'].should eql('attachment; filename="localized.tar.gz"')

      entries = Hash.new
      Archive.read_open_memory(response.body, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR_GNUTAR) do |archive|
        while (entry = archive.next_header)
          entry.should be_regular
          entries[entry.pathname] = archive.read_data
        end
      end

      entries.size.should eql(2)
      entries['file-de.svg'].should eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Hallo, Welt!</text>
  <g>
    <text>Gruppierten text</text>
  </g>
</svg>
      XML
      entries['file-fr.svg'].should eql(<<-XML)
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" x="0px" y="0px" width="292px" height="368.585px" viewBox="0 0 292 368.585" enable-background="new 0 0 292 368.585" xml:space="preserve">
  <text transform="matrix(0.95 0 0 1 34.5542 295.8516)" fill="#FFFFFF" font-family="'MyriadPro-Regular'" font-size="7" letter-spacing="1.053">Bonjour tut le monde!</text>
  <g>
    <text>Texte groupé</text>
  </g>
</svg>
      XML

      FileUtils.rm LocalizePrecompiler.new.path(@commit)
    end
  end

  describe '#create' do
    before :all do
      @user = FactoryGirl.create(:user, role: 'monitor')
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    before :each do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should strip the commit revision of whitespace" do
      post :create, project_id: @project.to_param, commit: {revision: "  HEAD     "}, format: 'json'
      response.status.should eql(200)
    end
  end

  describe '#destroy' do
    before :all do
      @user = FactoryGirl.create(:user, role: 'admin')
      Project.where(repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s).delete_all
      @project = FactoryGirl.create(:project,
                                    repository_url: Rails.root.join('spec', 'fixtures', 'repository.git').to_s)
    end

    before :each do
      @commit                        = @project.commit!('HEAD')
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in @user
    end

    it "should require an administrator" do
      @user.update_attribute :role, 'monitor'
      delete :destroy, project_id: @commit.project.to_param, id: @commit.to_param, format: 'json'
      response.status.should eql(403)
      -> { @commit.reload }.should_not raise_error(ActiveRecord::RecordNotFound)
    end

    it "should delete a commit" do
      delete :destroy, project_id: @commit.project.to_param, id: @commit.to_param, format: 'json'
      response.status.should eql(204)
      -> { @commit.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#extract_data (private)" do
    it "should preserve BOM at the beginning of the IO" do
      # Calling io.string and io.read are not identical. This test ensures that the BOM
      # data is preserved when pulling the information out of the IO.
      io  = StringIO.new
      bom = [0xFF, 0xFE]
      bom.each { |b| io.putc b }
      file     = Compiler::File.new(io, 'UTF-16LE', 'foo.bar', "application/x-gzip; charset=utf-16le")
      response = controller.send(:extract_data, file)
      response.bytes.to_a[0].should == bom[0]
      response.bytes.to_a[1].should == bom[1]
    end
  end
end
