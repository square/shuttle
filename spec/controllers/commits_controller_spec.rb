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
        expect(response.status).to eql(200)
        expect(response.headers['Content-Disposition']).to eql('attachment; filename="fr.yaml"')
        expect(response.body).to eql(<<-YAML)
---
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

    it "should use a cached manifest if available" do
      mime = Mime::Type.lookup('application/javascript')
      Shuttle::Redis.set ManifestPrecompiler.new.key(@commit, mime), "Ember.I18n.locales.translations.en = {};"
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js'
      expect(response.status).to eql(200)
      expect(response.headers['Content-Disposition']).to eql('attachment; filename="manifest.js"')
      expect(response.body).to eql("Ember.I18n.locales.translations.en = {};")
      Shuttle::Redis.del ManifestPrecompiler.new.key(@commit, mime)
    end

    it "should not use a cached manifest if force=true" do
      mime = Mime::Type.lookup('application/javascript')
      Shuttle::Redis.set ManifestPrecompiler.new.key(@commit, mime), "hello, world!"
      get :manifest, project_id: @project.to_param, id: @commit.to_param, format: 'js', force: 'true'
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
      Shuttle::Redis.del ManifestPrecompiler.new.key(@commit, mime)
    end

    it "should not use a cached manifest if the cached manifest is invalid" do
      mime = Mime::Type.lookup('application/javascript')
      Shuttle::Redis.set ManifestPrecompiler.new.key(@commit, mime), "hello, world!"
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
      Shuttle::Redis.del ManifestPrecompiler.new.key(@commit, mime)
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

    it "should use a cached localization if available" do
      smalltgz = "\x1F\x8B\b\b\xB1\x8E\xF8Q\x00\x03log.tar\x00\xED\x99\xCFO\xC20\x14\x80_'\xC6\x19/;\x19\x8F\xBDx\xF1\x80mi\xB7\xEBB\xF0hL\xDC\xC5\e\x121d\t?\x12\x1C\xF7\xFD\xE9\xB6\xF4I\x16\x10\x88\x89\e\"\xEFK\x9A\x0FX\xCB\xDE(\xAF\xEC\xD1\xF1lt\x0F5#\x84H\x8C\xE1\xD6J\xAB\xC4YH%\x96\xFE\x82K%\x93X\x8AD\x19\xCD\x85\x94\xC6$\xC0M\xDD\x819\x16\x1F\xC5`nC)\xF2\xC9\xCE~\x83\xE1$\x9F\xEE8\x8E\xD7\xB1\xF2\x910\xB6\xF3\xDF\xEE\xB7{Y?+f\xF3\xF7Z\xCEa?\x8FX\xEB\xED\xF3/\x95r\xF3o:\x89R\xB1\x8C\xED\xFCw\xB4Q\xC0E-\xD1\xACq\xE2\xF3\x0F\xE7\xD7\x17\x10\x00<\x0E\xDE\xF8S\xC6_8\xE2^\x83K\xDB\x94m\xDC6\xF7\xFC\xD9\rX\xF5\x88\x0E\x174\xF1[,\xF3\xBF\xD6\xEC\xDF\x97\xFFR\v\xA1\xD7\xF3_iI\xF9\xDF\x10\xAC\xBB\x18JX\xA6s\b\xDEp\xFB}\xD7\x10\xDB\x06A\xF5\xFD\x80\x96\x06\x82 \b\x828\x06\x98Wxu\xD80\b\x82\xF8\x83\xB8\xF5\x81\xA3St\xE9\xCD\xF0x\x80nU\xC6Dh\x8EN\xD1\xA57\xC3~\x01\xBA\x85\x0E\xD1\x11\x9A\xA3St\xE9\x8D\x8B\x16\xC3\xE2\x83\xE1\x99\x19V(\f\xAB\x10\xC6\xD1\xE9\x8F.\x99 N\x863\xAF\xC8\xFD\xFE?\xC0\xD6\xFA\x9F \x88\x7F\fk\xF5\xB2^\x17V\x05\xC1f\a\xDB^+\x8FK\xD8~\x13\x10\xF8?\vo*c9:E\x97\xDEt\#@\x10\x04\xD14\xCB\xFD\xBFQ^\xE4\xA3im\e\x80\xFB\xF6\xFF\x850\xEB\xFB\x7FF\xD3\xFE\x7F#\xDC\xB5\xED7\xE0\xD0A\x10\x04A\x10\x8D\xF3\t\n\xEE0\x8E\x00*\x00\x00"
      Shuttle::Redis.set LocalizePrecompiler.new.key(@commit), smalltgz

      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz'
      expect(response.status).to eql(200)
      expect(response.headers['Content-Disposition']).to eql('attachment; filename="localized.tar.gz"')
      expect(response.body).to eql(smalltgz)

      Shuttle::Redis.del LocalizePrecompiler.new.key(@commit)
    end

    it "should not use a cached localization if force=true" do
      Shuttle::Redis.set LocalizePrecompiler.new.key(@commit), "hello, world!"

      get :localize, project_id: @project.to_param, id: @commit.to_param, format: 'tgz', force: 'true'
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

      Shuttle::Redis.del LocalizePrecompiler.new.key(@commit)
    end

    it "should not use a cached localization if the cached localization is invalid" do
      Shuttle::Redis.set LocalizePrecompiler.new.key(@commit), "hello, world!"

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

      Shuttle::Redis.del LocalizePrecompiler.new.key(@commit)
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
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD', description: 'desc', pull_request_url: 'url', due_date: Date.today.tomorrow}, format: 'json'
      expect(@project.commits.first.description).to eql('desc')
      expect(@project.commits.first.pull_request_url).to eql('url')
      expect(@project.commits.first.due_date).to eql(Date.today.tomorrow)
    end

    it "should not attempt to import the same revision twice in quick succession" do
      expect(CommitCreator).to receive(:perform_once).once
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(JSON.parse(response.body)['success']).to include('has been received')

      expect(CommitCreator).not_to receive(:perform_once)
      post :create, project_id: @project.to_param, commit: {revision: 'HEAD'}, format: 'json'
      expect(JSON.parse(response.body)['alert']).to include('already submitted')
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

  describe "#extract_data (private)" do
    it "should preserve BOM at the beginning of the IO" do
      # Calling io.string and io.read are not identical. This test ensures that the BOM
      # data is preserved when pulling the information out of the IO.
      io  = StringIO.new
      bom = [0xFF, 0xFE]
      bom.each { |b| io.putc b }
      file     = Compiler::File.new(io, 'UTF-16LE', 'foo.bar', "application/x-gzip; charset=utf-16le")
      response = controller.send(:extract_data, file)
      expect(response.bytes.to_a[0]).to eq(bom[0])
      expect(response.bytes.to_a[1]).to eq(bom[1])
    end
  end
end
