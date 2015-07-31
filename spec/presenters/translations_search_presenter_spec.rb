require 'spec_helper'

describe TranslationsSearchPresenter do
  let (:presenter) { TranslationsSearchPresenter.new(true) }

  context '[Translation info minus translation and display class]' do
    before :each do
      @translation = FactoryGirl.build(:translation, translated:true, approved: true, id: 1234)
    end

    it 'gets the project name' do
      expect(presenter.project(@translation)).to eql 'Example Project'
    end

    it 'gets the url_text' do
      expect(presenter.url_text(@translation)).to eql 1234
    end

    it 'gets the source locale' do
      expect(presenter.from(@translation)).to eql 'en-US'
    end

    it 'gets the to locale' do
      expect(presenter.to(@translation)).to eql 'de-DE'
    end

    it 'should have the source copy' do
      expect(presenter.source(@translation).include? " men came to kill me one time. The best of 'em carried this. It's a Callahan full-bore autolock.").to be true
    end

    it 'gets the key' do
      expect(presenter.key(@translation)).to eql @translation.key.key
    end
  end

  context '[translated]' do
    it 'should have class text-success if approved' do
      translation = FactoryGirl.build(:translation, approved: true, id: 1234, translated: true)
      expect(presenter.translation_text(translation).include? " Männer kamen mal, um mich zu töten. Der Beste von denen, hatte die bei sich. Es ist eine Callahan Vollkaliber mit Auto-Sicherung.").to be true
      expect(presenter.translation_class_name(translation)).to eql 'text-success'
    end

    it 'should have class text-error if not approved' do
      translation = FactoryGirl.build(:translation, approved: false, id: 1234, translated: true)
      expect(presenter.translation_text(translation).include? " Männer kamen mal, um mich zu töten. Der Beste von denen, hatte die bei sich. Es ist eine Callahan Vollkaliber mit Auto-Sicherung.").to be true
      expect(presenter.translation_class_name(translation)).to eql 'text-error'
    end
  end

  context '[not translated]' do
    it 'should have a muted class and text of untranslated' do
      translation = FactoryGirl.build(:translation, copy: nil, id: 1234, translated: false)
      expect(presenter.translation_text(translation)).to eql '(untranslated)'
      expect(presenter.translation_class_name(translation)).to eql 'muted'
    end
  end
end